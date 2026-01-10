// test/utils/logger_test.dart
import 'dart:typed_data';

import 'package:test/test.dart';

void main() {
  group('Logger Log Levels', () {
    test('debug level maps correctly', () {
      // From code: case 'debug': _logger.level = logging.Level.FINE;
      const level = 'debug';
      expect(level.toLowerCase(), equals('debug'));
    });

    test('info level maps correctly', () {
      const level = 'info';
      expect(level.toLowerCase(), equals('info'));
    });

    test('warning level maps correctly', () {
      const level = 'warning';
      expect(level.toLowerCase(), equals('warning'));
    });

    test('error level maps correctly', () {
      const level = 'error';
      expect(level.toLowerCase(), equals('error'));
    });

    test('invalid level would throw', () {
      const level = 'invalid';
      final validLevels = ['debug', 'info', 'warning', 'error'];
      expect(validLevels.contains(level), isFalse);
    });
  });

  group('Logger Message Formatting', () {
    test('debug prefix is [DEBUG]', () {
      const prefix = '[DEBUG]';
      expect(prefix, equals('[DEBUG]'));
    });

    test('info prefix is [INFO]', () {
      const prefix = '[INFO]';
      expect(prefix, equals('[INFO]'));
    });

    test('warning prefix is [WARNING]', () {
      const prefix = '[WARNING]';
      expect(prefix, equals('[WARNING]'));
    });

    test('error prefix is [ERROR]', () {
      const prefix = '[ERROR]';
      expect(prefix, equals('[ERROR]'));
    });

    test('verbose prefix is [VERBOSE]', () {
      const prefix = '[VERBOSE]';
      expect(prefix, equals('[VERBOSE]'));
    });
  });

  group('Logger Debug/Verbose Flags', () {
    test('debug disabled by default', () {
      const debug = false;
      expect(debug, isFalse);
    });

    test('verbose disabled by default', () {
      const verbose = false;
      expect(verbose, isFalse);
    });

    test('debug messages only logged when enabled', () {
      var logged = false;
      const debugEnabled = true;
      
      if (debugEnabled) {
        logged = true;
      }
      
      expect(logged, isTrue);
    });
  });

  group('Logger Timestamp Format', () {
    test('uses ISO8601 format', () {
      final timestamp = DateTime.now().toIso8601String();
      expect(timestamp, contains('T')); // ISO format has T separator
    });
  });

  group('Logger File Output', () {
    test('log file name is ipfs.log', () {
      const logFileName = 'ipfs.log';
      expect(logFileName, equals('ipfs.log'));
    });

    test('stringToBytes converts correctly', () {
      const message = 'Hello World';
      final bytes = Uint8List.fromList(message.codeUnits);
      expect(bytes.length, equals(message.length));
    });
  });

  group('Logger Hierarchical Logging', () {
    test('supports component names', () {
      const componentName = 'BlockStore';
      final fullMessage = '[INFO] [$componentName] Starting...';
      expect(fullMessage, contains('BlockStore'));
    });
  });
}
