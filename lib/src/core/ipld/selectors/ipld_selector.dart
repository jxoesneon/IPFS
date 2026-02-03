// src/core/ipld/selectors/ipld_selector.dart

import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';

/// Types of IPLD selectors for DAG traversal.
enum SelectorType {
  /// Select all nodes.
  all,

  /// Select no nodes.
  none,

  /// Explore a specific path.
  explore,

  /// Match nodes by criteria.
  matcher,

  /// Recursively traverse the DAG.
  recursive,

  /// Union of multiple selectors.
  union,

  /// Intersection of multiple selectors.
  intersection,
}

/// IPLD Selector for querying and traversing DAG structures.
///
/// Selectors define patterns for matching and extracting subsets
/// of IPLD DAGs, used in Graphsync for efficient data transfer.
class IPLDSelector {
  /// Creates a selector with the given parameters.
  IPLDSelector({
    required this.type,
    this.criteria = const {},
    this.maxDepth,
    this.subSelectors,
    this.fieldPath,
    this.stopAtLink,
  });

  /// Creates a selector that matches all nodes.
  factory IPLDSelector.all() => IPLDSelector(type: SelectorType.all);

  /// Creates a selector that matches no nodes.
  factory IPLDSelector.none() => IPLDSelector(type: SelectorType.none);

  /// Creates an explore selector for traversing a specific path.
  factory IPLDSelector.explore({
    required String path,
    required IPLDSelector selector,
  }) => IPLDSelector(
    type: SelectorType.explore,
    fieldPath: path,
    subSelectors: [selector],
  );

  /// Creates a matcher selector with the given criteria.
  factory IPLDSelector.matcher({required Map<String, dynamic> criteria}) =>
      IPLDSelector(type: SelectorType.matcher, criteria: criteria);

  /// Creates a recursive traversal selector.
  factory IPLDSelector.recursive({
    required IPLDSelector selector,
    int? maxDepth,
    bool stopAtLink = false,
  }) => IPLDSelector(
    type: SelectorType.recursive,
    subSelectors: [selector],
    maxDepth: maxDepth,
    stopAtLink: stopAtLink,
  );

  /// Creates a union of multiple selectors.
  factory IPLDSelector.union(List<IPLDSelector> selectors) =>
      IPLDSelector(type: SelectorType.union, subSelectors: selectors);

  /// Creates an intersection of multiple selectors.
  factory IPLDSelector.intersection(List<IPLDSelector> selectors) =>
      IPLDSelector(type: SelectorType.intersection, subSelectors: selectors);

  /// The selector type.
  final SelectorType type;

  /// Matching criteria for this selector.
  final Map<String, dynamic> criteria;

  /// Maximum depth for recursive selectors.
  final int? maxDepth;

  /// Child selectors for composite selectors.
  final List<IPLDSelector>? subSelectors;

  /// Field path for explore selectors.
  final String? fieldPath;

  /// Whether to stop traversal at links.
  final bool? stopAtLink;

  /// Converts the selector to IPLD bytes for Graphsync protocol
  Future<Uint8List> toBytes() async {
    final node = IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = (IPLDMap()
        ..entries.addAll([
          MapEntry()
            ..key = '.tag'
            ..value = (IPLDNode()
              ..kind = Kind.STRING
              ..stringValue = type.toString()),
          if (criteria.isNotEmpty)
            MapEntry()
              ..key = 'criteria'
              ..value = _encodeCriteria(criteria),
          if (maxDepth != null)
            MapEntry()
              ..key = 'maxDepth'
              ..value = (IPLDNode()
                ..kind = Kind.INTEGER
                ..intValue = Int64(maxDepth!)),
          if (subSelectors != null)
            MapEntry()
              ..key = 'selectors'
              ..value = (IPLDNode()
                ..kind = Kind.LIST
                ..listValue = (IPLDList()
                  ..values.addAll(
                    await Future.wait(
                      subSelectors!.map(
                        (s) => s.toBytes().then(
                          (bytes) =>
                              EnhancedCBORHandler.decodeCborWithTags(bytes),
                        ),
                      ),
                    ),
                  ))),
          if (fieldPath != null)
            MapEntry()
              ..key = 'path'
              ..value = (IPLDNode()
                ..kind = Kind.STRING
                ..stringValue = fieldPath!),
          if (stopAtLink != null)
            MapEntry()
              ..key = 'stopAtLink'
              ..value = (IPLDNode()
                ..kind = Kind.BOOL
                ..boolValue = stopAtLink!),
        ]));

    return await EnhancedCBORHandler.encodeCbor(node);
  }

  IPLDNode _encodeCriteria(Map<String, dynamic> criteria) {
    final node = IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = IPLDMap();

    for (final entry in criteria.entries) {
      node.mapValue.entries.add(
        MapEntry()
          ..key = entry.key
          ..value = _encodeValue(entry.value),
      );
    }

    return node;
  }

  IPLDNode _encodeValue(dynamic value) {
    if (value == null) {
      return IPLDNode()..kind = Kind.NULL;
    } else if (value is bool) {
      return IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = value;
    } else if (value is int) {
      return IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(value);
    } else if (value is String) {
      return IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = value;
    }
    // Add other types as needed
    throw UnsupportedError('Unsupported value type: ${value.runtimeType}');
  }

