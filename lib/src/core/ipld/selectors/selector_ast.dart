// src/core/ipld/selectors/selector_ast.dart
//
// Official IPLD selector vocabulary as a typed, immutable AST.
//
// Serialization follows the selector schema from
// https://ipld.io/specs/selectors/ (the same keyed representation used by
// go-ipld-prime, and therefore by Graphsync on the wire):
//
//   type SelectorEnvelope union { | Selector "selector" } repr keyed
//   type Selector union {
//     | Matcher              "."
//     | ExploreAll           "a"
//     | ExploreFields        "f"
//     | ExploreIndex         "i"
//     | ExploreRange         "r"
//     | ExploreRecursive     "R"
//     | ExploreUnion         "|"
//     | ExploreConditional   "&"
//     | ExploreRecursiveEdge "@"   # sentinel; only valid inside "R" sequences
//     | InterpretAs          "~"
//   } representation keyed
//
// Field renames: next ">", fields "f>", index "i", start "^", end "$",
// sequence ":>", limit "l", stopAt "!", condition "&", subset "subset",
// label "label", index "index", onlyIf "onlyIf", slice bounds "[" and "]",
// interpretAs "as", recursion limits "depth" / "none".
//
// The parser additionally accepts the long-form member and field names
// (e.g. "matcher", "exploreAll", "next") so selectors written against the
// descriptive names still decode; encoding always emits the compact form.

// ignore_for_file: public_member_api_docs, directives_ordering, sort_constructors_first

import 'dart:typed_data';

import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';

import '../../cid.dart';
import '../../errors/ipld_errors.dart';
import '../codecs/standard_codecs.dart';
import '../../../proto/generated/ipld/data_model.pb.dart';

/// Base class for all official IPLD selectors.
abstract class Selector {
  const Selector();

  /// Encode this selector as an [IPLDNode] using the official compact
  /// DAG-CBOR/DAG-JSON selector schema.
  IPLDNode toNode();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

/// A [Slice] selects the `[from, to)` subset of a string, bytes, or reified
/// node inside a [Matcher].
///
/// Negative values are offsets from the end of the node; an overflowing `to`
/// clamps to the node length. A range that resolves to nothing (from >= to,
/// or from >= length) fails to match.
class Slice {
  final int from;
  final int to;

  const Slice({required this.from, required this.to});

  IPLDNode toNode() => _mapNode({'[': _intNode(from), ']': _intNode(to)});

  /// Resolves the slice against a [length] and returns `(from, to)`, or
  /// `null` when the range fails to match. Mirrors go-ipld-prime
  /// `sliceBounds`.
  (int, int)? resolve(int length) {
    var to = this.to;
    var from = this.from;
    if (to < 0) {
      to = length + to;
    } else if (length < to) {
      to = length;
    }
    if (from < 0) {
      from = length + from;
      if (from < 0) from = 0;
    }
    if (from > to || from >= length) return null;
    return (from, to);
  }

  @override
  bool operator ==(Object other) =>
      other is Slice && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// A predicate over a data-model node, used by [Matcher.onlyIf],
/// [ExploreRecursive.stopAt], and [ExploreConditional.condition].
///
/// The spec marks the Condition union as skeletal; this implements the
/// members listed there: `hasField`, `=` (hasValue), `%` (hasKind),
/// `/` (isLink), `greaterThan`, `lessThan`, `and`, `or`.
abstract class Condition {
  const Condition();

  IPLDNode toNode();

  /// Whether the condition holds for [node].
  bool matches(IPLDNode node);
}

/// Matches when [node] is a link. If [target] is set, the link must point
/// at that CID.
class IsLinkCondition extends Condition {
  final CID? target;

  const IsLinkCondition({this.target});

  @override
  IPLDNode toNode() =>
      _singleKeyMap('/', target == null ? _nullNode() : _linkNode(target!));

  @override
  bool matches(IPLDNode node) {
    if (node.kind != Kind.LINK) return false;
    if (target == null) return true;
    final link = node.linkValue;
    return link.codec == target!.codec &&
        _bytesEqual(link.multihash, target!.multihash.toBytes());
  }

  @override
  bool operator ==(Object other) =>
      other is IsLinkCondition &&
      other.target?.toString() == target?.toString();

  @override
  int get hashCode => Object.hash(runtimeType, target?.toString());
}

/// Matches when [node] is a map containing [field].
class HasFieldCondition extends Condition {
  final String field;

  const HasFieldCondition(this.field);

  @override
  IPLDNode toNode() => _singleKeyMap('hasField', _stringNode(field));

