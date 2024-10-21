//
//  Generated code. Do not modify.
//  source: remove_peer.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $0;

class RemovePeerRequest extends $pb.GeneratedMessage {
  factory RemovePeerRequest({
    $0.KademliaId? peerId,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  RemovePeerRequest._() : super();
  factory RemovePeerRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RemovePeerRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RemovePeerRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.remove_peer'), createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'peerId', subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RemovePeerRequest clone() => RemovePeerRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RemovePeerRequest copyWith(void Function(RemovePeerRequest) updates) => super.copyWith((message) => updates(message as RemovePeerRequest)) as RemovePeerRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemovePeerRequest create() => RemovePeerRequest._();
  RemovePeerRequest createEmptyInstance() => create();
  static $pb.PbList<RemovePeerRequest> createRepeated() => $pb.PbList<RemovePeerRequest>();
  @$core.pragma('dart2js:noInline')
  static RemovePeerRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemovePeerRequest>(create);
  static RemovePeerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.KademliaId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($0.KademliaId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);
  @$pb.TagNumber(1)
  $0.KademliaId ensurePeerId() => $_ensure(0);
}

class RemovePeerResponse extends $pb.GeneratedMessage {
  factory RemovePeerResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  RemovePeerResponse._() : super();
  factory RemovePeerResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RemovePeerResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RemovePeerResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.remove_peer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RemovePeerResponse clone() => RemovePeerResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RemovePeerResponse copyWith(void Function(RemovePeerResponse) updates) => super.copyWith((message) => updates(message as RemovePeerResponse)) as RemovePeerResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemovePeerResponse create() => RemovePeerResponse._();
  RemovePeerResponse createEmptyInstance() => create();
  static $pb.PbList<RemovePeerResponse> createRepeated() => $pb.PbList<RemovePeerResponse>();
  @$core.pragma('dart2js:noInline')
  static RemovePeerResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemovePeerResponse>(create);
  static RemovePeerResponse? _defaultInstance;

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
