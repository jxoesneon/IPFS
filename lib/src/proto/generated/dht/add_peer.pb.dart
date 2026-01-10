//
//  Generated code. Do not modify.
//  source: dht/add_peer.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $9;

class AddPeerRequest extends $pb.GeneratedMessage {
  factory AddPeerRequest({
    $9.KademliaId? peerId,
    $9.KademliaId? associatedPeerId,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (associatedPeerId != null) {
      $result.associatedPeerId = associatedPeerId;
    }
    return $result;
  }
  AddPeerRequest._() : super();
  factory AddPeerRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AddPeerRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AddPeerRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.add_peer'), createEmptyInstance: create)
    ..aOM<$9.KademliaId>(1, _omitFieldNames ? '' : 'peerId', subBuilder: $9.KademliaId.create)
    ..aOM<$9.KademliaId>(2, _omitFieldNames ? '' : 'associatedPeerId', subBuilder: $9.KademliaId.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AddPeerRequest clone() => AddPeerRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AddPeerRequest copyWith(void Function(AddPeerRequest) updates) => super.copyWith((message) => updates(message as AddPeerRequest)) as AddPeerRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPeerRequest create() => AddPeerRequest._();
  AddPeerRequest createEmptyInstance() => create();
  static $pb.PbList<AddPeerRequest> createRepeated() => $pb.PbList<AddPeerRequest>();
  @$core.pragma('dart2js:noInline')
  static AddPeerRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddPeerRequest>(create);
  static AddPeerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $9.KademliaId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($9.KademliaId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);
  @$pb.TagNumber(1)
  $9.KademliaId ensurePeerId() => $_ensure(0);

  @$pb.TagNumber(2)
  $9.KademliaId get associatedPeerId => $_getN(1);
  @$pb.TagNumber(2)
  set associatedPeerId($9.KademliaId v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasAssociatedPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAssociatedPeerId() => clearField(2);
  @$pb.TagNumber(2)
  $9.KademliaId ensureAssociatedPeerId() => $_ensure(1);
}

class AddPeerResponse extends $pb.GeneratedMessage {
  factory AddPeerResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  AddPeerResponse._() : super();
  factory AddPeerResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AddPeerResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AddPeerResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.add_peer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AddPeerResponse clone() => AddPeerResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AddPeerResponse copyWith(void Function(AddPeerResponse) updates) => super.copyWith((message) => updates(message as AddPeerResponse)) as AddPeerResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPeerResponse create() => AddPeerResponse._();
  AddPeerResponse createEmptyInstance() => create();
  static $pb.PbList<AddPeerResponse> createRepeated() => $pb.PbList<AddPeerResponse>();
  @$core.pragma('dart2js:noInline')
  static AddPeerResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddPeerResponse>(create);
  static AddPeerResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
