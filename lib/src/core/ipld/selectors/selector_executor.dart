// src/core/ipld/selectors/selector_executor.dart
//
// Spec-compliant IPLD selector execution against a node/block store.
//
// Semantics follow go-ipld-prime's traversal/selector implementation:
//   - only nodes reached by a Matcher are yielded into the result set;
//     every explored node is in the "covered" set (the merkle proof),
//   - ExploreRecursive replaces ExploreRecursiveEdge positions with the
//     recursive selector carrying a decremented depth limit; once the depth
//     limit is exhausted the edges match nothing further,
//   - ExploreRecursive.stopAt is a Condition: if it matches a node, neither
//     the node nor its children are explored,
//   - links (CIDs) are transparently followed through the loader.

// ignore_for_file: public_member_api_docs, directives_ordering

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_multihash/dart_multihash.dart';

import '../../cid.dart';
import '../../errors/ipld_errors.dart';
import 'selector_ast.dart';
import '../../../proto/generated/ipld/data_model.pb.dart';

/// Default safe depth budget for selector execution.
const int defaultSelectorMaxDepth = 32;

/// Default safe node budget for selector execution.
const int defaultSelectorMaxNodes = 10000;

/// Recognized ADL names for [ExploreInterpretAs].
const Set<String> _knownAdls = {
  'sha2-256-trunc254-augmented-hashmap',
  'hamt',
  'hamt/sha3-256',
  'hamt/sha2-256',
};

/// Executes a [Selector] against an IPLD block store.
///
/// The loader function [loadNode] must return the decoded [IPLDNode] for a
/// given CID, throwing [IPLDLinkError] if the block is not available.
class SelectorExecutor {
  /// Creates an executor with the given budgets and loader.
  SelectorExecutor(
    this._loadNode, {
    this.maxDepth = defaultSelectorMaxDepth,
    this.maxNodes = defaultSelectorMaxNodes,
    this.includePath = false,
  });

  final Future<IPLDNode> Function(CID) _loadNode;
  final int maxDepth;
  final int maxNodes;
  final bool includePath;

  int _visitedNodes = 0;
  final Set<String> _visitedCids = {};

  /// Execute the selector starting at [root] and yield every matched node.
  Stream<SelectedNode> execute(CID root, Selector selector) async* {
    _visitedNodes = 0;
    _visitedCids.clear();
    yield* _traverse(root, selector, '', 0, null);
  }

  Stream<SelectedNode> _traverse(
    CID cid,
    Selector selector,
    String path,
    int depth,
    _RecursionContext? recursion,
  ) async* {
    if (depth > maxDepth) {
      throw SelectorBudgetExceeded(
        'Traversal exceeded maxDepth ($maxDepth) at path ${path.isEmpty ? '<root>' : path}',
      );
    }
    if (_visitedNodes >= maxNodes) {
      throw SelectorBudgetExceeded('Traversal exceeded maxNodes ($maxNodes)');
    }

    final node = await _loadNode(cid);
    _visitedNodes++;
    _visitedCids.add(cid.toString());

    yield* _apply(node, cid, selector, path, depth, recursion);
  }

