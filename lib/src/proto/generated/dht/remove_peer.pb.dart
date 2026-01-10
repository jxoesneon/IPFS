// This is a generated file - do not edit.
//
// Generated from dht/remove_peer.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common_kademlia.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class RemovePeerRequest extends $pb.GeneratedMessage {
  factory RemovePeerRequest({
    $0.KademliaId? peerId,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  RemovePeerRequest._();

  factory RemovePeerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemovePeerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemovePeerRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.remove_peer'),
      createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'peerId',
        subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovePeerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovePeerRequest copyWith(void Function(RemovePeerRequest) updates) =>
      super.copyWith((message) => updates(message as RemovePeerRequest))
          as RemovePeerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemovePeerRequest create() => RemovePeerRequest._();
  @$core.override
  RemovePeerRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemovePeerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemovePeerRequest>(create);
  static RemovePeerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.KademliaId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($0.KademliaId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.KademliaId ensurePeerId() => $_ensure(0);
}

class RemovePeerResponse extends $pb.GeneratedMessage {
  factory RemovePeerResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  RemovePeerResponse._();

  factory RemovePeerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemovePeerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemovePeerResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.remove_peer'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovePeerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovePeerResponse copyWith(void Function(RemovePeerResponse) updates) =>
      super.copyWith((message) => updates(message as RemovePeerResponse))
          as RemovePeerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemovePeerResponse create() => RemovePeerResponse._();
  @$core.override
  RemovePeerResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemovePeerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemovePeerResponse>(create);
  static RemovePeerResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
