//
//  Generated code. Do not modify.
//  source: dht/dht.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

/// Represents a peer participating in the DHT.
class DHTPeer extends $pb.GeneratedMessage {
  factory DHTPeer({
    $core.List<$core.int>? id,
    $core.Iterable<$core.String>? addrs,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (addrs != null) {
      $result.addrs.addAll(addrs);
    }
    return $result;
  }
  DHTPeer._() : super();
  factory DHTPeer.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DHTPeer.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DHTPeer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OY)
    ..pPS(2, _omitFieldNames ? '' : 'addrs')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DHTPeer clone() => DHTPeer()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DHTPeer copyWith(void Function(DHTPeer) updates) =>
      super.copyWith((message) => updates(message as DHTPeer)) as DHTPeer;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DHTPeer create() => DHTPeer._();
  DHTPeer createEmptyInstance() => create();
  static $pb.PbList<DHTPeer> createRepeated() => $pb.PbList<DHTPeer>();
  @$core.pragma('dart2js:noInline')
  static DHTPeer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DHTPeer>(create);
  static DHTPeer? _defaultInstance;

  /// Required: The ID of the peer.
  @$pb.TagNumber(1)
  $core.List<$core.int> get id => $_getN(0);
  @$pb.TagNumber(1)
  set id($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  /// Repeated: The multiaddresses of the peer.
  @$pb.TagNumber(2)
  $core.List<$core.String> get addrs => $_getList(1);
}

/// Represents a record stored in the DHT.
class Record extends $pb.GeneratedMessage {
  factory Record({
    $core.List<$core.int>? key,
    $core.List<$core.int>? value,
    DHTPeer? publisher,
    $fixnum.Int64? sequence,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (value != null) {
      $result.value = value;
    }
    if (publisher != null) {
      $result.publisher = publisher;
    }
    if (sequence != null) {
      $result.sequence = sequence;
    }
    return $result;
  }
  Record._() : super();
  factory Record.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Record.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Record',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..aOM<DHTPeer>(3, _omitFieldNames ? '' : 'publisher',
        subBuilder: DHTPeer.create)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'sequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Record clone() => Record()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Record copyWith(void Function(Record) updates) =>
      super.copyWith((message) => updates(message as Record)) as Record;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Record create() => Record._();
  Record createEmptyInstance() => create();
  static $pb.PbList<Record> createRepeated() => $pb.PbList<Record>();
  @$core.pragma('dart2js:noInline')
  static Record getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Record>(create);
  static Record? _defaultInstance;

  /// Required: The key of the record.
  @$pb.TagNumber(1)
  $core.List<$core.int> get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  /// Required: The value of the record.
  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);