  static dynamic _decodeValue(IPLDNode node) {
    switch (node.kind) {
      case Kind.NULL:
        return null;
      case Kind.BOOL:
        return node.boolValue;
      case Kind.INTEGER:
        return node.intValue.toInt();
      case Kind.FLOAT:
        return node.floatValue;
      case Kind.STRING:
        return node.stringValue;
      case Kind.BYTES:
        return node.bytesValue;
      case Kind.LIST:
        return node.listValue.values.map((n) => _decodeValue(n)).toList();
      case Kind.MAP:
        final map = <String, dynamic>{};
        for (final entry in node.mapValue.entries) {
          map[entry.key] = _decodeValue(entry.value);
        }
        return map;
      case Kind.LINK:
        return {
          'version': node.linkValue.version,
          'codec': node.linkValue.codec,
          'multihash': node.linkValue.multihash,
        };
      case Kind.BIG_INT:
        return BigInt.parse(String.fromCharCodes(node.bigIntValue));
      default:
        throw IPLDDecodingError('Unsupported IPLD kind: ${node.kind}');
    }
  }

  /// Decodes CBOR bytes back to an IPLDNode
  static Future<IPLDNode> _decodeBytes(Uint8List bytes) async {
    try {
      return await EnhancedCBORHandler.decodeCborWithTags(bytes);
    } catch (e) {
      throw IPLDDecodingError('Failed to decode selector bytes: $e');
    }
  }

  /// Creates an IPLDSelector from its CBOR byte representation
  static Future<IPLDSelector> fromBytesAsync(Uint8List bytes) async {
    final node = await _decodeBytes(bytes);

    if (node.kind != Kind.MAP) {
      throw IPLDDecodingError('Invalid selector format: expected MAP');
    }

    final type = SelectorType.values.firstWhere(
      (t) =>
          t.toString() ==
          node.mapValue.entries
              .firstWhere((e) => e.key == '.tag')
              .value
              .stringValue,
      orElse: () => throw IPLDDecodingError('Invalid selector type'),
    );

    final criteria = <String, dynamic>{};
    final criteriaEntry = node.mapValue.entries.firstWhere(
      (e) => e.key == 'criteria',
      orElse: () => MapEntry()
        ..key = 'criteria'
        ..value = (IPLDNode()
          ..kind = Kind.MAP
          ..mapValue = IPLDMap()),
    );
    for (final entry in criteriaEntry.value.mapValue.entries) {
      criteria[entry.key] = _decodeValue(entry.value);
    }

    final maxDepth = node.mapValue.entries
        .firstWhere(
          (e) => e.key == 'maxDepth',
          orElse: () => MapEntry()
            ..key = 'maxDepth'
            ..value = (IPLDNode()..kind = Kind.NULL),
        )
        .value
        .intValue
        .toInt();

    final subSelectors = node.mapValue.entries
        .firstWhere(
          (e) => e.key == 'selectors',
          orElse: () => MapEntry()
            ..key = 'selectors'
            ..value = (IPLDNode()
              ..kind = Kind.LIST
              ..listValue = IPLDList()),
        )
        .value
        .listValue
        .values
        .map((n) => IPLDSelector.fromNode(n))
        .toList();

    final fieldPath = node.mapValue.entries
        .firstWhere(
          (e) => e.key == 'path',
          orElse: () => MapEntry()
            ..key = 'path'
            ..value = (IPLDNode()..kind = Kind.NULL),
        )
        .value
        .stringValue;

    final stopAtLink = node.mapValue.entries
        .firstWhere(
          (e) => e.key == 'stopAtLink',
          orElse: () => MapEntry()
            ..key = 'stopAtLink'
            ..value = (IPLDNode()..kind = Kind.NULL),
        )
        .value
        .boolValue;

    return IPLDSelector(
      type: type,
      criteria: criteria,
      maxDepth: maxDepth,
      subSelectors: subSelectors,
      fieldPath: fieldPath,
      stopAtLink: stopAtLink,
    );
  }

  /// Creates an IPLDSelector from an IPLDNode
  static IPLDSelector fromNode(IPLDNode node) {
    if (node.kind != Kind.MAP) {
      throw IPLDDecodingError('Invalid selector format: expected MAP');
    }

    final type = SelectorType.values.firstWhere(
      (t) =>
          t.toString() ==
          node.mapValue.entries
              .firstWhere((e) => e.key == '.tag')
              .value
              .stringValue,
      orElse: () => throw IPLDDecodingError('Invalid selector type'),
    );

    return IPLDSelector(
      type: type,
      criteria:
          _decodeValue(
                node.mapValue.entries
                    .firstWhere(
                      (e) => e.key == 'criteria',
                      orElse: () => MapEntry()
                        ..key = 'criteria'
                        ..value = (IPLDNode()
                          ..kind = Kind.MAP
                          ..mapValue = IPLDMap()),
                    )
                    .value,
              )
              as Map<String, dynamic>,
      maxDepth: node.mapValue.entries
          .firstWhere(
            (e) => e.key == 'maxDepth',
            orElse: () => MapEntry()
              ..key = 'maxDepth'
              ..value = (IPLDNode()..kind = Kind.NULL),
          )
          .value
          .intValue
          .toInt(),
      subSelectors: node.mapValue.entries
          .firstWhere(
            (e) => e.key == 'selectors',
            orElse: () => MapEntry()
              ..key = 'selectors'
              ..value = (IPLDNode()
                ..kind = Kind.LIST
                ..listValue = IPLDList()),
          )
          .value
          .listValue
          .values
          .map((n) => fromNode(n))
          .toList(),
      fieldPath: node.mapValue.entries
          .firstWhere(
            (e) => e.key == 'path',
            orElse: () => MapEntry()
              ..key = 'path'
              ..value = (IPLDNode()..kind = Kind.NULL),
          )
          .value
          .stringValue,
      stopAtLink: node.mapValue.entries
          .firstWhere(
            (e) => e.key == 'stopAtLink',
            orElse: () => MapEntry()
              ..key = 'stopAtLink'
              ..value = (IPLDNode()..kind = Kind.NULL),
          )
          .value
          .boolValue,
    );
  }
}
