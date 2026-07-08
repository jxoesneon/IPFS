// Copyright (c) 2024, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// Minimal hand-written FFI bindings for the Cloudflare quiche C API.
// This is a subset sufficient for a basic libp2p QUIC transport; more functions
// can be added as needed.

// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

/// The loaded native quiche library. Exposed so that consumers can probe
/// availability without attempting to use any function.
final DynamicLibrary quicheLibrary = _loadQuiche();

DynamicLibrary _loadQuiche() {
  final names = _nativeLibraryNames();
  final searchPaths = _nativeLibrarySearchPaths();
  for (final dir in searchPaths) {
    for (final name in names) {
      final path = '$dir${Platform.pathSeparator}$name';
      try {
        return DynamicLibrary.open(path);
      } catch (_) {
        // Continue trying.
      }
    }
  }
  for (final name in names) {
    try {
      return DynamicLibrary.open(name);
    } catch (_) {
      // Continue trying.
    }
  }
  throw UnsupportedError(
    'Unable to load quiche native library. '
    'Ensure quiche.dll / libquiche.so / libquiche.dylib is available in PATH or package native/ directory.',
  );
}

List<String> _nativeLibraryNames() {
  if (Platform.isWindows) {
    return ['quiche.dll', 'libquiche.dll'];
  }
  if (Platform.isLinux || Platform.isAndroid) {
    return ['libquiche.so'];
  }
  if (Platform.isMacOS || Platform.isIOS) {
    return ['libquiche.dylib'];
  }
  return ['libquiche.so', 'libquiche.dylib', 'quiche.dll'];
}

List<String> _nativeLibrarySearchPaths() {
  final paths = <String>[];
  try {
    final packageUri = Uri.parse('package:dart_ipfs_quic/dart_ipfs_quic.dart');
    final resolved = Isolate.resolvePackageUriSync(packageUri);
    if (resolved != null) {
      final packageDir = File.fromUri(resolved).parent.path;
      paths.add('$packageDir${Platform.pathSeparator}native');
    }
  } catch (_) {
    // Ignore package resolution failure.
  }
  // Fallback for execution from within the package directory.
  final script = Platform.script.toFilePath();
  final packageMarker = 'packages${Platform.pathSeparator}dart_ipfs_quic';
  if (script.contains(packageMarker)) {
    final idx = script.indexOf(packageMarker);
    final packageRoot = script.substring(0, idx + packageMarker.length);
    paths.add('$packageRoot${Platform.pathSeparator}native');
  }
  // Check current working directory and native/ subdir.
  paths.add(Directory.current.path);
  paths.add('${Directory.current.path}${Platform.pathSeparator}native');
  return paths;
}

// Opaque structs.

final class quiche_config extends Opaque {}

final class quiche_conn extends Opaque {}

final class quiche_stream_iter extends Opaque {}

// Error codes.

const int QUICHE_ERR_DONE = -1;
const int QUICHE_ERR_BUFFER_TOO_SHORT = -2;
const int QUICHE_ERR_UNKNOWN_VERSION = -3;
const int QUICHE_ERR_INVALID_FRAME = -4;
const int QUICHE_ERR_INVALID_PACKET = -5;
const int QUICHE_ERR_INVALID_STATE = -6;
const int QUICHE_ERR_INVALID_STREAM_STATE = -7;
const int QUICHE_ERR_INVALID_TRANSPORT_PARAM = -8;
const int QUICHE_ERR_CRYPTO_FAIL = -9;
const int QUICHE_ERR_TLS_FAIL = -10;
const int QUICHE_ERR_FLOW_CONTROL = -11;
const int QUICHE_ERR_STREAM_LIMIT = -12;
const int QUICHE_ERR_FINAL_SIZE = -13;
const int QUICHE_ERR_CONGESTION_CONTROL = -14;
const int QUICHE_ERR_STREAM_STOPPED = -15;
const int QUICHE_ERR_STREAM_RESET = -16;
const int QUICHE_ERR_ID_LIMIT = -17;
const int QUICHE_ERR_OUT_OF_IDENTIFIERS = -18;
const int QUICHE_ERR_KEY_UPDATE = -19;
const int QUICHE_ERR_CRYPTO_BUFFER_EXCEEDED = -20;

const int QUICHE_SHUTDOWN_READ = 0;
const int QUICHE_SHUTDOWN_WRITE = 1;

const int QUICHE_PROTOCOL_VERSION = 0x00000001;
const int QUICHE_MAX_CONN_ID_LEN = 20;
const int QUICHE_MIN_CLIENT_INITIAL_LEN = 1200;

