/// Base class for API responses with success status.
///
/// All response types extend this to provide consistent structure.
abstract class BaseResponse {
  /// Whether the operation succeeded.
  final bool success;

  /// Human-readable result message.
  final String message;

  /// Creates a response with [success] status and [message].
  const BaseResponse({required this.success, required this.message});

  /// Converts to JSON representation.
  Map<String, dynamic> toJson();

  @override
  String toString() => '${runtimeType}(success: $success, message: $message)';
}
