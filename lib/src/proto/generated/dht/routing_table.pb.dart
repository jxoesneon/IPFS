//
//  Generated code. Do not modify.
//  source: dht/routing_table.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'kademlia_node.pb.dart' as $0;

class RoutingTableProto extends $pb.GeneratedMessage {
  factory RoutingTableProto({
    $core.Map<$core.String, $0.KademliaNode>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  RoutingTableProto._() : super();
  factory RoutingTableProto.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RoutingTableProto.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RoutingTableProto', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.routing_table'), createEmptyInstance: create)
    ..m<$core.String, $0.KademliaNode>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'RoutingTableProto.EntriesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OM, valueCreator: $0.KademliaNode.create, valueDefaultOrMaker: $0.KademliaNode.getDefault, packageName: const $pb.PackageName('ipfs.dht.routing_table'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RoutingTableProto clone() => RoutingTableProto()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RoutingTableProto copyWith(void Function(RoutingTableProto) updates) => super.copyWith((message) => updates(message as RoutingTableProto)) as RoutingTableProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoutingTableProto create() => RoutingTableProto._();
  RoutingTableProto createEmptyInstance() => create();
  static $pb.PbList<RoutingTableProto> createRepeated() => $pb.PbList<RoutingTableProto>();
  @$core.pragma('dart2js:noInline')
  static RoutingTableProto getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoutingTableProto>(create);
  static RoutingTableProto? _defaultInstance;

  /// Represents the routing table entries.
  /// The key is the PeerId string, and the value is the associated KademliaNode.
  @$pb.TagNumber(1)
  $core.Map<$core.String, $0.KademliaNode> get entries => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
