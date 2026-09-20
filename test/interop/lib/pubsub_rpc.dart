// Shared Kubo-style pubsub RPC surface for the interop clients.
//
// dart_ipfs, Kubo, and the Helia shim all expose the same four endpoints:
//   POST /api/v0/pubsub/sub?arg=<topic>   — subscribe; streams NDJSON
//   POST /api/v0/pubsub/pub?arg=<topic>   — publish; body is the payload
//   POST /api/v0/pubsub/ls                — list subscribed topics
//   POST /api/v0/pubsub/peers?arg=<topic> — list peers on a topic
//
// NDJSON message objects use the Kubo wire shape: {"from","data","seqno",
// "topicIDs"} with binary fields multibase-base64url (`u`-prefixed).
//
// Kubo quirks handled via flags: its arg values must be multibase-encoded
// and its pub endpoint expects a multipart file upload.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A decoded pubsub message from a `pubsub/sub` stream.
class PubsubRpcMessage {
  PubsubRpcMessage({
    required this.from,
    required this.data,
    required this.topics,
  });

  /// The sender's peer ID string.
  final String from;

  /// The decoded message payload bytes.
  final Uint8List data;

  /// The decoded topic strings the message was published on.
  final List<String> topics;

  /// The payload decoded as UTF-8 text.
  String get text => utf8.decode(data, allowMalformed: true);
}

/// Multibase base64url (`u`-prefix) encode — Kubo's `arg` wire format.
/// The `u` multibase code is unpadded, so '=' padding must be stripped.
String encodeMultibaseBase64Url(List<int> bytes) =>
    'u${base64Url.encode(bytes).replaceAll('=', '')}';

/// Decodes a multibase base64url (`u`-prefixed) value; returns the raw
/// bytes for empty payloads.
Uint8List decodeMultibaseBase64Url(String value) {
  if (value.isEmpty) return Uint8List(0);
  final body = value.startsWith('u') ? value.substring(1) : value;
  if (body.isEmpty) return Uint8List(0);
  return base64Url.decode(base64Url.normalize(body));
}

/// Buffers NDJSON messages arriving on one streaming `pubsub/sub` request.
class PubsubStreamBuffer {
  final List<PubsubRpcMessage> _messages = [];
  final Completer<void> _ready = Completer<void>();

  List<PubsubRpcMessage> get messages => List.unmodifiable(_messages);

  /// Completes once the subscription stream has produced its first byte
  /// (i.e. the server accepted the subscription).
  Future<void> get ready => _ready.future;

  void _add(PubsubRpcMessage message) {
    _messages.add(message);
    if (!_ready.isCompleted) _ready.complete();
  }
}

