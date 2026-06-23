// src/utils/password_prompt.dart
import 'dart:async';
import 'package:dart_ipfs/src/platform/platform.dart';

/// Utility for securely prompting passwords from the terminal.
///
/// **Security Note:** Uses stdin echo disabling to prevent password
/// visibility in terminal history.
class PasswordPrompt {
  /// Prompts the user for a password without echoing to the terminal.
  ///
  /// Returns null if running in a non-interactive environment.
  static Future<String?> prompt([
    String message = 'Enter keystore password: ',
  ]) async {
    return await getPlatform().promptPassword(message);
  }

  /// Prompts for a new password with confirmation.
  ///
  /// Returns the password if both entries match, null otherwise.
  static Future<String?> promptNew([
    String message = 'Create keystore password: ',
  ]) async {
    final password = await prompt(message);
    if (password == null || password.isEmpty) {
      return null;
    }

    final confirm = await prompt('Confirm password: ');
    if (password != confirm) {
      return null;
    }

    return password;
  }

  /// Checks password strength.
  ///
  /// Requires at least 12 characters, one uppercase, one lowercase,
  /// one digit, one special character, and no common patterns.
  static bool isStrongEnough(String password) {
    if (password.length < 12) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\'",.<>?/\\|`~]'))) {
      return false;
    }

    const commonPatterns = ['password', '123456', 'qwerty', 'admin', 'letmein'];
    if (commonPatterns.any((p) => password.toLowerCase().contains(p))) {
      return false;
    }

    return true;
  }
}
