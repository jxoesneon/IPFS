abstract class BaseResponse {
  final bool success;
  final String message;

  const BaseResponse({
    required this.success,
    required this.message,
  });

  Map<String, dynamic> toJson();

  @override
  String toString() => '${runtimeType}(success: $success, message: $message)';
}