  @override
  bool matches(IPLDNode node) {
    if (node.kind != Kind.MAP) return false;
    return node.mapValue.entries.any((e) => e.key == field);
  }

  @override
  bool operator ==(Object other) =>
      other is HasFieldCondition && other.field == field;

  @override
  int get hashCode => Object.hash(runtimeType, field);
}

/// Matches when [node] is data-model-equal to [value].
class HasValueCondition extends Condition {
  final IPLDNode value;

  const HasValueCondition(this.value);

  @override
  IPLDNode toNode() => _singleKeyMap('=', value);

  @override
  bool matches(IPLDNode node) => ipldNodeEquals(node, value);

  @override
  bool operator ==(Object other) =>
      other is HasValueCondition && ipldNodeEquals(other.value, value);

  @override
  int get hashCode => ipldNodeHash(value);
}

/// Matches when [node]'s kind equals [kindName] (one of `map`, `list`,
/// `string`, `bytes`, `int`, `float`, `bool`, `null`, `link`).
class HasKindCondition extends Condition {
  final String kindName;

  const HasKindCondition(this.kindName);

  @override
  IPLDNode toNode() => _singleKeyMap('%', _stringNode(kindName));

  @override
  bool matches(IPLDNode node) => ipldKindName(node.kind) == kindName;

  @override
  bool operator ==(Object other) =>
      other is HasKindCondition && other.kindName == kindName;

  @override
  int get hashCode => Object.hash(runtimeType, kindName);
}

/// Matches when [node] is a number strictly greater than [value].
class GreaterThanCondition extends Condition {
  final num value;

  const GreaterThanCondition(this.value);

  @override
  IPLDNode toNode() => _singleKeyMap('greaterThan', _numNode(value));

  @override
  bool matches(IPLDNode node) =>
      _numericValue(node) is num && _numericValue(node)! > value;

  @override
  bool operator ==(Object other) =>
      other is GreaterThanCondition && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// Matches when [node] is a number strictly less than [value].
class LessThanCondition extends Condition {
  final num value;

  const LessThanCondition(this.value);

  @override
  IPLDNode toNode() => _singleKeyMap('lessThan', _numNode(value));

  @override
  bool matches(IPLDNode node) =>
      _numericValue(node) is num && _numericValue(node)! < value;

  @override
  bool operator ==(Object other) =>
      other is LessThanCondition && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// Matches when every member condition matches.
class AndCondition extends Condition {
  final List<Condition> conditions;

  AndCondition(List<Condition> conditions)
    : conditions = List.unmodifiable(conditions);

  @override
  IPLDNode toNode() => _singleKeyMap('and', _conditionList(conditions));

  @override
  bool matches(IPLDNode node) => conditions.every((c) => c.matches(node));

  @override
  bool operator ==(Object other) =>
      other is AndCondition &&
      _listEquals(other.conditions.cast<dynamic>(), conditions);

  @override
  int get hashCode => Object.hash(runtimeType, _listHash(conditions));
}

/// Matches when at least one member condition matches.
class OrCondition extends Condition {
  final List<Condition> conditions;

  OrCondition(List<Condition> conditions)
    : conditions = List.unmodifiable(conditions);

  @override
  IPLDNode toNode() => _singleKeyMap('or', _conditionList(conditions));

  @override
  bool matches(IPLDNode node) => conditions.any((c) => c.matches(node));

  @override
  bool operator ==(Object other) =>
      other is OrCondition &&
      _listEquals(other.conditions.cast<dynamic>(), conditions);

  @override
  int get hashCode => Object.hash(runtimeType, _listHash(conditions));
}

/// Matcher selector: marks the node it is applied to as part of the result
/// set. With [subset] only the sliced span of a string/bytes node is
/// matched; [onlyIf] gates the match on a [Condition]; [label] and [index]
/// annotate the match for result labelling.
class Matcher extends Selector {
  final Slice? subset;
  final String? label;
  final int? index;
  final Condition? onlyIf;

  const Matcher({this.subset, this.label, this.index, this.onlyIf});

  @override
  IPLDNode toNode() {
    final body = <String, IPLDNode>{};
    if (subset != null) body['subset'] = subset!.toNode();
    if (label != null) body['label'] = _stringNode(label!);
    if (index != null) body['index'] = _intNode(index!);
    if (onlyIf != null) body['onlyIf'] = onlyIf!.toNode();
    return _singleKeyMap('.', _mapNode(body));
  }

