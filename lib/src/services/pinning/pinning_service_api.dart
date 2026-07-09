// lib/src/services/pinning/pinning_service_api.dart
//
// IPFS Pinning Service API v1 client.
//
// Implements the vendor-agnostic IPFS Pinning Service API specification
// (https://ipfs.github.io/pinning-services-api-spec/) for communicating
// with remote pinning services.
//
// Endpoints implemented:
//   POST   /pins          — Add a pin
//   GET    /pins          — List pins (with filters)
//   GET    /pins/{id}     — Get pin status by request ID
//   DELETE /pins/{id}     — Remove a pin
//   POST   /pins/{id}?mode=replace — Replace a pin
//
// Pin status lifecycle: queued → pinning → pinned → failed

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/logger.dart';

/// Status of a pin in the pinning service.
enum PinStatus {
  /// The pin request has been accepted but not yet started.
  queued,

  /// The pinning service is actively pinning the content.
  pinning,

  /// The content has been successfully pinned.
  pinned,

  /// The pinning operation failed.
  failed,

  /// The pin is being removed.
  pinningOff,

  /// The pin has been removed.
  unpinned,

  /// Unknown status.
  unknown;

  /// Parses a status string from the API into a [PinStatus].
  static PinStatus fromString(String? status) {
    switch (status) {
      case 'queued':
        return PinStatus.queued;
      case 'pinning':
        return PinStatus.pinning;
      case 'pinned':
        return PinStatus.pinned;
      case 'failed':
        return PinStatus.failed;
      case 'pinning_off':
        return PinStatus.pinningOff;
      case 'unpinned':
        return PinStatus.unpinned;
      default:
        return PinStatus.unknown;
    }
  }

  /// Converts this status to the API string representation.
  String toApiString() {
    switch (this) {
      case PinStatus.queued:
        return 'queued';
      case PinStatus.pinning:
        return 'pinning';
      case PinStatus.pinned:
        return 'pinned';
      case PinStatus.failed:
        return 'failed';
      case PinStatus.pinningOff:
        return 'pinning_off';
      case PinStatus.unpinned:
        return 'unpinned';
      case PinStatus.unknown:
        return 'unknown';
    }
  }
}

/// A pin request object as defined by the Pinning Service API spec.
class PinRequest {
  /// Creates a [PinRequest].
  PinRequest({
    required this.cid,
    this.name,
    this.origins = const [],
    this.meta = const {},
  });

  /// The CID of the content to pin.
  final String cid;

  /// Optional human-readable name for the pin.
  final String? name;

  /// Optional list of multiaddrs for the pinning service to fetch content from.
  final List<String> origins;

  /// Optional vendor-specific metadata.
  final Map<String, dynamic> meta;

  /// Converts this request to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'cid': cid};
    if (name != null) json['name'] = name;
    if (origins.isNotEmpty) json['origins'] = origins;
    if (meta.isNotEmpty) json['meta'] = meta;
    return json;
  }
}

/// A pin status response from the pinning service.
class PinStatusResponse {
  /// Creates a [PinStatusResponse].
  PinStatusResponse({
    required this.requestId,
    required this.status,
    required this.created,
    required this.pin,
    this.delegates = const [],
    this.info = const {},
  });