// Function bindings.

final quiche_versionPtr =
    _lookup<NativeFunction<Pointer<Utf8> Function()>>('quiche_version');
String quiche_version() =>
    quiche_versionPtr.asFunction<Pointer<Utf8> Function()>()().toDartString();

final quiche_enable_debug_loggingPtr = _lookup<
    NativeFunction<
        Int32 Function(
            Pointer<
                NativeFunction<Void Function(Pointer<Utf8>, Pointer<Void>)>>,
            Pointer<Void>)>>('quiche_enable_debug_logging');
int quiche_enable_debug_logging(
        Pointer<NativeFunction<Void Function(Pointer<Utf8>, Pointer<Void>)>> cb,
        Pointer<Void> argp) =>
    quiche_enable_debug_loggingPtr.asFunction<
        int Function(
            Pointer<
                NativeFunction<Void Function(Pointer<Utf8>, Pointer<Void>)>>,
            Pointer<Void>)>()(cb, argp);

final quiche_config_newPtr =
    _lookup<NativeFunction<Pointer<quiche_config> Function(Uint32)>>(
        'quiche_config_new');
Pointer<quiche_config> quiche_config_new(int version) => quiche_config_newPtr
    .asFunction<Pointer<quiche_config> Function(int)>()(version);

final quiche_config_load_cert_chain_from_pem_filePtr = _lookup<
        NativeFunction<Int32 Function(Pointer<quiche_config>, Pointer<Utf8>)>>(
    'quiche_config_load_cert_chain_from_pem_file');
int quiche_config_load_cert_chain_from_pem_file(
    Pointer<quiche_config> config, String path) {
  final pathPtr = path.toNativeUtf8();
  try {
    return quiche_config_load_cert_chain_from_pem_filePtr
            .asFunction<int Function(Pointer<quiche_config>, Pointer<Utf8>)>()(
        config, pathPtr);
  } finally {
    calloc.free(pathPtr);
  }
}

final quiche_config_load_priv_key_from_pem_filePtr = _lookup<
        NativeFunction<Int32 Function(Pointer<quiche_config>, Pointer<Utf8>)>>(
    'quiche_config_load_priv_key_from_pem_file');
int quiche_config_load_priv_key_from_pem_file(
    Pointer<quiche_config> config, String path) {
  final pathPtr = path.toNativeUtf8();
  try {
    return quiche_config_load_priv_key_from_pem_filePtr
            .asFunction<int Function(Pointer<quiche_config>, Pointer<Utf8>)>()(
        config, pathPtr);
  } finally {
    calloc.free(pathPtr);
  }
}

final quiche_config_set_application_protosPtr = _lookup<
    NativeFunction<
        Int32 Function(Pointer<quiche_config>, Pointer<Uint8>,
            IntPtr)>>('quiche_config_set_application_protos');
int quiche_config_set_application_protos(
    Pointer<quiche_config> config, List<int> protos) {
  final ptr = calloc<Uint8>(protos.length);
  try {
    for (var i = 0; i < protos.length; i++) {
      ptr[i] = protos[i];
    }
    return quiche_config_set_application_protosPtr.asFunction<
            int Function(Pointer<quiche_config>, Pointer<Uint8>, int)>()(
        config, ptr, protos.length);
  } finally {
    calloc.free(ptr);
  }
}

final quiche_config_verify_peerPtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, Bool)>>(
        'quiche_config_verify_peer');
void quiche_config_verify_peer(Pointer<quiche_config> config, bool v) =>
    quiche_config_verify_peerPtr
        .asFunction<void Function(Pointer<quiche_config>, bool)>()(config, v);

final quiche_config_set_max_idle_timeoutPtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, Uint64)>>(
        'quiche_config_set_max_idle_timeout');
void quiche_config_set_max_idle_timeout(Pointer<quiche_config> config, int v) =>
    quiche_config_set_max_idle_timeoutPtr
        .asFunction<void Function(Pointer<quiche_config>, int)>()(config, v);

final quiche_config_set_max_recv_udp_payload_sizePtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, IntPtr)>>(
        'quiche_config_set_max_recv_udp_payload_size');
void quiche_config_set_max_recv_udp_payload_size(
        Pointer<quiche_config> config, int v) =>
    quiche_config_set_max_recv_udp_payload_sizePtr
        .asFunction<void Function(Pointer<quiche_config>, int)>()(config, v);

final quiche_config_set_max_send_udp_payload_sizePtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, IntPtr)>>(
        'quiche_config_set_max_send_udp_payload_size');
