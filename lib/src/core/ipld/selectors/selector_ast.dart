// src/core/ipld/selectors/selector_ast.dart
//
// Official IPLD selector vocabulary as a typed, immutable AST.
//
// See: https://ipld.io/specs/selectors/

// ignore_for_file: public_member_api_docs, directives_ordering, sort_constructors_first

import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../../cid.dart';
import '../../errors/ipld_errors.dart';
import '../codecs/standard_codecs.dart';
import '../../../proto/generated/ipld/data_model.pb.dart';

/// Base class for all official IPLD selectors.
abstract class Selector {
  const Selector();

  /// Encode this selector as an [IPLDNode] using the official DAG-CBOR/DAG-JSON
  /// selector schema.
  IPLDNode toNode();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

/// Matcher selector: selects the current node and causes it to be yielded.
class Matcher extends Selector {
  const Matcher();

  @override
  IPLDNode toNode() => _singleKeyMap('matcher', _emptyMap());

  @override
  bool operator ==(Object other) => other is Matcher;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// ExploreAll: traverse every key/value pair of a map or every index of a list.
class ExploreAll extends Selector {
  final Selector next;

  const ExploreAll({required this.next});

  @override
  IPLDNode toNode() =>
      _singleKeyMap('exploreAll', _mapNode({'next': next.toNode()}));

  @override
  bool operator ==(Object other) => other is ExploreAll && other.next == next;

  @override
  int get hashCode => Object.hash(runtimeType, next);
}

/// ExploreFields: traverse only a named set of fields of a map.
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
    return _singleKeyMap('exploreFields', _mapNode({'fields': fieldsNode}));
  }

  @override
  bool operator ==(Object other) =>
      other is ExploreFields && _mapEquals(other.fields, fields);

  @override
  int get hashCode => Object.hash(runtimeType, _mapHash(fields));
}

/// ExploreIndex: traverse a single list index.
class ExploreIndex extends Selector {
  final int index;
  final Selector next;

  const ExploreIndex({required this.index, required this.next});

  @override
  IPLDNode toNode() => _singleKeyMap(
    'exploreIndex',
    _mapNode({'index': _intNode(index), 'next': next.toNode()}),
  );

  @override
  bool operator ==(Object other) =>
      other is ExploreIndex && other.index == index && other.next == next;

  @override
  int get hashCode => Object.hash(runtimeType, index, next);
}

/// ExploreRange: traverse a half-open range of list indices `[start, end)`.
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
    'exploreRange',
    _mapNode({
      'start': _intNode(start),
      'end': _intNode(end),
      'next': next.toNode(),
    }),
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

/// Recursion limit for [ExploreRecursive].
abstract class RecursionLimit {
  const RecursionLimit();

  IPLDNode toNode();
}

/// Depth-based recursion limit.
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

/// Node-count-based recursion limit.
class NodeCountRecursionLimit extends RecursionLimit {
  final int count;

  const NodeCountRecursionLimit(this.count);

  @override
  IPLDNode toNode() => _mapNode({'nodeCount': _intNode(count)});

  @override
  bool operator ==(Object other) =>
      other is NodeCountRecursionLimit && other.count == count;

  @override
  int get hashCode => Object.hash(runtimeType, count);
}

/// ExploreRecursive: recursive descent with a [limit] and a [sequence].
///
/// The [sequence] may contain [ExploreRecursiveEdge] markers that terminate the
/// recursion pattern at the current depth.
class ExploreRecursive extends Selector {
  final RecursionLimit limit;
  final Selector sequence;
  final Selector? stopAt;

  const ExploreRecursive({
    required this.limit,
    required this.sequence,
    this.stopAt,
  });

