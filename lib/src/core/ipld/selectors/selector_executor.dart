// src/core/ipld/selectors/selector_executor.dart
//
// Spec-compliant IPLD selector execution against a node/block store.

// ignore_for_file: public_member_api_docs, directives_ordering

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_multihash/dart_multihash.dart';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/selector_ast.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

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
      case Matcher():
        yield SelectedNode(
          cid: cid,
          node: node,
          path: includePath ? (path.isEmpty ? '' : path) : null,
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
      case ExploreRecursive(sequence: final sequence, stopAt: final stopAt):
        // Check stopAt: if the stopAt selector matches this node, apply the
        // sequence without expanding recursive edges.
        if (stopAt != null) {
          final stop = await _hasMatch(
            node,
            cid,
            stopAt,
            path,
            depth,
            recursion,
          );
          if (stop) {
            yield* _apply(node, cid, sequence, path, depth, null);
            return;
          }
        }

        // Compute the edge replacement for the next level of recursion.
        final edgeSelector = _decrementRecursion(selector);
        if (edgeSelector == null) {
          // Budget exhausted: apply the sequence without expanding edges.
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
        if (condition == null) {
          if (next != null) {
            yield* _apply(node, cid, next, path, depth, recursion);
          }
          return;
        }
        final matches = await _hasMatch(
          node,
          cid,
          condition,
          path,
          depth,
          recursion,
        );
        if (matches && next != null) {
          yield* _apply(node, cid, next, path, depth, recursion);
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

  Future<bool> _hasMatch(
    IPLDNode node,
    CID cid,
    Selector selector,
    String path,
    int depth,
    _RecursionContext? recursion,
  ) async {
    try {
      await for (final _ in _apply(
        node,
        cid,
        selector,
        path,
        depth,
        recursion,
      )) {
        return true;
      }
    } catch (_) {
      // A budget error during a condition check is treated as no match.
      return false;
    }
    return false;
  }

  Selector? _decrementRecursion(ExploreRecursive recursive) {
    if (recursive.limit is DepthRecursionLimit) {
      final depthLimit = recursive.limit as DepthRecursionLimit;
      if (depthLimit.depth <= 0) return null;
      return ExploreRecursive(
        limit: DepthRecursionLimit(depthLimit.depth - 1),
        sequence: recursive.sequence,
        stopAt: recursive.stopAt,
      );
    }
    if (recursive.limit is NodeCountRecursionLimit) {
      final countLimit = recursive.limit as NodeCountRecursionLimit;
      if (countLimit.count <= 0) return null;
      return ExploreRecursive(
        limit: NodeCountRecursionLimit(countLimit.count - 1),
        sequence: recursive.sequence,
        stopAt: recursive.stopAt,
      );
    }
    return null;
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