void quiche_config_set_max_send_udp_payload_size(
        Pointer<quiche_config> config, int v) =>
    quiche_config_set_max_send_udp_payload_sizePtr
        .asFunction<void Function(Pointer<quiche_config>, int)>()(config, v);

final quiche_config_set_initial_max_dataPtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, Uint64)>>(
        'quiche_config_set_initial_max_data');
void quiche_config_set_initial_max_data(Pointer<quiche_config> config, int v) =>
    quiche_config_set_initial_max_dataPtr
        .asFunction<void Function(Pointer<quiche_config>, int)>()(config, v);

final quiche_config_set_initial_max_stream_data_bidi_localPtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, Uint64)>>(
        'quiche_config_set_initial_max_stream_data_bidi_local');
void quiche_config_set_initial_max_stream_data_bidi_local(
        Pointer<quiche_config> config, int v) =>
    quiche_config_set_initial_max_stream_data_bidi_localPtr
        .asFunction<void Function(Pointer<quiche_config>, int)>()(config, v);

final quiche_config_set_initial_max_stream_data_bidi_remotePtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, Uint64)>>(
        'quiche_config_set_initial_max_stream_data_bidi_remote');
void quiche_config_set_initial_max_stream_data_bidi_remote(
        Pointer<quiche_config> config, int v) =>
    quiche_config_set_initial_max_stream_data_bidi_remotePtr
        .asFunction<void Function(Pointer<quiche_config>, int)>()(config, v);

final quiche_config_set_initial_max_streams_bidiPtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, Uint64)>>(
        'quiche_config_set_initial_max_streams_bidi');
void quiche_config_set_initial_max_streams_bidi(
        Pointer<quiche_config> config, int v) =>
    quiche_config_set_initial_max_streams_bidiPtr
        .asFunction<void Function(Pointer<quiche_config>, int)>()(config, v);

final quiche_config_set_initial_max_streams_uniPtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>, Uint64)>>(
        'quiche_config_set_initial_max_streams_uni');
void quiche_config_set_initial_max_streams_uni(
        Pointer<quiche_config> config, int v) =>
    quiche_config_set_initial_max_streams_uniPtr
        .asFunction<void Function(Pointer<quiche_config>, int)>()(config, v);

final quiche_config_freePtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_config>)>>(
        'quiche_config_free');
void quiche_config_free(Pointer<quiche_config> config) => quiche_config_freePtr
    .asFunction<void Function(Pointer<quiche_config>)>()(config);

final quiche_acceptPtr = _lookup<
    NativeFunction<
        Pointer<quiche_conn> Function(Pointer<Uint8>, IntPtr, Pointer<Uint8>,
            IntPtr, Pointer<quiche_config>)>>('quiche_accept');
Pointer<quiche_conn> quiche_accept(
    List<int> scid, List<int> odcid, Pointer<quiche_config> config) {
  final scidPtr = calloc<Uint8>(scid.length);
  final odcidPtr = calloc<Uint8>(odcid.length);
  try {
    for (var i = 0; i < scid.length; i++) {
      scidPtr[i] = scid[i];
    }
    for (var i = 0; i < odcid.length; i++) {
      odcidPtr[i] = odcid[i];
    }
    return quiche_acceptPtr.asFunction<
            Pointer<quiche_conn> Function(Pointer<Uint8>, int, Pointer<Uint8>,
                int, Pointer<quiche_config>)>()(
        scidPtr, scid.length, odcidPtr, odcid.length, config);
  } finally {
    calloc.free(scidPtr);
    calloc.free(odcidPtr);
  }
}

final quiche_connectPtr = _lookup<
    NativeFunction<
        Pointer<quiche_conn> Function(Pointer<Utf8>, Pointer<Uint8>, IntPtr,
            Pointer<Uint8>, IntPtr, Pointer<quiche_config>)>>('quiche_connect');
Pointer<quiche_conn> quiche_connect(String serverName, List<int> scid,
    List<int> peerAddr, Pointer<quiche_config> config) {
  final namePtr = serverName.toNativeUtf8();
  final scidPtr = calloc<Uint8>(scid.length);
  final peerAddrPtr = calloc<Uint8>(peerAddr.length);
  try {
    for (var i = 0; i < scid.length; i++) {
      scidPtr[i] = scid[i];
    }
    for (var i = 0; i < peerAddr.length; i++) {
      peerAddrPtr[i] = peerAddr[i];
    }
    return quiche_connectPtr.asFunction<
            Pointer<quiche_conn> Function(Pointer<Utf8>, Pointer<Uint8>, int,
                Pointer<Uint8>, int, Pointer<quiche_config>)>()(
        namePtr, scidPtr, scid.length, peerAddrPtr, peerAddr.length, config);
  } finally {
    calloc.free(namePtr);
    calloc.free(scidPtr);
    calloc.free(peerAddrPtr);
  }
}