  /// Parses a JSON response from the API into a [PinStatusResponse].
  factory PinStatusResponse.fromJson(Map<String, dynamic> json) {
    final pinRaw = json['pin'] as Map<String, dynamic>? ?? {};
    return PinStatusResponse(
      requestId: json['requestid'] as String? ?? '',
      status: PinStatus.fromString(json['status'] as String?),
      created: json['created'] as String? ?? '',
      pin: PinObject.fromJson(pinRaw),
      delegates:
          (json['delegates'] as List?)?.map((e) => e as String).toList() ?? [],
      info: (json['info'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// The unique request ID assigned by the pinning service.
  final String requestId;

  /// Current status of the pin.
  final PinStatus status;

  /// ISO 8601 timestamp of when the pin was created.
  final String created;

  /// The pin object.
  final PinObject pin;

  /// Multiaddrs of peers delegated by the pinning service.
  final List<String> delegates;

  /// Additional vendor-specific information.
  final Map<String, dynamic> info;

  /// Converts this response to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'requestid': requestId,
    'status': status.toApiString(),
    'created': created,
    'pin': pin.toJson(),
    'delegates': delegates,
    'info': info,
  };
}

/// A pin object as defined by the Pinning Service API spec.
class PinObject {
  /// Creates a [PinObject].
  PinObject({
    required this.cid,
    this.name,
    this.origins = const [],
    this.meta = const {},
  });

  /// Parses a JSON map into a [PinObject].
  factory PinObject.fromJson(Map<String, dynamic> json) {
    return PinObject(
      cid: json['cid'] as String? ?? '',
      name: json['name'] as String?,
      origins:
          (json['origins'] as List?)?.map((e) => e as String).toList() ?? [],
      meta: (json['meta'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// The CID of the pinned content.
  final String cid;

  /// Optional human-readable name.
  final String? name;

  /// Optional list of origin multiaddrs.
  final List<String> origins;

  /// Optional vendor-specific metadata.
  final Map<String, dynamic> meta;

  /// Converts this pin to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'cid': cid};
    if (name != null) json['name'] = name;
    if (origins.isNotEmpty) json['origins'] = origins;
    if (meta.isNotEmpty) json['meta'] = meta;
    return json;
  }
}

/// Filters for listing pins.
class PinListFilter {
  /// Creates a [PinListFilter].
  const PinListFilter({
    this.cid,
    this.name,
    this.status,
    this.before,
    this.after,
    this.limit,
    this.meta,
  });

  /// Filter by CID.
  final List<String>? cid;

  /// Filter by name (exact match).
  final String? name;

  /// Filter by status.
  final List<PinStatus>? status;

  /// Return results created before this ISO 8601 timestamp.
  final String? before;

  /// Return results created after this ISO 8601 timestamp.
  final String? after;

  /// Maximum number of results to return.
  final int? limit;

  /// Filter by metadata key-value pairs.
  final Map<String, String>? meta;

  /// Converts this filter to query parameters.
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (cid != null && cid!.isNotEmpty) {
      params['cid'] = cid!.join(',');
    }
    if (name != null) params['name'] = name!;
    if (status != null && status!.isNotEmpty) {
      params['status'] = status!.map((s) => s.toApiString()).join(',');
    }
    if (before != null) params['before'] = before!;
    if (after != null) params['after'] = after!;
    if (limit != null) params['limit'] = limit.toString();
    if (meta != null) {
      for (final entry in meta!.entries) {
        params['meta.${entry.key}'] = entry.value;
      }
    }
    return params;
  }
}

/// Response from a list pins request.
class PinListResponse {
  /// Creates a [PinListResponse].
  PinListResponse({required this.results, this.count, this.nextPageToken});

  /// Parses a JSON response from the API.
  factory PinListResponse.fromJson(Map<String, dynamic> json) {
    final resultsRaw = json['results'] as List? ?? [];
    return PinListResponse(
      results: resultsRaw
          .map((e) => PinStatusResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int?,
      nextPageToken: json['next_page_token'] as String?,
    );
  }

  /// The list of pin status results.
  final List<PinStatusResponse> results;

  /// Total count of results (if provided by the service).
  final int? count;

  /// Token for the next page of results (if pagination is supported).
  final String? nextPageToken;
}

/// Error returned by the pinning service API.
class PinningServiceError {
  /// Creates a [PinningServiceError].
  PinningServiceError({required this.message, this.reason, this.details});

  /// Parses a JSON error response.
  factory PinningServiceError.fromJson(Map<String, dynamic> json) {
    return PinningServiceError(
      message: json['message'] as String? ?? 'Unknown error',
      reason: json['reason'] as String?,
      details: json['details'],
    );
  }

  /// Human-readable error message.
  final String message;

  /// Machine-readable error reason.
  final String? reason;

  /// Additional error details.
  final dynamic details;

  @override
  String toString() => 'PinningServiceError: $message';
}

/// Client for the IPFS Pinning Service API v1.
///
/// Communicates with a remote pinning service using the vendor-agnostic
/// IPFS Pinning Service API specification.
class PinningServiceAPIClient {
  /// Creates a [PinningServiceAPIClient].
  ///
  /// [endpoint] is the base URL of the pinning service API.
  /// [token] is the authentication token for the service.
  PinningServiceAPIClient({
    required String endpoint,
    required String token,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  }) : _endpoint = endpoint,
       _token = token,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout,
       _logger = Logger('PinningServiceAPIClient');

  final String _endpoint;
  final String _token;
  final http.Client _httpClient;
  final Duration _timeout;
  final Logger _logger;

  /// Returns the base endpoint URL.
  String get endpoint => _endpoint;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  String _pinsUrl([String? requestId]) {
    final base = '$_endpoint/pins';
    if (requestId != null) return '$base/$requestId';
    return base;
  }

  /// Adds a pin to the remote pinning service.
  ///
  /// Sends a POST /pins request with the [pin] request.
  /// Returns the [PinStatusResponse] from the service.
  Future<PinStatusResponse> addPin(PinRequest pin) async {
    _logger.debug('Adding pin for CID: ${pin.cid}');

    final response = await _httpClient
        .post(
          Uri.parse(_pinsUrl()),
          headers: _headers,
          body: jsonEncode(pin.toJson()),
        )
        .timeout(_timeout);

    return _handlePinResponse(response);
  }

  /// Gets the status of a pin by its [requestId].
  ///
  /// Sends a GET /pins/{requestId} request.
  Future<PinStatusResponse> getPin(String requestId) async {
    _logger.debug('Getting pin status for request: $requestId');

    final response = await _httpClient
        .get(Uri.parse(_pinsUrl(requestId)), headers: _headers)
        .timeout(_timeout);

    return _handlePinResponse(response);
  }

  /// Lists pins with optional [filter].
  ///
  /// Sends a GET /pins request with query parameters.
  Future<PinListResponse> listPins({PinListFilter? filter}) async {
    _logger.debug('Listing pins with filter: $filter');

    final uri = Uri.parse(_pinsUrl());
    final params = filter?.toQueryParams() ?? <String, String>{};
    final url = uri.replace(queryParameters: params.isEmpty ? null : params);

    final response = await _httpClient
        .get(url, headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return PinListResponse.fromJson(decoded);
      }
      throw PinningServiceError(
        message: 'Invalid response format from pinning service',
      );
    }
    throw _parseError(response);
  }

  /// Removes a pin by its [requestId].
  ///
  /// Sends a DELETE /pins/{requestId} request.
  Future<void> removePin(String requestId) async {
    _logger.debug('Removing pin with request ID: $requestId');

    final response = await _httpClient
        .delete(Uri.parse(_pinsUrl(requestId)), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode != 202 && response.statusCode != 200) {
      throw _parseError(response);
    }
  }

  /// Replaces a pin by its [requestId] with a new [pin] request.
  ///
  /// Sends a POST /pins/{requestId}?mode=replace request.
  Future<PinStatusResponse> replacePin(String requestId, PinRequest pin) async {
    _logger.debug('Replacing pin $requestId with CID: ${pin.cid}');

    final uri = Uri.parse(
      _pinsUrl(requestId),
    ).replace(queryParameters: {'mode': 'replace'});

    final response = await _httpClient
        .post(uri, headers: _headers, body: jsonEncode(pin.toJson()))
        .timeout(_timeout);

    return _handlePinResponse(response);
  }

  PinStatusResponse _handlePinResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 202) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return PinStatusResponse.fromJson(decoded);
      }
      throw PinningServiceError(
        message: 'Invalid response format from pinning service',
      );
    }
    throw _parseError(response);
  }

  PinningServiceError _parseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return PinningServiceError.fromJson(decoded);
      }
    } catch (_) {
      // Fall through to generic error.
    }
    return PinningServiceError(
      message: 'Pinning service returned HTTP ${response.statusCode}',
      reason: 'http_error',
    );
  }

  /// Releases HTTP resources.
  void dispose() {
    _httpClient.close();
  }
}
