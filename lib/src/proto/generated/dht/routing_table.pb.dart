// This is a generated file - do not edit.
//
// Generated from dht/routing_table.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'kademlia_node.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class RoutingTableProto extends $pb.GeneratedMessage {
  factory RoutingTableProto({
    $core.Iterable<$core.MapEntry<$core.String, $0.KademliaNode>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  RoutingTableProto._();

  factory RoutingTableProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoutingTableProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RoutingTableProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.routing_table'),
      createEmptyInstance: create)
    ..m<$core.String, $0.KademliaNode>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'RoutingTableProto.EntriesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: $0.KademliaNode.create,
        valueDefaultOrMaker: $0.KademliaNode.getDefault,
        packageName: const $pb.PackageName('ipfs.dht.routing_table'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoutingTableProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoutingTableProto copyWith(void Function(RoutingTableProto) updates) =>
      super.copyWith((message) => updates(message as RoutingTableProto)) as RoutingTableProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoutingTableProto create() => RoutingTableProto._();
  @$core.override
  RoutingTableProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoutingTableProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoutingTableProto>(create);
  static RoutingTableProto? _defaultInstance;

  /// Represents the routing table entries.
  /// The key is the PeerId string, and the value is the associated KademliaNode.
  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $0.KademliaNode> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