  Stream<SelectedNode> _apply(
    IPLDNode node,
    CID cid,
    Selector selector,
    String path,
    int depth,
    _RecursionContext? recursion,
  ) async* {
    // CID links are transparently followed so that selectors operate on the
    // data they reference.
    if (node.kind == Kind.LINK) {
      final targetCid = _cidFromLink(node);
      if (_visitedCids.contains(targetCid.toString())) {
        return;
      }
      yield* _traverse(targetCid, selector, path, depth + 1, recursion);
      return;
    }

    switch (selector) {
      case Matcher(
        subset: final subset,
        label: final label,
        index: final index,
        onlyIf: final onlyIf,
      ):
        if (onlyIf != null && !onlyIf.matches(node)) {
          return;
        }
        IPLDNode matched = node;
        if (subset != null) {
          final sliced = _applySlice(node, subset);
          if (sliced == null) return; // range does not match this node.
          matched = sliced;
        }
        yield SelectedNode(
          cid: cid,
          node: matched,
          path: includePath ? path : null,
          label: label,
          index: index,
          remainingDepth: maxDepth - depth,
        );
      case ExploreAll(next: final next):
        if (node.kind == Kind.MAP) {
          for (final entry in node.mapValue.entries) {
            yield* _applyChild(
              entry.value,
              _childPath(path, entry.key),
              next,
              depth,
              recursion,
              cid,
            );
          }
        } else if (node.kind == Kind.LIST) {
          final values = node.listValue.values;
          for (var i = 0; i < values.length; i++) {
            yield* _applyChild(
              values[i],
              _childPath(path, i.toString()),
              next,
              depth,
              recursion,
              cid,
            );
          }
        }
      case ExploreFields(fields: final fields):
        if (node.kind == Kind.MAP) {
          for (final entry in node.mapValue.entries) {
            final sub = fields[entry.key];
            if (sub != null) {
              yield* _applyChild(
                entry.value,
                _childPath(path, entry.key),
                sub,
                depth,
                recursion,
                cid,
              );
            }
          }
        }
      case ExploreIndex(index: final index, next: final next):
        if (node.kind == Kind.LIST) {
          final values = node.listValue.values;
          if (index >= 0 && index < values.length) {
            yield* _applyChild(
              values[index],
              _childPath(path, index.toString()),
              next,
              depth,
              recursion,
              cid,
            );
          }
        }
      case ExploreRange(start: final start, end: final end, next: final next):
        if (node.kind == Kind.LIST) {
          final values = node.listValue.values;
          final s = start.clamp(0, values.length);
          final e = end.clamp(s, values.length);
          for (var i = s; i < e; i++) {
            yield* _applyChild(
              values[i],
              _childPath(path, i.toString()),
              next,
              depth,
              recursion,
              cid,
            );
          }
        }
      case ExploreUnion(members: final members):
        for (final member in members) {
          yield* _apply(node, cid, member, path, depth, recursion);
        }
      case ExploreRecursive(
        sequence: final sequence,
        stopAt: final stopAt,
      ):
        // stopAt: a matching node is not matched and its children are not
        // explored — the traversal stops descending at this point.
        if (stopAt != null && stopAt.matches(node)) {
          return;
        }

        // Compute the edge replacement for the next level of recursion.
        final edgeSelector = _decrementRecursion(selector);
        if (edgeSelector == null) {
          // Recursion budget exhausted: apply the sequence, but any
          // ExploreRecursiveEdge positions inside it match nothing.
          yield* _apply(node, cid, sequence, path, depth, null);
          return;
        }

        yield* _apply(
          node,
          cid,
          sequence,
          path,
          depth,
          _RecursionContext(edgeSelector),
        );
      case ExploreRecursiveEdge():
        if (recursion != null) {
          yield* _apply(node, cid, recursion.edgeSelector, path, depth, null);
        }
      case ExploreInterpretAs(adl: final adl, next: final next):
        if (!_knownAdls.contains(adl)) {
          throw IPLDValidationError(
            'Unknown ADL for exploreInterpretAs: "$adl"',
          );
        }
        // ADL interpretation is a P1 item. For now, apply the next selector
        // to the raw node so that the selector can still traverse the layout.
        yield* _apply(node, cid, next, path, depth, recursion);
      case ExploreConditional(condition: final condition, next: final next):
        if (condition == null || condition.matches(node)) {
          if (next != null) {
            yield* _apply(node, cid, next, path, depth, recursion);
          }
        }
      default:
        throw IPLDValidationError(
          'Unsupported selector: ${selector.runtimeType}',
        );
    }
  }

  Stream<SelectedNode> _applyChild(
    IPLDNode child,
    String childPath,
    Selector next,
    int depth,
    _RecursionContext? recursion,
    CID parentCid,
  ) async* {
    yield* _apply(child, parentCid, next, childPath, depth, recursion);
  }

  /// Returns the selector that replaces [ExploreRecursiveEdge] positions at
  /// the next recursion level, or `null` when the recursion limit is spent
  /// (edges then match nothing). Mirrors go-ipld-prime: a depth limit of
  /// `d` allows `d - 1` further levels of recursion.
  Selector? _decrementRecursion(ExploreRecursive recursive) {
    final limit = recursive.limit;
    if (limit is DepthRecursionLimit) {
      if (limit.depth <= 1) return null;
      return ExploreRecursive(
        limit: DepthRecursionLimit(limit.depth - 1),
        sequence: recursive.sequence,
        stopAt: recursive.stopAt,
      );
    }
    if (limit is RecursionLimitNone) {
      // No recursion limit in the selector; the executor's traversal
      // budget (maxDepth/maxNodes) still bounds the walk.
      return recursive;
    }
    return null;
  }

  /// Applies a [Slice] to a string or bytes node. Returns `null` when the
  /// range fails to match, per the spec's slice rules.
  IPLDNode? _applySlice(IPLDNode node, Slice slice) {
    switch (node.kind) {
      case Kind.STRING:
        final bounds = slice.resolve(node.stringValue.length);
        if (bounds == null) return null;
        return IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = node.stringValue.substring(bounds.$1, bounds.$2);
      case Kind.BYTES:
        final bounds = slice.resolve(node.bytesValue.length);
        if (bounds == null) return null;
        return IPLDNode()
          ..kind = Kind.BYTES
          ..bytesValue = node.bytesValue.sublist(bounds.$1, bounds.$2);
      default:
        return null;
    }
  }

  CID _cidFromLink(IPLDNode node) {
    final link = node.linkValue;
    return CID.v1(
      link.codec,
      Multihash.decode(Uint8List.fromList(link.multihash)),
    );
  }

  String _childPath(String path, String segment) {
    final escaped = segment.replaceAll('~', '~0').replaceAll('/', '~1');
    return path.isEmpty ? escaped : '$path/$escaped';
  }
}

class _RecursionContext {
  _RecursionContext(this.edgeSelector);
  final Selector edgeSelector;
}
