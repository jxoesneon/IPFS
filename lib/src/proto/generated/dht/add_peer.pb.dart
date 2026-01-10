// This is a generated file - do not edit.
//
// Generated from dht/add_peer.proto.

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

class AddPeerRequest extends $pb.GeneratedMessage {
  factory AddPeerRequest({
    $0.KademliaId? peerId,
    $0.KademliaId? associatedPeerId,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (associatedPeerId != null) result.associatedPeerId = associatedPeerId;
    return result;
  }

  AddPeerRequest._();

  factory AddPeerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddPeerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AddPeerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.add_peer'),
      createEmptyInstance: create)
    ..aOM<$0.KademliaId>(1, _omitFieldNames ? '' : 'peerId', subBuilder: $0.KademliaId.create)
    ..aOM<$0.KademliaId>(2, _omitFieldNames ? '' : 'associatedPeerId',
        subBuilder: $0.KademliaId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPeerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPeerRequest copyWith(void Function(AddPeerRequest) updates) =>
      super.copyWith((message) => updates(message as AddPeerRequest)) as AddPeerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPeerRequest create() => AddPeerRequest._();
  @$core.override
  AddPeerRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddPeerRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddPeerRequest>(create);
  static AddPeerRequest? _defaultInstance;

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

  @$pb.TagNumber(2)
  $0.KademliaId get associatedPeerId => $_getN(1);
  @$pb.TagNumber(2)
  set associatedPeerId($0.KademliaId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAssociatedPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAssociatedPeerId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.KademliaId ensureAssociatedPeerId() => $_ensure(1);
}

class AddPeerResponse extends $pb.GeneratedMessage {
  factory AddPeerResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  AddPeerResponse._();

  factory AddPeerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddPeerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AddPeerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.add_peer'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPeerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPeerResponse copyWith(void Function(AddPeerResponse) updates) =>
      super.copyWith((message) => updates(message as AddPeerResponse)) as AddPeerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPeerResponse create() => AddPeerResponse._();
  @$core.override
  AddPeerResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddPeerResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddPeerResponse>(create);
  static AddPeerResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