/// Kubo-style pubsub RPC methods shared by the interop clients.
mixin PubsubRpc {
  String get host;
  int get port;

  /// Whether `arg` values must be multibase base64url encoded (Kubo).
  bool get pubsubMultibaseArgs => false;

  /// Whether `pubsub/pub` sends the payload as a multipart file (Kubo)
  /// rather than a raw request body (dart_ipfs, Helia shim).
  bool get pubsubMultipartPublish => false;

  final Map<String, PubsubStreamBuffer> _pubsubBuffers = {};
  final Map<String, HttpClient> _pubsubClients = {};

  String _encodeTopicArg(String topic) => pubsubMultibaseArgs
      ? encodeMultibaseBase64Url(utf8.encode(topic))
      : topic;

  /// Opens `POST /api/v0/pubsub/sub?arg=<topic>` and buffers every NDJSON
  /// message in the background until [pubsubUnsubscribe] or process exit.
  /// Idempotent per topic.
  Future<void> pubsubSubscribe(String topic) async {
    if (_pubsubBuffers.containsKey(topic)) return;
    final buffer = PubsubStreamBuffer();
    _pubsubBuffers[topic] = buffer;

    final uri = Uri.http('$host:$port', '/api/v0/pubsub/sub', {
      'arg': _encodeTopicArg(topic),
    });
    final client = HttpClient();
    _pubsubClients[topic] = client;

    unawaited(() async {
      try {
        final request = await client.postUrl(uri);
        final response = await request.close();
        if (response.statusCode != 200) {
          final body = await response.transform(utf8.decoder).join();
          throw HttpException(
            'pubsub/sub returned ${response.statusCode}: $body',
          );
        }
        if (!buffer._ready.isCompleted) buffer._ready.complete();
        await for (final line
            in response
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final json = jsonDecode(trimmed) as Map<String, dynamic>;
            buffer._add(
              PubsubRpcMessage(
                from: json['from'] as String? ?? '',
                data: decodeMultibaseBase64Url(json['data'] as String? ?? ''),
                topics: [
                  for (final t in json['topicIDs'] as List? ?? const [])
                    utf8.decode(
                      decodeMultibaseBase64Url(t as String),
                      allowMalformed: true,
                    ),
                ],
              ),
            );
          } catch (_) {
            // Tolerate malformed lines on the stream.
          }
        }
      } catch (_) {
        if (!buffer._ready.isCompleted) buffer._ready.complete();
      }
    }());
    // Give the request a moment to establish before returning.
    await buffer.ready.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// Closes the streaming subscription for [topic].
  Future<void> pubsubUnsubscribe(String topic) async {
    _pubsubClients.remove(topic)?.close(force: true);
    _pubsubBuffers.remove(topic);
  }

  /// Messages buffered so far for [topic] (decoded).
  List<PubsubRpcMessage> pubsubMessages(String topic) =>
      _pubsubBuffers[topic]?.messages ?? const [];

  /// Waits for a message on [topic] whose payload equals [expected] (or any
  /// message when null) until [timeout]. Returns the matched message.
  Future<PubsubRpcMessage> pubsubWaitFor(
    String topic, {
    String? expected,
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(milliseconds: 250),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final message
          in _pubsubBuffers[topic]?.messages ?? const <PubsubRpcMessage>[]) {
        if (expected == null || message.text == expected) return message;
      }
      await Future<void>.delayed(pollInterval);
    }
    final seen = (_pubsubBuffers[topic]?.messages ?? const <PubsubRpcMessage>[])
        .map((m) => m.text)
        .toList();
    throw TimeoutException(
      'Timed out waiting for pubsub message on $topic '
      '(expected: $expected, seen: $seen)',
    );
  }

  /// Publishes [data] to [topic] via `POST /api/v0/pubsub/pub`.
  Future<void> pubsubPublish(String topic, List<int> data) async {
    final uri = Uri.http('$host:$port', '/api/v0/pubsub/pub', {
      'arg': _encodeTopicArg(topic),
    });
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      if (pubsubMultipartPublish) {
        final boundary =
            '----PubsubPub${DateTime.now().millisecondsSinceEpoch}';
        request.headers.contentType = ContentType(
          'multipart',
          'form-data',
          parameters: {'boundary': boundary},
        );
        final body = BytesBuilder()
          ..add(utf8.encode('--$boundary\r\n'))
          ..add(
            utf8.encode(
              'Content-Disposition: form-data; name="file"; '
              'filename="data"\r\n\r\n',
            ),
          )
          ..add(data)
          ..add(utf8.encode('\r\n--$boundary--\r\n'));
        request.add(body.toBytes());
      } else {
        request.add(data);
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'pubsub/pub returned ${response.statusCode}: $body',
        );
      }
    } finally {
      client.close();
    }
  }

  /// Lists subscribed topics via `POST /api/v0/pubsub/ls`.
  Future<List<String>> pubsubLs() async {
    final uri = Uri.http('$host:$port', '/api/v0/pubsub/ls');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('pubsub/ls returned ${response.statusCode}: $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return [for (final s in json['Strings'] as List? ?? const []) '$s'];
    } finally {
      client.close();
    }
  }

  /// Lists peers subscribed to [topic] via `POST /api/v0/pubsub/peers`.
  Future<List<String>> pubsubPeers(String topic) async {
    final uri = Uri.http('$host:$port', '/api/v0/pubsub/peers', {
      'arg': _encodeTopicArg(topic),
    });
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'pubsub/peers returned ${response.statusCode}: $body',
        );
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return [for (final s in json['Strings'] as List? ?? const []) '$s'];
    } finally {
      client.close();
    }
  }

  /// Closes all open pubsub subscription streams.
  Future<void> pubsubClose() async {
    for (final client in _pubsubClients.values) {
      client.close(force: true);
    }
    _pubsubClients.clear();
    _pubsubBuffers.clear();
  }
}
