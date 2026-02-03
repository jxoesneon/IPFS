// src/utils/password_prompt.dart
import 'dart:io';

/// Utility for securely prompting passwords from the terminal.
///
/// **Security Note:** Uses stdin echo disabling to prevent password
/// visibility in terminal history.
class PasswordPrompt {
  /// Prompts the user for a password without echoing to the terminal.
  ///
  /// Returns null if running in a non-interactive environment.
  static String? prompt([String message = 'Enter keystore password: ']) {
    if (!stdin.hasTerminal) {
      return null;
    }

    stdout.write(message);
    stdin.echoMode = false;
    try {
      final password = stdin.readLineSync();
      stdout.writeln(); // New line after hidden input
      return password;
    } finally {
      stdin.echoMode = true;
    }
  }

  /// Prompts for a new password with confirmation.
  ///
  /// Returns the password if both entries match, null otherwise.
  static String? promptNew([String message = 'Create keystore password: ']) {
    if (!stdin.hasTerminal) {
      return null;
    }

    final password = prompt(message);
    if (password == null || password.isEmpty) {
      stderr.writeln('Error: Password cannot be empty');
      return null;
    }

    final confirm = prompt('Confirm password: ');
    if (password != confirm) {
      stderr.writeln('Error: Passwords do not match');
      return null;
    }

    return password;
  }

  /// Checks password strength (basic check).
  ///
  /// Returns true if password meets minimum requirements.
  static bool isStrongEnough(String password) {
    // Minimum 8 characters
    if (password.length < 8) {
      stderr.writeln('Error: Password must be at least 8 characters');
      return false;
    }
    return true;
  }
}

