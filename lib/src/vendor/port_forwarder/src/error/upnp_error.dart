import '../../port_forwarder.dart';

class UPnPError extends GatewayError {
  final String? description;
  final int? statusCode;
  final String response;

  UPnPError({required this.description, required this.statusCode, required this.response});

  @override
  String toString() => "$description (status code: $statusCode)";
}