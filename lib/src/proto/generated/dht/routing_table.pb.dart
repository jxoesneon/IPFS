//
//  Generated code. Do not modify.
//  source: routing_table.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'kademlia_node.pb.dart' as $0;

class RoutingTable extends $pb.GeneratedMessage {
  factory RoutingTable({
    $core.Map<$core.String, $0.KademliaNode>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  RoutingTable._() : super();
  factory RoutingTable.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RoutingTable.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RoutingTable', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.routing_table'), createEmptyInstance: create)
    ..m<$core.String, $0.KademliaNode>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'RoutingTable.EntriesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OM, valueCreator: $0.KademliaNode.create, valueDefaultOrMaker: $0.KademliaNode.getDefault, packageName: const $pb.PackageName('ipfs.dht.routing_table'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RoutingTable clone() => RoutingTable()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RoutingTable copyWith(void Function(RoutingTable) updates) => super.copyWith((message) => updates(message as RoutingTable)) as RoutingTable;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoutingTable create() => RoutingTable._();
  RoutingTable createEmptyInstance() => create();
  static $pb.PbList<RoutingTable> createRepeated() => $pb.PbList<RoutingTable>();
  @$core.pragma('dart2js:noInline')
  static RoutingTable getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoutingTable>(create);
  static RoutingTable? _defaultInstance;

  /// Represents the routing table entries.
  /// The key is the PeerId string, and the value is the associated KademliaNode.
  @$pb.TagNumber(1)
  $core.Map<$core.String, $0.KademliaNode> get entries => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