  @override
  bool operator ==(Object other) =>
      other is Matcher &&
      other.subset == subset &&
      other.label == label &&
      other.index == index &&
      other.onlyIf == onlyIf;

  @override
  int get hashCode => Object.hash(runtimeType, subset, label, index, onlyIf);
}

/// ExploreAll: traverse every key/value pair of a map or every index of a
/// list, applying [next] to each reached node.
class ExploreAll extends Selector {
  final Selector next;

  const ExploreAll({required this.next});

  @override
  IPLDNode toNode() => _singleKeyMap('a', _mapNode({'>': next.toNode()}));

  @override
  bool operator ==(Object other) => other is ExploreAll && other.next == next;

  @override
  int get hashCode => Object.hash(runtimeType, next);
}

/// ExploreFields: traverse only the named [fields] of a map.
class ExploreFields extends Selector {
  final Map<String, Selector> fields;

  ExploreFields({required Map<String, Selector> fields})
    : fields = Map.unmodifiable(fields);

  @override
  IPLDNode toNode() {
    final entries = <MapEntry>[];
    for (final entry in fields.entries) {
      entries.add(
        MapEntry()
          ..key = entry.key
          ..value = entry.value.toNode(),
      );
    }
    final fieldsNode = IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = (IPLDMap()..entries.addAll(entries));
    return _singleKeyMap('f', _mapNode({'f>': fieldsNode}));
  }

  @override
  bool operator ==(Object other) =>
      other is ExploreFields && _mapEquals(other.fields, fields);

  @override
  int get hashCode => Object.hash(runtimeType, _mapHash(fields));
}

/// ExploreIndex: traverse a single list [index].
class ExploreIndex extends Selector {
  final int index;
  final Selector next;

  const ExploreIndex({required this.index, required this.next});

  @override
  IPLDNode toNode() =>
      _singleKeyMap('i', _mapNode({'i': _intNode(index), '>': next.toNode()}));

  @override
  bool operator ==(Object other) =>
      other is ExploreIndex && other.index == index && other.next == next;

  @override
  int get hashCode => Object.hash(runtimeType, index, next);
}

/// ExploreRange: traverse the half-open range of list indices `[start, end)`.
class ExploreRange extends Selector {
  final int start;
  final int end;
  final Selector next;

  const ExploreRange({
    required this.start,
    required this.end,
    required this.next,
  });

  @override
  IPLDNode toNode() => _singleKeyMap(
    'r',
    _mapNode({'^': _intNode(start), '\$': _intNode(end), '>': next.toNode()}),
  );

  @override
  bool operator ==(Object other) =>
      other is ExploreRange &&
      other.start == start &&
      other.end == end &&
      other.next == next;

  @override
  int get hashCode => Object.hash(runtimeType, start, end, next);
}

/// Recursion limit for [ExploreRecursive]. The spec union has two members:
/// `{"depth": int}` and `{"none": {}}`.
abstract class RecursionLimit {
  const RecursionLimit();

  IPLDNode toNode();
}

/// Depth-based recursion limit (`{"depth": n}`).
class DepthRecursionLimit extends RecursionLimit {
  final int depth;

  const DepthRecursionLimit(this.depth);

  @override
  IPLDNode toNode() => _mapNode({'depth': _intNode(depth)});

  @override
  bool operator ==(Object other) =>
      other is DepthRecursionLimit && other.depth == depth;

  @override
  int get hashCode => Object.hash(runtimeType, depth);
}

/// Unbounded recursion limit (`{"none": {}}`).
///
/// The spec leaves the effective bound to the executing library; the
/// executor's traversal budget applies.
class RecursionLimitNone extends RecursionLimit {
  const RecursionLimitNone();

  @override
  IPLDNode toNode() => _mapNode({'none': _emptyMap()});

  @override
  bool operator ==(Object other) => other is RecursionLimitNone;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// ExploreRecursive: recursive descent with a [limit] and a [sequence].
///
/// The [sequence] should contain [ExploreRecursiveEdge] markers at the
/// positions where recursion re-enters; each edge expansion decrements a
/// depth [limit]. [stopAt] is a [Condition] that, when it matches a node,
/// excludes that node and its children from exploration entirely.
class ExploreRecursive extends Selector {
  final RecursionLimit limit;
  final Selector sequence;
  final Condition? stopAt;

  const ExploreRecursive({
    required this.limit,
    required this.sequence,
    this.stopAt,
  });