final quiche_conn_recvPtr = _lookup<
    NativeFunction<
        IntPtr Function(
            Pointer<quiche_conn>,
            Pointer<Uint8>,
            IntPtr,
            Pointer<
                NativeFunction<
                    Void Function(Pointer<Uint8>, IntPtr, Pointer<Void>)>>,
            Pointer<Void>)>>('quiche_conn_recv');
int quiche_conn_recv(Pointer<quiche_conn> conn, List<int> buf,
    {void Function(List<int> from)? onPeerAddr}) {
  final bufPtr = calloc<Uint8>(buf.length);
  try {
    for (var i = 0; i < buf.length; i++) {
      bufPtr[i] = buf[i];
    }
    return quiche_conn_recvPtr.asFunction<
        int Function(
            Pointer<quiche_conn>,
            Pointer<Uint8>,
            int,
            Pointer<
                NativeFunction<
                    Void Function(Pointer<Uint8>, IntPtr, Pointer<Void>)>>,
            Pointer<Void>)>()(conn, bufPtr, buf.length, nullptr, nullptr);
  } finally {
    calloc.free(bufPtr);
  }
}

final quiche_conn_sendPtr = _lookup<
    NativeFunction<
        IntPtr Function(
            Pointer<quiche_conn>,
            Pointer<Uint8>,
            IntPtr,
            Pointer<
                NativeFunction<
                    Void Function(Pointer<Uint8>, IntPtr, Pointer<Void>)>>,
            Pointer<Void>)>>('quiche_conn_send');
(int, List<int>) quiche_conn_send(Pointer<quiche_conn> conn, int maxLen) {
  final bufPtr = calloc<Uint8>(maxLen);
  try {
    final written = quiche_conn_sendPtr.asFunction<
        int Function(
            Pointer<quiche_conn>,
            Pointer<Uint8>,
            int,
            Pointer<
                NativeFunction<
                    Void Function(Pointer<Uint8>, IntPtr, Pointer<Void>)>>,
            Pointer<Void>)>()(conn, bufPtr, maxLen, nullptr, nullptr);
    if (written < 0) {
      return (written, <int>[]);
    }
    final out = <int>[];
    for (var i = 0; i < written; i++) {
      out.add(bufPtr[i]);
    }
    return (written, out);
  } finally {
    calloc.free(bufPtr);
  }
}

final quiche_conn_stream_recvPtr = _lookup<
    NativeFunction<
        IntPtr Function(Pointer<quiche_conn>, Int64, Pointer<Uint8>, IntPtr,
            Pointer<Uint8>, Pointer<Uint64>)>>('quiche_conn_stream_recv');
(int, List<int>, bool) quiche_conn_stream_recv(
    Pointer<quiche_conn> conn, int streamId, int maxLen) {
  final bufPtr = calloc<Uint8>(maxLen);
  final finPtr = calloc<Uint8>(1);
  try {
    final read = quiche_conn_stream_recvPtr.asFunction<
            int Function(Pointer<quiche_conn>, int, Pointer<Uint8>, int,
                Pointer<Uint8>, Pointer<Uint64>)>()(
        conn, streamId, bufPtr, maxLen, finPtr, nullptr);
    if (read < 0) {
      return (read, <int>[], false);
    }
    final out = <int>[];
    for (var i = 0; i < read; i++) {
      out.add(bufPtr[i]);
    }
    return (read, out, finPtr.value == 1);
  } finally {
    calloc.free(bufPtr);
    calloc.free(finPtr);
  }
}

final quiche_conn_stream_sendPtr = _lookup<
    NativeFunction<
        IntPtr Function(Pointer<quiche_conn>, Int64, Pointer<Uint8>, IntPtr,
            Bool)>>('quiche_conn_stream_send');
int quiche_conn_stream_send(
    Pointer<quiche_conn> conn, int streamId, List<int> data, bool fin) {
  final dataPtr = calloc<Uint8>(data.length);
  try {
    for (var i = 0; i < data.length; i++) {
      dataPtr[i] = data[i];
    }
    return quiche_conn_stream_sendPtr.asFunction<
        int Function(Pointer<quiche_conn>, int, Pointer<Uint8>, int,
            bool)>()(conn, streamId, dataPtr, data.length, fin);
  } finally {
    calloc.free(dataPtr);
  }
}

