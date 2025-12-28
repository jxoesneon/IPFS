// Platform-specific libsodium setup and auto-installation
import 'dart:io';

/// Helper for ensuring libsodium is available before P2P initialization.
///
/// This class proactively checks for libsodium and attempts automatic
/// installation on Windows to prevent FFI hang during package import.
class LibsodiumSetup {
  /// Checks if libsodium is available and attempts installation if needed.
  ///
  /// Returns true if libsodium is available or was successfully installed.
  /// Returns false if libsodium is missing and installation failed/was skipped.
  ///
  /// Set [autoInstall] to false to skip automatic installation attempts.
  /// Set [verbose] to false to suppress console output.
  static Future<bool> ensureAvailable({
    bool autoInstall = true,
    bool verbose = true,
  }) async {
    if (!Platform.isWindows) {
      // macOS and Linux handle libsodium differently
      return await _checkNonWindows(verbose);
    }

    // Windows-specific check
    if (await _isInstalled()) {
      if (verbose) {
        stdout.writeln('✅ libsodium.dll found');
      }
      return true;
    }

    if (verbose) {
      stdout.writeln('⚠️  libsodium not found (required for P2P networking)');
    }

    if (!autoInstall) {
      if (verbose) {
        _printInstallInstructions();
      }
      return false;
    }

    if (verbose) {
      stdout.writeln('Attempting automatic installation...');
    }

    return await _attemptInstall(verbose);
  }

  /// Checks if libsodium.dll is in the system PATH on Windows.
  static Future<bool> _isInstalled() async {
    try {
      final result = await Process.run('where', [
        'libsodium.dll',
      ], runInShell: true);
      return result.exitCode == 0 && result.stdout.toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Attempts to install libsodium via winget.
  static Future<bool> _attemptInstall(bool verbose) async {
    // Check if winget is available
    if (!await _hasWinget()) {
      if (verbose) {
        stdout.writeln('❌ winget not found (Windows Package Manager required)');
        _printInstallInstructions();
      }
      return false;
    }

    if (verbose) {
      stdout.writeln('Installing libsodium via winget...');
    }

    try {
      final result = await Process.run('winget', [
        'install',
        '--id',
        'jedisct1.libsodium',
        '--accept-source-agreements',
        '--accept-package-agreements',
        '--silent',
      ], runInShell: true);

      if (result.exitCode == 0) {
        if (verbose) {
          stdout.writeln('✅ libsodium installed successfully!');
          stdout.writeln('   Note: You may need to restart your terminal/IDE.');
        }
        return true;
      } else {
        if (verbose) {
          stdout.writeln('❌ Installation failed (exit code: ${result.exitCode})');
          if (result.stderr.toString().isNotEmpty) {
            stdout.writeln('   Error: ${result.stderr}');
          }
        }
      }
    } catch (e) {
      if (verbose) {
        stdout.writeln('❌ Installation failed: $e');
      }
    }

    if (verbose) {
      _printInstallInstructions();
    }
    return false;
  }

  /// Checks if winget (Windows Package Manager) is available.
  static Future<bool> _hasWinget() async {
    try {
      final result = await Process.run('winget', [
        '--version',
      ], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Prints manual installation instructions.
  static void _printInstallInstructions() {
    stdout.writeln('''

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Manual Installation Options for libsodium
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Via winget (Windows Package Manager):
   winget install jedisct1.libsodium

2. Via vcpkg:
   vcpkg install libsodium

3. Manual download:
   https://libsodium.org
   → Download DLL → Add to PATH

4. Via iTunes (includes Bonjour):
   choco install itunes

Alternative: Use offline mode (no P2P required)
   IPFSConfig(offline: true)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''');
  }

  /// Checks for libsodium on non-Windows platforms.
  static Future<bool> _checkNonWindows(bool verbose) async {
    if (Platform.isMacOS) {
      // macOS usually has libsodium via Homebrew or system
      // Let it fail gracefully if missing
      return true;
    }

    if (Platform.isLinux) {
      // Check for libsodium.so via ldconfig
      try {
        final result = await Process.run('ldconfig', ['-p']);
        final hasLib = result.stdout.toString().contains('libsodium');

        if (!hasLib && verbose) {
          stdout.writeln('⚠️  libsodium not found');
          stdout.writeln('Install via: sudo apt-get install libsodium-dev');
        }

        return hasLib;
      } catch (e) {
        // ldconfig not available, assume library might be present
        return true;
      }
    }

    return true; // Unknown platform, let it try
  }
}
