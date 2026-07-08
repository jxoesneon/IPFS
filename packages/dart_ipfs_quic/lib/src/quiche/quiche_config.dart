import 'dart:ffi';

import '../generated/quiche_bindings.dart' as q;

/// Configuration for a quiche endpoint.
///
/// Wraps `quiche_config` and applies sensible defaults for a libp2p QUIC
/// transport. This is a minimal implementation; production deployments may
/// want to expose more parameters.
class QuicheConfig {
  Pointer<q.quiche_config>? _config;

  /// Creates a new quiche configuration for QUIC version 1.
  QuicheConfig() {
    _config = q.quiche_config_new(q.QUICHE_PROTOCOL_VERSION);
    if (_config == null || _config!.address == 0) {
      throw StateError('quiche_config_new failed');
    }
  }

  /// Applies transport parameters suitable for a libp2p node.
  void applyDefaults() {
    _assertValid();
    q.quiche_config_set_max_idle_timeout(_config!, 30 * 1000);
    q.quiche_config_set_max_recv_udp_payload_size(_config!, 1350);
    q.quiche_config_set_max_send_udp_payload_size(_config!, 1350);
    q.quiche_config_set_initial_max_data(_config!, 10 * 1024 * 1024);
    q.quiche_config_set_initial_max_stream_data_bidi_local(
        _config!, 1024 * 1024);
    q.quiche_config_set_initial_max_stream_data_bidi_remote(
        _config!, 1024 * 1024);
    q.quiche_config_set_initial_max_streams_bidi(_config!, 100);
    q.quiche_config_set_initial_max_streams_uni(_config!, 100);
  }

  /// Loads the TLS certificate chain from a PEM file.
  void loadCertChain(String path) {
    _assertValid();
    final result =
        q.quiche_config_load_cert_chain_from_pem_file(_config!, path);
    if (result < 0) {
      throw StateError(
          'quiche_config_load_cert_chain_from_pem_file failed: $result');
    }
  }

  /// Loads the TLS private key from a PEM file.
  void loadPrivKey(String path) {
    _assertValid();
    final result = q.quiche_config_load_priv_key_from_pem_file(_config!, path);
    if (result < 0) {
      throw StateError(
          'quiche_config_load_priv_key_from_pem_file failed: $result');
    }
  }

  /// Sets the ALPN list. For libp2p QUIC this should be the libp2p protocol id.
  void setApplicationProtos(List<int> protos) {
    _assertValid();
    final result = q.quiche_config_set_application_protos(_config!, protos);
    if (result < 0) {
      throw StateError('quiche_config_set_application_protos failed: $result');
    }
  }

  /// Disables peer certificate verification. Useful for tests; production
  /// libp2p nodes should use proper TLS 1.3 certificates with embedded
  /// peer public keys.
  void setVerifyPeer(bool verify) {
    _assertValid();
    q.quiche_config_verify_peer(_config!, verify);
  }

  Pointer<q.quiche_config> get pointer {
    _assertValid();
    return _config!;
  }

  void _assertValid() {
    if (_config == null || _config!.address == 0) {
      throw StateError('QuicheConfig has been disposed');
    }
  }

  /// Releases the native configuration object.
  void dispose() {
    if (_config != null && _config!.address != 0) {
      q.quiche_config_free(_config!);
      _config = null;
    }
  }
}