final quiche_conn_stream_shutdownPtr =
    _lookup<NativeFunction<Int32 Function(Pointer<quiche_conn>, Int64, Int32)>>(
        'quiche_conn_stream_shutdown');
int quiche_conn_stream_shutdown(
        Pointer<quiche_conn> conn, int streamId, int direction) =>
    quiche_conn_stream_shutdownPtr
            .asFunction<int Function(Pointer<quiche_conn>, int, int)>()(
        conn, streamId, direction);

final quiche_conn_closePtr = _lookup<
    NativeFunction<
        Void Function(Pointer<quiche_conn>, Bool, Int64,
            Pointer<Utf8>)>>('quiche_conn_close');
void quiche_conn_close(
    Pointer<quiche_conn> conn, bool app, int error, String reason) {
  final reasonPtr = reason.toNativeUtf8();
  try {
    quiche_conn_closePtr.asFunction<
            void Function(Pointer<quiche_conn>, bool, int, Pointer<Utf8>)>()(
        conn, app, error, reasonPtr);
  } finally {
    calloc.free(reasonPtr);
  }
}

final quiche_conn_freePtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_conn>)>>(
        'quiche_conn_free');
void quiche_conn_free(Pointer<quiche_conn> conn) =>
    quiche_conn_freePtr.asFunction<void Function(Pointer<quiche_conn>)>()(conn);

final quiche_conn_is_establishedPtr =
    _lookup<NativeFunction<Bool Function(Pointer<quiche_conn>)>>(
        'quiche_conn_is_established');
bool quiche_conn_is_established(Pointer<quiche_conn> conn) =>
    quiche_conn_is_establishedPtr
        .asFunction<bool Function(Pointer<quiche_conn>)>()(conn);

final quiche_conn_is_closedPtr =
    _lookup<NativeFunction<Bool Function(Pointer<quiche_conn>)>>(
        'quiche_conn_is_closed');
bool quiche_conn_is_closed(Pointer<quiche_conn> conn) =>
    quiche_conn_is_closedPtr
        .asFunction<bool Function(Pointer<quiche_conn>)>()(conn);

final quiche_conn_stream_init_nextPtr =
    _lookup<NativeFunction<Int64 Function(Pointer<quiche_conn>)>>(
        'quiche_conn_stream_init_next');
int quiche_conn_stream_init_next(Pointer<quiche_conn> conn) =>
    quiche_conn_stream_init_nextPtr
        .asFunction<int Function(Pointer<quiche_conn>)>()(conn);

final quiche_conn_readablePtr = _lookup<
    NativeFunction<
        Pointer<quiche_stream_iter> Function(
            Pointer<quiche_conn>)>>('quiche_conn_readable');
Pointer<quiche_stream_iter> quiche_conn_readable(Pointer<quiche_conn> conn) =>
    quiche_conn_readablePtr.asFunction<
        Pointer<quiche_stream_iter> Function(Pointer<quiche_conn>)>()(conn);

final quiche_conn_writablePtr = _lookup<
    NativeFunction<
        Pointer<quiche_stream_iter> Function(
            Pointer<quiche_conn>)>>('quiche_conn_writable');
Pointer<quiche_stream_iter> quiche_conn_writable(Pointer<quiche_conn> conn) =>
    quiche_conn_writablePtr.asFunction<
        Pointer<quiche_stream_iter> Function(Pointer<quiche_conn>)>()(conn);

final quiche_stream_iter_nextPtr = _lookup<
    NativeFunction<
        Bool Function(Pointer<quiche_stream_iter>,
            Pointer<Int64>)>>('quiche_stream_iter_next');
bool quiche_stream_iter_next(
        Pointer<quiche_stream_iter> iter, Pointer<Int64> streamId) =>
    quiche_stream_iter_nextPtr.asFunction<
        bool Function(
            Pointer<quiche_stream_iter>, Pointer<Int64>)>()(iter, streamId);

final quiche_stream_iter_freePtr =
    _lookup<NativeFunction<Void Function(Pointer<quiche_stream_iter>)>>(
        'quiche_stream_iter_free');
void quiche_stream_iter_free(Pointer<quiche_stream_iter> iter) =>
    quiche_stream_iter_freePtr
        .asFunction<void Function(Pointer<quiche_stream_iter>)>()(iter);

Pointer<T> _lookup<T extends NativeFunction>(String name) =>
    quicheLibrary.lookup<T>(name);