  /// Optional: The publisher of the record.
  @$pb.TagNumber(3)
  DHTPeer get publisher => $_getN(2);
  @$pb.TagNumber(3)
  set publisher(DHTPeer v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasPublisher() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublisher() => clearField(3);
  @$pb.TagNumber(3)
  DHTPeer ensurePublisher() => $_ensure(2);

  /// Optional: The sequence number of the record.
  @$pb.TagNumber(4)
  $fixnum.Int64 get sequence => $_getI64(3);
  @$pb.TagNumber(4)
  set sequence($fixnum.Int64 v) {
    $_setInt64(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSequence() => $_has(3);
  @$pb.TagNumber(4)
  void clearSequence() => clearField(4);
}

/// Represents a request to find providers for a key.
class FindProvidersRequest extends $pb.GeneratedMessage {
  factory FindProvidersRequest({
    $core.List<$core.int>? key,
    $core.int? count,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (count != null) {
      $result.count = count;
    }
    return $result;
  }
  FindProvidersRequest._() : super();
  factory FindProvidersRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FindProvidersRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindProvidersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'count', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FindProvidersRequest clone() =>
      FindProvidersRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FindProvidersRequest copyWith(void Function(FindProvidersRequest) updates) =>
      super.copyWith((message) => updates(message as FindProvidersRequest))
          as FindProvidersRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindProvidersRequest create() => FindProvidersRequest._();
  FindProvidersRequest createEmptyInstance() => create();
  static $pb.PbList<FindProvidersRequest> createRepeated() =>
      $pb.PbList<FindProvidersRequest>();
  @$core.pragma('dart2js:noInline')
  static FindProvidersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindProvidersRequest>(create);
  static FindProvidersRequest? _defaultInstance;

  /// Required: The key to find providers for.
  @$pb.TagNumber(1)
  $core.List<$core.int> get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  /// Optional: The maximum number of providers to return (default: unlimited).
  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => clearField(2);
}

/// Represents a response to a FindProviders request.
class FindProvidersResponse extends $pb.GeneratedMessage {
  factory FindProvidersResponse({
    $core.Iterable<DHTPeer>? providers,
    $core.bool? closerPeers,
  }) {
    final $result = create();
    if (providers != null) {
      $result.providers.addAll(providers);
    }
    if (closerPeers != null) {
      $result.closerPeers = closerPeers;
    }
    return $result;
  }
  FindProvidersResponse._() : super();
  factory FindProvidersResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FindProvidersResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindProvidersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..pc<DHTPeer>(1, _omitFieldNames ? '' : 'providers', $pb.PbFieldType.PM,
        subBuilder: DHTPeer.create)
    ..aOB(2, _omitFieldNames ? '' : 'closerPeers', protoName: 'closerPeers')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FindProvidersResponse clone() =>
      FindProvidersResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FindProvidersResponse copyWith(
          void Function(FindProvidersResponse) updates) =>
      super.copyWith((message) => updates(message as FindProvidersResponse))
          as FindProvidersResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindProvidersResponse create() => FindProvidersResponse._();
  FindProvidersResponse createEmptyInstance() => create();
  static $pb.PbList<FindProvidersResponse> createRepeated() =>
      $pb.PbList<FindProvidersResponse>();
  @$core.pragma('dart2js:noInline')
  static FindProvidersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindProvidersResponse>(create);
  static FindProvidersResponse? _defaultInstance;

  /// Repeated: The providers found for the key.
  @$pb.TagNumber(1)
  $core.List<DHTPeer> get providers => $_getList(0);

  /// Optional: Whether or not closer peers were found during the search.
  @$pb.TagNumber(2)
  $core.bool get closerPeers => $_getBF(1);
  @$pb.TagNumber(2)
  set closerPeers($core.bool v) {
    $_setBool(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasCloserPeers() => $_has(1);
  @$pb.TagNumber(2)
  void clearCloserPeers() => clearField(2);
}

/// Represents a request to provide a record for a key.
class ProvideRequest extends $pb.GeneratedMessage {
  factory ProvideRequest({
    $core.List<$core.int>? key,
    DHTPeer? provider,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (provider != null) {
      $result.provider = provider;
    }
    return $result;
  }
  ProvideRequest._() : super();
  factory ProvideRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ProvideRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProvideRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
    ..aOM<DHTPeer>(2, _omitFieldNames ? '' : 'provider',
        subBuilder: DHTPeer.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ProvideRequest clone() => ProvideRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ProvideRequest copyWith(void Function(ProvideRequest) updates) =>
      super.copyWith((message) => updates(message as ProvideRequest))
          as ProvideRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProvideRequest create() => ProvideRequest._();
  ProvideRequest createEmptyInstance() => create();
  static $pb.PbList<ProvideRequest> createRepeated() =>
      $pb.PbList<ProvideRequest>();
  @$core.pragma('dart2js:noInline')
  static ProvideRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProvideRequest>(create);
  static ProvideRequest? _defaultInstance;

  /// Required: The key for which the record is being provided.
  @$pb.TagNumber(1)
  $core.List<$core.int> get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  /// Optional: The peer providing the record.
  @$pb.TagNumber(2)
  DHTPeer get provider => $_getN(1);
  @$pb.TagNumber(2)
  set provider(DHTPeer v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasProvider() => $_has(1);
  @$pb.TagNumber(2)
  void clearProvider() => clearField(2);
  @$pb.TagNumber(2)
  DHTPeer ensureProvider() => $_ensure(1);
}

/// Represents a response to a Provide request.
class ProvideResponse extends $pb.GeneratedMessage {
  factory ProvideResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  ProvideResponse._() : super();
  factory ProvideResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ProvideResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProvideResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ProvideResponse clone() => ProvideResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ProvideResponse copyWith(void Function(ProvideResponse) updates) =>
      super.copyWith((message) => updates(message as ProvideResponse))
          as ProvideResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProvideResponse create() => ProvideResponse._();
  ProvideResponse createEmptyInstance() => create();
  static $pb.PbList<ProvideResponse> createRepeated() =>
      $pb.PbList<ProvideResponse>();
  @$core.pragma('dart2js:noInline')
  static ProvideResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProvideResponse>(create);
  static ProvideResponse? _defaultInstance;

  /// Required: Whether or not the record was successfully provided.
  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) {
    $_setBool(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}

/// Represents a request to find a value for a key.
class FindValueRequest extends $pb.GeneratedMessage {
  factory FindValueRequest({
    $core.List<$core.int>? key,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    return $result;
  }
  FindValueRequest._() : super();
  factory FindValueRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FindValueRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindValueRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FindValueRequest clone() => FindValueRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FindValueRequest copyWith(void Function(FindValueRequest) updates) =>
      super.copyWith((message) => updates(message as FindValueRequest))
          as FindValueRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindValueRequest create() => FindValueRequest._();
  FindValueRequest createEmptyInstance() => create();
  static $pb.PbList<FindValueRequest> createRepeated() =>
      $pb.PbList<FindValueRequest>();
  @$core.pragma('dart2js:noInline')
  static FindValueRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindValueRequest>(create);
  static FindValueRequest? _defaultInstance;

  /// Required: The key to find the value for.
  @$pb.TagNumber(1)
  $core.List<$core.int> get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);
}

/// Represents a response to a FindValue request.
class FindValueResponse extends $pb.GeneratedMessage {
  factory FindValueResponse({
    $core.List<$core.int>? value,
    $core.Iterable<DHTPeer>? closerPeers,
  }) {
    final $result = create();
    if (value != null) {
      $result.value = value;
    }
    if (closerPeers != null) {
      $result.closerPeers.addAll(closerPeers);
    }
    return $result;
  }
  FindValueResponse._() : super();
  factory FindValueResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FindValueResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindValueResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..pc<DHTPeer>(2, _omitFieldNames ? '' : 'closerPeers', $pb.PbFieldType.PM,
        protoName: 'closerPeers', subBuilder: DHTPeer.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FindValueResponse clone() => FindValueResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FindValueResponse copyWith(void Function(FindValueResponse) updates) =>
      super.copyWith((message) => updates(message as FindValueResponse))
          as FindValueResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindValueResponse create() => FindValueResponse._();
  FindValueResponse createEmptyInstance() => create();
  static $pb.PbList<FindValueResponse> createRepeated() =>
      $pb.PbList<FindValueResponse>();
  @$core.pragma('dart2js:noInline')
  static FindValueResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindValueResponse>(create);
  static FindValueResponse? _defaultInstance;

  /// Optional: The value found for the key (if present).
  @$pb.TagNumber(1)
  $core.List<$core.int> get value => $_getN(0);
  @$pb.TagNumber(1)
  set value($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => clearField(1);

  /// Optional: The peers that are closer to the key (if no direct value is found).
  @$pb.TagNumber(2)
  $core.List<DHTPeer> get closerPeers => $_getList(1);
}

/// Represents a request to store a value for a key.
class PutValueRequest extends $pb.GeneratedMessage {
  factory PutValueRequest({
    $core.List<$core.int>? key,
    $core.List<$core.int>? value,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  PutValueRequest._() : super();
  factory PutValueRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PutValueRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PutValueRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PutValueRequest clone() => PutValueRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PutValueRequest copyWith(void Function(PutValueRequest) updates) =>
      super.copyWith((message) => updates(message as PutValueRequest))
          as PutValueRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PutValueRequest create() => PutValueRequest._();
  PutValueRequest createEmptyInstance() => create();
  static $pb.PbList<PutValueRequest> createRepeated() =>
      $pb.PbList<PutValueRequest>();
  @$core.pragma('dart2js:noInline')
  static PutValueRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PutValueRequest>(create);
  static PutValueRequest? _defaultInstance;

  /// Required: The key to store the value for.
  @$pb.TagNumber(1)
  $core.List<$core.int> get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  /// Required: The value to store.
  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);
}

/// Represents a response to a PutValue request.
class PutValueResponse extends $pb.GeneratedMessage {
  factory PutValueResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  PutValueResponse._() : super();
  factory PutValueResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PutValueResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PutValueResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PutValueResponse clone() => PutValueResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PutValueResponse copyWith(void Function(PutValueResponse) updates) =>
      super.copyWith((message) => updates(message as PutValueResponse))
          as PutValueResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PutValueResponse create() => PutValueResponse._();
  PutValueResponse createEmptyInstance() => create();
  static $pb.PbList<PutValueResponse> createRepeated() =>
      $pb.PbList<PutValueResponse>();
  @$core.pragma('dart2js:noInline')
  static PutValueResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PutValueResponse>(create);
  static PutValueResponse? _defaultInstance;

  /// Required: Whether or not the value was successfully stored.
  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) {
    $_setBool(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}

/// Represents a request to find a peer in the DHT by their ID.
class FindNodeRequest extends $pb.GeneratedMessage {
  factory FindNodeRequest({
    $core.List<$core.int>? peerId,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    return $result;
  }
  FindNodeRequest._() : super();
  factory FindNodeRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FindNodeRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindNodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'peerId', $pb.PbFieldType.OY,
        protoName: 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FindNodeRequest clone() => FindNodeRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FindNodeRequest copyWith(void Function(FindNodeRequest) updates) =>
      super.copyWith((message) => updates(message as FindNodeRequest))
          as FindNodeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindNodeRequest create() => FindNodeRequest._();
  FindNodeRequest createEmptyInstance() => create();
  static $pb.PbList<FindNodeRequest> createRepeated() =>
      $pb.PbList<FindNodeRequest>();
  @$core.pragma('dart2js:noInline')
  static FindNodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindNodeRequest>(create);
  static FindNodeRequest? _defaultInstance;

  /// Required: The ID of the peer to find.
  @$pb.TagNumber(1)
  $core.List<$core.int> get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);
}

/// Represents a response to a FindNode request.
class FindNodeResponse extends $pb.GeneratedMessage {
  factory FindNodeResponse({
    $core.Iterable<DHTPeer>? closerPeers,
  }) {
    final $result = create();
    if (closerPeers != null) {
      $result.closerPeers.addAll(closerPeers);
    }
    return $result;
  }
  FindNodeResponse._() : super();
  factory FindNodeResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FindNodeResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindNodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..pc<DHTPeer>(1, _omitFieldNames ? '' : 'closerPeers', $pb.PbFieldType.PM,
        protoName: 'closerPeers', subBuilder: DHTPeer.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FindNodeResponse clone() => FindNodeResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FindNodeResponse copyWith(void Function(FindNodeResponse) updates) =>
      super.copyWith((message) => updates(message as FindNodeResponse))
          as FindNodeResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindNodeResponse create() => FindNodeResponse._();
  FindNodeResponse createEmptyInstance() => create();
  static $pb.PbList<FindNodeResponse> createRepeated() =>
      $pb.PbList<FindNodeResponse>();
  @$core.pragma('dart2js:noInline')
  static FindNodeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindNodeResponse>(create);
  static FindNodeResponse? _defaultInstance;

  /// Repeated: The peers that are closer to the requested peer ID.
  @$pb.TagNumber(1)
  $core.List<DHTPeer> get closerPeers => $_getList(0);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