  @override
  IPLDNode toNode() {
    final body = <String, IPLDNode>{
      'limit': limit.toNode(),
      'sequence': sequence.toNode(),
    };
    if (stopAt != null) {
      body['stopAt'] = stopAt!.toNode();
    }
    return _singleKeyMap('exploreRecursive', _mapNode(body));
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

/// ExploreRecursiveEdge: marker that terminates the recursion pattern inside
/// [ExploreRecursive].
class ExploreRecursiveEdge extends Selector {
  const ExploreRecursiveEdge();

  @override
  IPLDNode toNode() => _singleKeyMap('exploreRecursiveEdge', _emptyMap());

  @override
  bool operator ==(Object other) => other is ExploreRecursiveEdge;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// ExploreUnion: apply a list of selectors to the same node.
class ExploreUnion extends Selector {
  final List<Selector> members;

  ExploreUnion({required List<Selector> members})
    : members = List.unmodifiable(members);

  @override
  IPLDNode toNode() {
    final list = IPLDList()..values.addAll(members.map((m) => m.toNode()));
    return _singleKeyMap(
      'exploreUnion',
      _mapNode({
        'members': (IPLDNode()
          ..kind = Kind.LIST
          ..listValue = list),
      }),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExploreUnion && _listEquals(other.members, members);

  @override
  int get hashCode => Object.hash(runtimeType, _listHash(members));
}

/// ExploreInterpretAs: traverse with an Advanced Data Layout (ADL) interpretation.
class ExploreInterpretAs extends Selector {
  final String adl;
  final Selector next;

  const ExploreInterpretAs({required this.adl, required this.next});

  @override
  IPLDNode toNode() => _singleKeyMap(
    'exploreInterpretAs',
    _mapNode({'adl': _stringNode(adl), 'next': next.toNode()}),
  );

  @override
  bool operator ==(Object other) =>
      other is ExploreInterpretAs && other.adl == adl && other.next == next;

  @override
  int get hashCode => Object.hash(runtimeType, adl, next);
}

/// ExploreConditional: include or exclude nodes based on a condition selector.
///
/// If the [condition] selector yields at least one node when applied to the
/// current node, the [next] selector is applied. If [condition] is omitted,
/// [next] is always applied.
class ExploreConditional extends Selector {
  final Selector? condition;
  final Selector? next;

  const ExploreConditional({this.condition, this.next});

  @override
  IPLDNode toNode() {
    final body = <String, IPLDNode>{};
    if (condition != null) {
      body['condition'] = condition!.toNode();
    }
    if (next != null) {
      body['next'] = next!.toNode();
    }
    return _singleKeyMap('exploreConditional', _mapNode(body));
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
    required this.remainingDepth,
  });

  /// The CID of the block containing the selected node.
  final CID cid;

  /// The selected IPLD data-model node.
  final IPLDNode node;

  /// The IPLD path from the root to the selected node, if requested.
  final String? path;

  /// The remaining recursion budget at the point of selection.
  final int remainingDepth;
}

// ---- Parser ----

/// Parse an [IPLDNode] (decoded from DAG-CBOR or DAG-JSON) into a typed
/// [Selector].
///
/// Unknown selector keys, malformed shapes, and [ExploreRecursiveEdge] outside
/// an [ExploreRecursive] sequence are rejected with [SelectorParseError].
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
  final body = _requireMap(value, 'body of "$key"');

  switch (key) {
    case 'exploreAll':
      return ExploreAll(next: _parseSelectorField(body, 'next'));
    case 'exploreFields':
      final fieldsNode = _requireField(body, 'fields');
      final fieldsMap = _requireMap(fieldsNode, 'fields');
      final fields = <String, Selector>{};
      for (final entry in fieldsMap.entries) {
        fields[entry.key] = parseSelector(entry.value);
      }
      return ExploreFields(fields: fields);
    case 'exploreIndex':
      return ExploreIndex(
        index: _requireInt(_requireField(body, 'index'), 'index'),
        next: _parseSelectorField(body, 'next'),
      );
    case 'exploreRange':
      return ExploreRange(
        start: _requireInt(_requireField(body, 'start'), 'start'),
        end: _requireInt(_requireField(body, 'end'), 'end'),
        next: _parseSelectorField(body, 'next'),
      );
    case 'exploreRecursive':
      final limitNode = _requireField(body, 'limit');
      final sequence = _parseSelectorField(body, 'sequence');
      Selector? stopAt;
      final stopAtNode = _optionalField(body, 'stopAt');
      if (stopAtNode != null) {
        stopAt = parseSelector(stopAtNode);
      }
      return ExploreRecursive(
        limit: _parseRecursionLimit(limitNode),
        sequence: sequence,
        stopAt: stopAt,
      );
    case 'exploreRecursiveEdge':
      return const ExploreRecursiveEdge();
    case 'exploreUnion':
      final membersNode = _requireField(body, 'members');
      final membersList = _requireList(membersNode, 'members');
      return ExploreUnion(
        members: membersList.values.map(parseSelector).toList(),
      );
    case 'exploreInterpretAs':
      return ExploreInterpretAs(
        adl: _requireString(_requireField(body, 'adl'), 'adl'),
        next: _parseSelectorField(body, 'next'),
      );
    case 'exploreConditional':
    case 'condition':
      Selector? condition;
      final conditionNode = _optionalField(body, 'condition');
      if (conditionNode != null) {
        condition = parseSelector(conditionNode);
      }
      Selector? next;
      final nextNode = _optionalField(body, 'next');
      if (nextNode != null) {
        next = parseSelector(nextNode);
      }
      return ExploreConditional(condition: condition, next: next);
    case 'matcher':
      return const Matcher();
    default:
      throw SelectorParseError('Unknown selector key: "$key"');
  }
}

RecursionLimit _parseRecursionLimit(IPLDNode node) {
  final map = _requireMap(node, 'limit');
  final depthNode = _optionalField(map, 'depth');
  if (depthNode != null) {
    return DepthRecursionLimit(_requireInt(depthNode, 'limit.depth'));
  }
  final countNode = _optionalField(map, 'nodeCount');
  if (countNode != null) {
    return NodeCountRecursionLimit(_requireInt(countNode, 'limit.nodeCount'));
  }
  throw SelectorParseError('limit must contain "depth" or "nodeCount"');
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

/// Decode a selector from DAG-CBOR bytes.
Future<Selector> decodeSelectorDagCbor(Uint8List bytes) async {
  return parseSelector(await DagCborCodec().decode(bytes));
}

/// Decode a selector from DAG-JSON bytes.
Future<Selector> decodeSelectorDagJson(Uint8List bytes) async {
  return parseSelector(await DagJsonCodec().decode(bytes));
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

// ---- Helpers ----

IPLDNode _emptyMap() => IPLDNode()
  ..kind = Kind.MAP
  ..mapValue = IPLDMap();

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

IPLDNode? _optionalField(IPLDMap map, String key) {
  for (final entry in map.entries) {
    if (entry.key == key) {
      return entry.value;
    }
  }
  return null;
}

Selector _parseSelectorField(IPLDMap map, String key) {
  return parseSelector(_requireField(map, key));
}

int _requireInt(IPLDNode node, String context) {
  if (node.kind != Kind.INTEGER) {
    throw SelectorParseError('$context must be an integer');
  }
  return node.intValue.toInt();
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

bool _listEquals(List<Selector> a, List<Selector> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _listHash(List<Selector> list) {
  var hash = 0;
  for (final item in list) {
    hash ^= item.hashCode;
  }
  return hash;
}
