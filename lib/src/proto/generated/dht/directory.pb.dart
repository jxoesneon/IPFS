//
//  Generated code. Do not modify.
//  source: directory.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

/// Represents a single entry in the directory
class DirectoryEntry extends $pb.GeneratedMessage {
  factory DirectoryEntry({
    $core.String? name,
    $core.List<$core.int>? hash,
    $fixnum.Int64? size,
    $core.bool? isDirectory,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (hash != null) {
      $result.hash = hash;
    }
    if (size != null) {
      $result.size = size;
    }
    if (isDirectory != null) {
      $result.isDirectory = isDirectory;
    }
    return $result;
  }
  DirectoryEntry._() : super();
  factory DirectoryEntry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DirectoryEntry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DirectoryEntry', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'hash', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'size')
    ..aOB(4, _omitFieldNames ? '' : 'isDirectory')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DirectoryEntry clone() => DirectoryEntry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DirectoryEntry copyWith(void Function(DirectoryEntry) updates) => super.copyWith((message) => updates(message as DirectoryEntry)) as DirectoryEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DirectoryEntry create() => DirectoryEntry._();
  DirectoryEntry createEmptyInstance() => create();
  static $pb.PbList<DirectoryEntry> createRepeated() => $pb.PbList<DirectoryEntry>();
  @$core.pragma('dart2js:noInline')
  static DirectoryEntry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DirectoryEntry>(create);
  static DirectoryEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get hash => $_getN(1);
  @$pb.TagNumber(2)
  set hash($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasHash() => $_has(1);
  @$pb.TagNumber(2)
  void clearHash() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get size => $_getI64(2);
  @$pb.TagNumber(3)
  set size($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isDirectory => $_getBF(3);
  @$pb.TagNumber(4)
  set isDirectory($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIsDirectory() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsDirectory() => clearField(4);
}

/// Represents the entire directory structure
class Directory extends $pb.GeneratedMessage {
  factory Directory({
    $core.Iterable<DirectoryEntry>? entries,
    $core.String? path,
    $fixnum.Int64? totalSize,
    $core.int? numberOfFiles,
    $core.int? numberOfDirectories,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    if (path != null) {
      $result.path = path;
    }
    if (totalSize != null) {
      $result.totalSize = totalSize;
    }
    if (numberOfFiles != null) {
      $result.numberOfFiles = numberOfFiles;
    }
    if (numberOfDirectories != null) {
      $result.numberOfDirectories = numberOfDirectories;
    }
    return $result;
  }
  Directory._() : super();
  factory Directory.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Directory.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Directory', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..pc<DirectoryEntry>(1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM, subBuilder: DirectoryEntry.create)
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..aInt64(3, _omitFieldNames ? '' : 'totalSize')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'numberOfFiles', $pb.PbFieldType.O3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'numberOfDirectories', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Directory clone() => Directory()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Directory copyWith(void Function(Directory) updates) => super.copyWith((message) => updates(message as Directory)) as Directory;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Directory create() => Directory._();
  Directory createEmptyInstance() => create();
  static $pb.PbList<Directory> createRepeated() => $pb.PbList<Directory>();
  @$core.pragma('dart2js:noInline')
  static Directory getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Directory>(create);
  static Directory? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<DirectoryEntry> get entries => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalSize => $_getI64(2);
  @$pb.TagNumber(3)
  set totalSize($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTotalSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalSize() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get numberOfFiles => $_getIZ(3);
  @$pb.TagNumber(4)
  set numberOfFiles($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasNumberOfFiles() => $_has(3);
  @$pb.TagNumber(4)
  void clearNumberOfFiles() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get numberOfDirectories => $_getIZ(4);
  @$pb.TagNumber(5)
  set numberOfDirectories($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasNumberOfDirectories() => $_has(4);
  @$pb.TagNumber(5)
  void clearNumberOfDirectories() => clearField(5);
}

/// Requests to add a new directory entry
class AddDirectoryEntryRequest extends $pb.GeneratedMessage {
  factory AddDirectoryEntryRequest({
    DirectoryEntry? entry,
  }) {
    final $result = create();
    if (entry != null) {
      $result.entry = entry;
    }
    return $result;
  }
  AddDirectoryEntryRequest._() : super();
  factory AddDirectoryEntryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AddDirectoryEntryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AddDirectoryEntryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<DirectoryEntry>(1, _omitFieldNames ? '' : 'entry', subBuilder: DirectoryEntry.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AddDirectoryEntryRequest clone() => AddDirectoryEntryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AddDirectoryEntryRequest copyWith(void Function(AddDirectoryEntryRequest) updates) => super.copyWith((message) => updates(message as AddDirectoryEntryRequest)) as AddDirectoryEntryRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddDirectoryEntryRequest create() => AddDirectoryEntryRequest._();
  AddDirectoryEntryRequest createEmptyInstance() => create();
  static $pb.PbList<AddDirectoryEntryRequest> createRepeated() => $pb.PbList<AddDirectoryEntryRequest>();
  @$core.pragma('dart2js:noInline')
  static AddDirectoryEntryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddDirectoryEntryRequest>(create);
  static AddDirectoryEntryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  DirectoryEntry get entry => $_getN(0);
  @$pb.TagNumber(1)
  set entry(DirectoryEntry v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasEntry() => $_has(0);
  @$pb.TagNumber(1)
  void clearEntry() => clearField(1);
  @$pb.TagNumber(1)
  DirectoryEntry ensureEntry() => $_ensure(0);
}

/// Response after adding a new directory entry
class AddDirectoryEntryResponse extends $pb.GeneratedMessage {
  factory AddDirectoryEntryResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  AddDirectoryEntryResponse._() : super();
  factory AddDirectoryEntryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AddDirectoryEntryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AddDirectoryEntryResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AddDirectoryEntryResponse clone() => AddDirectoryEntryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AddDirectoryEntryResponse copyWith(void Function(AddDirectoryEntryResponse) updates) => super.copyWith((message) => updates(message as AddDirectoryEntryResponse)) as AddDirectoryEntryResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddDirectoryEntryResponse create() => AddDirectoryEntryResponse._();
  AddDirectoryEntryResponse createEmptyInstance() => create();
  static $pb.PbList<AddDirectoryEntryResponse> createRepeated() => $pb.PbList<AddDirectoryEntryResponse>();
  @$core.pragma('dart2js:noInline')
  static AddDirectoryEntryResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddDirectoryEntryResponse>(create);
  static AddDirectoryEntryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}

/// Requests to remove a directory entry
class RemoveDirectoryEntryRequest extends $pb.GeneratedMessage {
  factory RemoveDirectoryEntryRequest({
    $core.String? name,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    return $result;
  }
  RemoveDirectoryEntryRequest._() : super();
  factory RemoveDirectoryEntryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RemoveDirectoryEntryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RemoveDirectoryEntryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RemoveDirectoryEntryRequest clone() => RemoveDirectoryEntryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RemoveDirectoryEntryRequest copyWith(void Function(RemoveDirectoryEntryRequest) updates) => super.copyWith((message) => updates(message as RemoveDirectoryEntryRequest)) as RemoveDirectoryEntryRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveDirectoryEntryRequest create() => RemoveDirectoryEntryRequest._();
  RemoveDirectoryEntryRequest createEmptyInstance() => create();
  static $pb.PbList<RemoveDirectoryEntryRequest> createRepeated() => $pb.PbList<RemoveDirectoryEntryRequest>();
  @$core.pragma('dart2js:noInline')
  static RemoveDirectoryEntryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemoveDirectoryEntryRequest>(create);
  static RemoveDirectoryEntryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);
}

/// Response after removing a directory entry
class RemoveDirectoryEntryResponse extends $pb.GeneratedMessage {
  factory RemoveDirectoryEntryResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  RemoveDirectoryEntryResponse._() : super();
  factory RemoveDirectoryEntryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RemoveDirectoryEntryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RemoveDirectoryEntryResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RemoveDirectoryEntryResponse clone() => RemoveDirectoryEntryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RemoveDirectoryEntryResponse copyWith(void Function(RemoveDirectoryEntryResponse) updates) => super.copyWith((message) => updates(message as RemoveDirectoryEntryResponse)) as RemoveDirectoryEntryResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveDirectoryEntryResponse create() => RemoveDirectoryEntryResponse._();
  RemoveDirectoryEntryResponse createEmptyInstance() => create();
  static $pb.PbList<RemoveDirectoryEntryResponse> createRepeated() => $pb.PbList<RemoveDirectoryEntryResponse>();
  @$core.pragma('dart2js:noInline')
  static RemoveDirectoryEntryResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemoveDirectoryEntryResponse>(create);
  static RemoveDirectoryEntryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}

/// Requests to list all entries in a directory
class ListDirectoryRequest extends $pb.GeneratedMessage {
  factory ListDirectoryRequest({
    $core.String? path,
  }) {
    final $result = create();
    if (path != null) {
      $result.path = path;
    }
    return $result;
  }
  ListDirectoryRequest._() : super();
  factory ListDirectoryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDirectoryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDirectoryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDirectoryRequest clone() => ListDirectoryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDirectoryRequest copyWith(void Function(ListDirectoryRequest) updates) => super.copyWith((message) => updates(message as ListDirectoryRequest)) as ListDirectoryRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDirectoryRequest create() => ListDirectoryRequest._();
  ListDirectoryRequest createEmptyInstance() => create();
  static $pb.PbList<ListDirectoryRequest> createRepeated() => $pb.PbList<ListDirectoryRequest>();
  @$core.pragma('dart2js:noInline')
  static ListDirectoryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDirectoryRequest>(create);
  static ListDirectoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => clearField(1);
}

/// Response containing the list of directory entries
class ListDirectoryResponse extends $pb.GeneratedMessage {
  factory ListDirectoryResponse({
    $core.Iterable<DirectoryEntry>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  ListDirectoryResponse._() : super();
  factory ListDirectoryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDirectoryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDirectoryResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..pc<DirectoryEntry>(1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM, subBuilder: DirectoryEntry.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDirectoryResponse clone() => ListDirectoryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDirectoryResponse copyWith(void Function(ListDirectoryResponse) updates) => super.copyWith((message) => updates(message as ListDirectoryResponse)) as ListDirectoryResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDirectoryResponse create() => ListDirectoryResponse._();
  ListDirectoryResponse createEmptyInstance() => create();
  static $pb.PbList<ListDirectoryResponse> createRepeated() => $pb.PbList<ListDirectoryResponse>();
  @$core.pragma('dart2js:noInline')
  static ListDirectoryResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDirectoryResponse>(create);
  static ListDirectoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<DirectoryEntry> get entries => $_getList(0);
}

/// Request to get the details of a specific directory entry
class GetDirectoryEntryRequest extends $pb.GeneratedMessage {
  factory GetDirectoryEntryRequest({
    $core.String? name,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    return $result;
  }
  GetDirectoryEntryRequest._() : super();
  factory GetDirectoryEntryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetDirectoryEntryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetDirectoryEntryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetDirectoryEntryRequest clone() => GetDirectoryEntryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetDirectoryEntryRequest copyWith(void Function(GetDirectoryEntryRequest) updates) => super.copyWith((message) => updates(message as GetDirectoryEntryRequest)) as GetDirectoryEntryRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetDirectoryEntryRequest create() => GetDirectoryEntryRequest._();
  GetDirectoryEntryRequest createEmptyInstance() => create();
  static $pb.PbList<GetDirectoryEntryRequest> createRepeated() => $pb.PbList<GetDirectoryEntryRequest>();
  @$core.pragma('dart2js:noInline')
  static GetDirectoryEntryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetDirectoryEntryRequest>(create);
  static GetDirectoryEntryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);
}

/// Response containing the directory entry details
class GetDirectoryEntryResponse extends $pb.GeneratedMessage {
  factory GetDirectoryEntryResponse({
    DirectoryEntry? entry,
  }) {
    final $result = create();
    if (entry != null) {
      $result.entry = entry;
    }
    return $result;
  }
  GetDirectoryEntryResponse._() : super();
  factory GetDirectoryEntryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetDirectoryEntryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetDirectoryEntryResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<DirectoryEntry>(1, _omitFieldNames ? '' : 'entry', subBuilder: DirectoryEntry.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetDirectoryEntryResponse clone() => GetDirectoryEntryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetDirectoryEntryResponse copyWith(void Function(GetDirectoryEntryResponse) updates) => super.copyWith((message) => updates(message as GetDirectoryEntryResponse)) as GetDirectoryEntryResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetDirectoryEntryResponse create() => GetDirectoryEntryResponse._();
  GetDirectoryEntryResponse createEmptyInstance() => create();
  static $pb.PbList<GetDirectoryEntryResponse> createRepeated() => $pb.PbList<GetDirectoryEntryResponse>();
  @$core.pragma('dart2js:noInline')
  static GetDirectoryEntryResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetDirectoryEntryResponse>(create);
  static GetDirectoryEntryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  DirectoryEntry get entry => $_getN(0);
  @$pb.TagNumber(1)
  set entry(DirectoryEntry v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasEntry() => $_has(0);
  @$pb.TagNumber(1)
  void clearEntry() => clearField(1);
  @$pb.TagNumber(1)
  DirectoryEntry ensureEntry() => $_ensure(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