  @override
  IPLDNode toNode() {
    final body = <String, IPLDNode>{
      ':>': sequence.toNode(),
      'l': limit.toNode(),
    };
    if (stopAt != null) {
      body['!'] = stopAt!.toNode();
    }
    return _singleKeyMap('R', _mapNode(body));
  }

  @override
  bool operator ==(Object other) =>
      other is ExploreRecursive &&
      other.limit == limit &&
      other.sequence == sequence &&
      other.stopAt == stopAt;

  @override
  int get hashCode => Object.hash(runtimeType, limit, sequence, stopAt);
}

/// ExploreRecursiveEdge: sentinel marking the recursion point inside an
/// [ExploreRecursive] sequence. Invalid outside one.
class ExploreRecursiveEdge extends Selector {
  const ExploreRecursiveEdge();

  @override
  IPLDNode toNode() => _singleKeyMap('@', _emptyMap());

  @override
  bool operator ==(Object other) => other is ExploreRecursiveEdge;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// ExploreUnion: apply a list of selectors to the same node. Serializes as
/// `{"|": [<selector>...]}`.
class ExploreUnion extends Selector {
  final List<Selector> members;

  ExploreUnion({required List<Selector> members})
    : members = List.unmodifiable(members);

  @override
  IPLDNode toNode() {
    final list = IPLDList()..values.addAll(members.map((m) => m.toNode()));
    return _singleKeyMap(
      '|',
      IPLDNode()
        ..kind = Kind.LIST
        ..listValue = list,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExploreUnion && _listEquals(other.members, members);

  @override
  int get hashCode => Object.hash(runtimeType, _listHash(members));
}

/// ExploreInterpretAs (spec name `InterpretAs`, union key `~`): reify the
/// current node through the ADL named [adl], then apply [next] to the
/// reified view.
class ExploreInterpretAs extends Selector {
  final String adl;
  final Selector next;

  const ExploreInterpretAs({required this.adl, required this.next});

  @override
  IPLDNode toNode() => _singleKeyMap(
    '~',
    _mapNode({'as': _stringNode(adl), '>': next.toNode()}),
  );

  @override
  bool operator ==(Object other) =>
      other is ExploreInterpretAs && other.adl == adl && other.next == next;

  @override
  int get hashCode => Object.hash(runtimeType, adl, next);
}

/// ExploreConditional: when [condition] matches the current node, continue
/// exploration with [next].
class ExploreConditional extends Selector {
  final Condition? condition;
  final Selector? next;

  const ExploreConditional({this.condition, this.next});

  @override
  IPLDNode toNode() {
    final body = <String, IPLDNode>{};
    if (condition != null) {
      body['&'] = condition!.toNode();
    }
    if (next != null) {
      body['>'] = next!.toNode();
    }
    return _singleKeyMap('&', _mapNode(body));
  }

  @override
  bool operator ==(Object other) =>
      other is ExploreConditional &&
      other.condition == condition &&
      other.next == next;

  @override
  int get hashCode => Object.hash(runtimeType, condition, next);
}

/// Result of a selector execution.
class SelectedNode {
  /// Creates a selected node result.
  SelectedNode({
    required this.cid,
    required this.node,
    this.path,
    this.label,
    this.index,
    required this.remainingDepth,
  });

  /// The CID of the block containing the selected node.
  final CID cid;

  /// The selected IPLD data-model node.
  final IPLDNode node;

  /// The IPLD path from the root to the selected node, if requested.
  final String? path;

  /// The matcher's label, if the matching [Matcher] carried one.
  final String? label;

  /// The matcher's index annotation, if the matching [Matcher] carried one.
  final int? index;

  /// The remaining recursion budget at the point of selection.
  final int remainingDepth;
}

// ---- Parser ----

/// Parse an [IPLDNode] (decoded from DAG-CBOR or DAG-JSON) into a typed
/// [Selector].
///
/// Accepts the compact spec keys (`.`, `a`, `f`, `i`, `r`, `R`, `|`, `&`,
/// `@`, `~`) and, leniently, their long-form names (`matcher`,
/// `exploreAll`, ...). Malformed shapes are rejected with
/// [SelectorParseError].
Selector parseSelector(IPLDNode node) {
  if (node.kind != Kind.MAP) {
    throw SelectorParseError('Selector must be a map');
  }
  final entries = node.mapValue.entries;
  if (entries.length != 1) {
    throw SelectorParseError(
      'Selector map must contain exactly one key, found ${entries.length}',
    );
  }
  final key = entries.first.key;
  final value = entries.first.value;

  switch (key) {
    case '.':
    case 'matcher':
      return _parseMatcher(value);
    case 'a':
    case 'exploreAll':
      final body = _requireMap(value, 'body of "exploreAll"');
      return ExploreAll(next: _parseSelectorField(body, const ['>', 'next']));
    case 'f':
    case 'exploreFields':
      final body = _requireMap(value, 'body of "exploreFields"');
      final fieldsNode = _requireFieldAny(body, const ['f>', 'fields']);
      final fieldsMap = _requireMap(fieldsNode, 'exploreFields fields');
      final fields = <String, Selector>{};
      for (final entry in fieldsMap.entries) {
        fields[entry.key] = parseSelector(entry.value);
      }
      return ExploreFields(fields: fields);
    case 'i':
    case 'exploreIndex':
      final body = _requireMap(value, 'body of "exploreIndex"');
      return ExploreIndex(
        index: _requireInt(
          _requireFieldAny(body, const ['i', 'index']),
          'exploreIndex index',
        ),
        next: _parseSelectorField(body, const ['>', 'next']),
      );
    case 'r':
    case 'exploreRange':
      final body = _requireMap(value, 'body of "exploreRange"');
      return ExploreRange(
        start: _requireInt(
          _requireFieldAny(body, const ['^', 'start']),
          'exploreRange start',
        ),
        end: _requireInt(
          _requireFieldAny(body, const ['\$', 'end']),
          'exploreRange end',
        ),
        next: _parseSelectorField(body, const ['>', 'next']),
      );
    case 'R':
    case 'exploreRecursive':
      final body = _requireMap(value, 'body of "exploreRecursive"');
      final limitNode = _requireFieldAny(body, const ['l', 'limit']);
      final sequence = _parseSelectorField(body, const [':>', 'sequence']);
      Condition? stopAt;
      final stopAtNode = _optionalFieldAny(body, const ['!', 'stopAt']);
      if (stopAtNode != null) {
        stopAt = parseCondition(stopAtNode);
      }
      return ExploreRecursive(
        limit: _parseRecursionLimit(limitNode),
        sequence: sequence,
        stopAt: stopAt,
      );
    case '@':
    case 'exploreRecursiveEdge':
      return const ExploreRecursiveEdge();
    case '|':
    case 'exploreUnion':
      final membersList = _requireList(value, 'exploreUnion members');
      return ExploreUnion(
        members: membersList.values.map(parseSelector).toList(),
      );
    case '&':
    case 'exploreConditional':
      final body = _requireMap(value, 'body of "exploreConditional"');
      Condition? condition;
      final conditionNode = _optionalFieldAny(body, const ['&', 'condition']);
      if (conditionNode != null) {
        condition = parseCondition(conditionNode);
      }
      Selector? next;
      final nextNode = _optionalFieldAny(body, const ['>', 'next']);
      if (nextNode != null) {
        next = parseSelector(nextNode);
      }
      return ExploreConditional(condition: condition, next: next);
    case '~':
    case 'exploreInterpretAs':
    case 'interpretAs':
      final body = _requireMap(value, 'body of "interpretAs"');
      return ExploreInterpretAs(
        adl: _requireString(
          _requireFieldAny(body, const ['as', 'adl']),
          'interpretAs as',
        ),
        next: _parseSelectorField(body, const ['>', 'next']),
      );
    default:
      throw SelectorParseError('Unknown selector key: "$key"');
  }
}

/// Parse a `SelectorEnvelope` node (`{"selector": <selector>}`).
Selector parseSelectorEnvelope(IPLDNode node) {
  if (node.kind != Kind.MAP) {
    throw SelectorParseError('Selector envelope must be a map');
  }
  final inner = _requireField(node.mapValue, 'selector');
  return parseSelector(inner);
}

/// Parse a [Condition] from its data-model node.
Condition parseCondition(IPLDNode node) {
  if (node.kind != Kind.MAP) {
    throw SelectorParseError('Condition must be a keyed-union map');
  }
  final entries = node.mapValue.entries;
  if (entries.length != 1) {
    throw SelectorParseError(
      'Condition map must contain exactly one key, found ${entries.length}',
    );
  }
  final key = entries.first.key;
  final value = entries.first.value;

  switch (key) {
    case '/':
      if (value.kind == Kind.LINK) {
        return IsLinkCondition(target: _cidFromLinkNode(value));
      }
      if (value.kind == Kind.NULL) {
        return const IsLinkCondition();
      }
      throw SelectorParseError('isLink condition must be a link or null');
    case 'hasField':
      return HasFieldCondition(_requireString(value, 'hasField condition'));
    case '=':
      return HasValueCondition(value);
    case '%':
      return HasKindCondition(_requireString(value, 'hasKind condition'));
    case 'greaterThan':
      return GreaterThanCondition(_requireNum(value, 'greaterThan'));
    case 'lessThan':
      return LessThanCondition(_requireNum(value, 'lessThan'));
    case 'and':
      final list = _requireList(value, 'and condition');
      return AndCondition(list.values.map(parseCondition).toList());
    case 'or':
      final list = _requireList(value, 'or condition');
      return OrCondition(list.values.map(parseCondition).toList());
    default:
      throw SelectorParseError('Unknown condition key: "$key"');
  }
}

Matcher _parseMatcher(IPLDNode node) {
  final body = _requireMap(node, 'body of "matcher"');
  Slice? subset;
  final subsetNode = _optionalField(body, 'subset');
  if (subsetNode != null) {
    final sliceMap = _requireMap(subsetNode, 'matcher subset');
    subset = Slice(
      from: _requireInt(
        _requireFieldAny(sliceMap, const ['[', 'from']),
        'subset from',
      ),
      to: _requireInt(
        _requireFieldAny(sliceMap, const [']', 'to']),
        'subset to',
      ),
    );
  }
  String? label;
  final labelNode = _optionalField(body, 'label');
  if (labelNode != null) {
    label = _requireString(labelNode, 'matcher label');
  }
  int? index;
  final indexNode = _optionalField(body, 'index');
  if (indexNode != null) {
    index = _requireInt(indexNode, 'matcher index');
  }
  Condition? onlyIf;
  final onlyIfNode = _optionalField(body, 'onlyIf');
  if (onlyIfNode != null) {
    onlyIf = parseCondition(onlyIfNode);
  }
  return Matcher(subset: subset, label: label, index: index, onlyIf: onlyIf);
}

RecursionLimit _parseRecursionLimit(IPLDNode node) {
  final map = _requireMap(node, 'limit');
  final depthNode = _optionalField(map, 'depth');
  if (depthNode != null) {
    return DepthRecursionLimit(_requireInt(depthNode, 'limit.depth'));
  }
  if (_optionalField(map, 'none') != null) {
    return const RecursionLimitNone();
  }
  throw SelectorParseError('limit must contain "depth" or "none"');
}

// ---- Serialization to bytes ----

/// Encode a [Selector] to canonical DAG-CBOR bytes.
Future<Uint8List> encodeSelectorDagCbor(Selector selector) async {
  return DagCborCodec().encode(selector.toNode());
}

/// Encode a [Selector] to canonical DAG-JSON bytes.
Future<Uint8List> encodeSelectorDagJson(Selector selector) async {
  return DagJsonCodec().encode(selector.toNode());
}

/// Encode a [Selector] wrapped in the `SelectorEnvelope`
/// (`{"selector": ...}`) to canonical DAG-CBOR bytes.
Future<Uint8List> encodeSelectorEnvelopeDagCbor(Selector selector) async {
  return DagCborCodec().encode(_singleKeyMap('selector', selector.toNode()));
}

/// Decode a selector from DAG-CBOR bytes. A bare selector or a
/// `{"selector": ...}` envelope are both accepted.
Future<Selector> decodeSelectorDagCbor(Uint8List bytes) async {
  return _parseMaybeEnveloped(await DagCborCodec().decode(bytes));
}

/// Decode a selector from DAG-JSON bytes. A bare selector or a
/// `{"selector": ...}` envelope are both accepted.
Future<Selector> decodeSelectorDagJson(Uint8List bytes) async {
  return _parseMaybeEnveloped(await DagJsonCodec().decode(bytes));
}

/// Decode a selector from either DAG-CBOR or DAG-JSON bytes.
///
/// The encoding is detected from the first non-whitespace byte.
Future<Selector> decodeSelectorBytes(Uint8List bytes) async {
  final trimmed = _trimLeading(bytes);
  if (trimmed.isEmpty) {
    throw SelectorParseError('Empty selector bytes');
  }
  final first = trimmed.first;
  // DAG-JSON objects start with '{'; DAG-JSON arrays start with '['.
  if (first == 0x7b || first == 0x5b) {
    return decodeSelectorDagJson(bytes);
  }
  return decodeSelectorDagCbor(bytes);
}

Selector _parseMaybeEnveloped(IPLDNode node) {
  if (node.kind == Kind.MAP && node.mapValue.entries.length == 1) {
    final key = node.mapValue.entries.first.key;
    if (key == 'selector') {
      return parseSelector(node.mapValue.entries.first.value);
    }
  }
  return parseSelector(node);
}

// ---- Data-model helpers ----

/// The lowercase data-model kind name for [kind], as used by
/// [HasKindCondition].
String ipldKindName(Kind kind) {
  switch (kind) {
    case Kind.MAP:
      return 'map';
    case Kind.LIST:
      return 'list';
    case Kind.STRING:
      return 'string';
    case Kind.BYTES:
      return 'bytes';
    case Kind.INTEGER:
      return 'int';
    case Kind.BIG_INT:
      return 'int';
    case Kind.FLOAT:
      return 'float';
    case Kind.BOOL:
      return 'bool';
    case Kind.NULL:
      return 'null';
    case Kind.LINK:
      return 'link';
    // coverage:ignore-start
    default:
      return 'invalid';
    // coverage:ignore-end
  }
}

/// Structural equality for [IPLDNode] values.
bool ipldNodeEquals(IPLDNode a, IPLDNode b) {
  if (a.kind != b.kind) return false;
  switch (a.kind) {
    case Kind.NULL:
      return true;
    case Kind.BOOL:
      return a.boolValue == b.boolValue;
    case Kind.INTEGER:
      return a.intValue == b.intValue;
    case Kind.BIG_INT:
      return _bytesEqual(a.bigIntValue, b.bigIntValue);
    case Kind.FLOAT:
      return a.floatValue == b.floatValue;
    case Kind.STRING:
      return a.stringValue == b.stringValue;
    case Kind.BYTES:
      return _bytesEqual(a.bytesValue, b.bytesValue);
    case Kind.LINK:
      return a.linkValue.codec == b.linkValue.codec &&
          _bytesEqual(a.linkValue.multihash, b.linkValue.multihash);
    case Kind.LIST:
      if (a.listValue.values.length != b.listValue.values.length) {
        return false;
      }
      for (var i = 0; i < a.listValue.values.length; i++) {
        if (!ipldNodeEquals(a.listValue.values[i], b.listValue.values[i])) {
          return false;
        }
      }
      return true;
    case Kind.MAP:
      if (a.mapValue.entries.length != b.mapValue.entries.length) {
        return false;
      }
      for (final entry in a.mapValue.entries) {
        final other = _optionalField(b.mapValue, entry.key);
        if (other == null || !ipldNodeEquals(entry.value, other)) {
          return false;
        }
      }
      return true;
    // coverage:ignore-start
    default:
      return false;
    // coverage:ignore-end
  }
}

/// Order-independent hash for [ipldNodeEquals]-comparable nodes.
int ipldNodeHash(IPLDNode node) {
  switch (node.kind) {
    case Kind.NULL:
      return 0;
    case Kind.BOOL:
      return Object.hash(1, node.boolValue);
    case Kind.INTEGER:
      return Object.hash(2, node.intValue);
    case Kind.BIG_INT:
      return Object.hash(2, Object.hashAll(node.bigIntValue));
    case Kind.FLOAT:
      return Object.hash(3, node.floatValue);
    case Kind.STRING:
      return Object.hash(4, node.stringValue);
    case Kind.BYTES:
      return Object.hash(5, Object.hashAll(node.bytesValue));
    case Kind.LINK:
      return Object.hash(
        6,
        node.linkValue.codec,
        Object.hashAll(node.linkValue.multihash),
      );
    case Kind.LIST:
      return Object.hash(7, Object.hashAll(node.listValue.values));
    case Kind.MAP:
      var hash = 8;
      for (final entry in node.mapValue.entries) {
        hash ^= Object.hash(entry.key, ipldNodeHash(entry.value));
      }
      return hash;
    // coverage:ignore-start
    default:
      return node.kind.hashCode;
    // coverage:ignore-end
  }
}

CID _cidFromLinkNode(IPLDNode node) {
  final link = node.linkValue;
  return CID.v1(
    link.codec,
    Multihash.decode(Uint8List.fromList(link.multihash)),
  );
}

// ---- Helpers ----

IPLDNode _emptyMap() => IPLDNode()
  ..kind = Kind.MAP
  ..mapValue = IPLDMap();

IPLDNode _nullNode() => IPLDNode()..kind = Kind.NULL;

IPLDNode _mapNode(Map<String, IPLDNode> entries) {
  final map = IPLDMap();
  for (final entry in entries.entries) {
    map.entries.add(
      MapEntry()
        ..key = entry.key
        ..value = entry.value,
    );
  }
  return IPLDNode()
    ..kind = Kind.MAP
    ..mapValue = map;
}

IPLDNode _singleKeyMap(String key, IPLDNode value) => _mapNode({key: value});

IPLDNode _intNode(int value) => IPLDNode()
  ..kind = Kind.INTEGER
  ..intValue = Int64(value);

IPLDNode _stringNode(String value) => IPLDNode()
  ..kind = Kind.STRING
  ..stringValue = value;

IPLDNode _numNode(num value) {
  if (value is int) return _intNode(value);
  return IPLDNode()
    ..kind = Kind.FLOAT
    ..floatValue = value.toDouble();
}

IPLDNode _linkNode(CID cid) => IPLDNode()
  ..kind = Kind.LINK
  ..linkValue = (IPLDLink()
    ..version = cid.version
    ..codec = cid.codec ?? 'dag-cbor'
    ..multihash = cid.multihash.toBytes());

IPLDNode _conditionList(List<Condition> conditions) {
  final list = IPLDList()..values.addAll(conditions.map((c) => c.toNode()));
  return IPLDNode()
    ..kind = Kind.LIST
    ..listValue = list;
}

IPLDMap _requireMap(IPLDNode node, String context) {
  if (node.kind != Kind.MAP) {
    throw SelectorParseError('$context must be a map');
  }
  return node.mapValue;
}

IPLDList _requireList(IPLDNode node, String context) {
  if (node.kind != Kind.LIST) {
    throw SelectorParseError('$context must be a list');
  }
  return node.listValue;
}

IPLDNode _requireField(IPLDMap map, String key) {
  for (final entry in map.entries) {
    if (entry.key == key) {
      return entry.value;
    }
  }
  throw SelectorParseError('Missing required field: "$key"');
}

IPLDNode _requireFieldAny(IPLDMap map, List<String> keys) {
  for (final entry in map.entries) {
    if (keys.contains(entry.key)) {
      return entry.value;
    }
  }
  throw SelectorParseError('Missing required field: "${keys.first}"');
}

IPLDNode? _optionalField(IPLDMap map, String key) {
  for (final entry in map.entries) {
    if (entry.key == key) {
      return entry.value;
    }
  }
  return null;
}

IPLDNode? _optionalFieldAny(IPLDMap map, List<String> keys) {
  for (final entry in map.entries) {
    if (keys.contains(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

Selector _parseSelectorField(IPLDMap map, List<String> keys) {
  return parseSelector(_requireFieldAny(map, keys));
}

int _requireInt(IPLDNode node, String context) {
  if (node.kind != Kind.INTEGER) {
    throw SelectorParseError('$context must be an integer');
  }
  return node.intValue.toInt();
}

num _requireNum(IPLDNode node, String context) {
  if (node.kind == Kind.INTEGER) return node.intValue.toInt();
  if (node.kind == Kind.FLOAT) return node.floatValue;
  throw SelectorParseError('$context must be a number');
}

num? _numericValue(IPLDNode node) {
  if (node.kind == Kind.INTEGER) return node.intValue.toInt();
  if (node.kind == Kind.BIG_INT) {
    // Internal convention: [sign, ...bigEndianMagnitudeBytes].
    final bytes = node.bigIntValue;
    if (bytes.length < 2) return 0;
    var magnitude = BigInt.zero;
    for (var i = 1; i < bytes.length; i++) {
      magnitude = (magnitude << 8) | BigInt.from(bytes[i]);
    }
    final signed = bytes[0] == 1 ? -magnitude : magnitude;
    return signed.toDouble();
  }
  if (node.kind == Kind.FLOAT) return node.floatValue;
  return null;
}

String _requireString(IPLDNode node, String context) {
  if (node.kind != Kind.STRING) {
    throw SelectorParseError('$context must be a string');
  }
  return node.stringValue;
}

Uint8List _trimLeading(Uint8List bytes) {
  var start = 0;
  while (start < bytes.length &&
      (bytes[start] == 0x20 ||
          bytes[start] == 0x09 ||
          bytes[start] == 0x0a ||
          bytes[start] == 0x0d)) {
    start++;
  }
  return Uint8List.fromList(bytes.sublist(start));
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, Selector> a, Map<String, Selector> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) return false;
  }
  return true;
}

int _mapHash(Map<String, Selector> map) {
  var hash = 0;
  for (final entry in map.entries) {
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}

bool _listEquals(List<dynamic> a, List<dynamic> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _listHash(List<dynamic> list) {
  var hash = 0;
  for (final item in list) {
    hash ^= item.hashCode;
  }
  return hash;
}
