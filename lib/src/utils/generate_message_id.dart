// lib/src/utils/message_id.dart

import 'package:uuid/uuid.dart'; // Import the uuid package

/// Generates a unique message ID.
String generateMessageId() {
  var uuid = const Uuid();
  return uuid.v4(); // Generate a UUID v4
}

