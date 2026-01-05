// src/utils/logger.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:logging/logging.dart' as logging;

/// A hierarchical logging system for IPFS operations.
///
/// Logger provides structured logging with multiple severity levels,
/// automatic file output, and metrics integration. Each component
/// creates its own named logger instance for easy filtering.
///
/// **Log Levels:**
/// - `debug`: Detailed debugging information (disabled by default)
/// - `verbose`: Extended debugging (disabled by default)
/// - `info`: General operational information
/// - `warning`: Potential issues that don't prevent operation
/// - `error`: Errors with optional exception and stack trace
///
/// Example:
/// ```dart
/// final logger = Logger('BlockStore', debug: true);
/// logger.info('Starting block store...');
/// logger.debug('Processing block: $cid');
/// logger.error('Failed to store block', exception, stackTrace);
/// ```
///
/// Logs are written to both console and `ipfs.log` file (on IO platforms).
class Logger {
  /// Creates a new logger for the specified component
  Logger(String name, {bool debug = false, bool verbose = false})
    : _debug = debug,
      _verbose = verbose,
      _logger = logging.Logger(name) {
    _initializeIfNeeded();
  }
  final logging.Logger _logger;
  static bool _initialized = false;
  static MetricsCollector? _metrics;
  static IpfsPlatform? _platform;
  final bool _debug;
  final bool _verbose;

  /// Initializes the global metrics collector for all loggers.
  static void initializeMetrics(IPFSConfig config) {
    _metrics = MetricsCollector(config);
  }

  static void _initializeIfNeeded() {
    if (!_initialized) {
      logging.hierarchicalLoggingEnabled = true;
      logging.Logger.root.level = logging.Level.ALL;

      // Get platform for file logging (only on IO platforms)
      try {
        _platform = getPlatform();
      } catch (e) {
        // Platform not available (stub), skip file logging
        _platform = null;
      }

      logging.Logger.root.onRecord.listen((record) {
        final timestamp = DateTime.now().toIso8601String();
        final message =
            '$timestamp [${record.level.name}] [${record.loggerName}] '
            '${record.message}';

        if (record.error != null) {
          // ignore: avoid_print
          print(
            '$message\nError: ${record.error}\nStack trace: ${record.stackTrace}',
          );
          _metrics?.recordError(
            'system',
            record.loggerName,
            record.error.toString(),
          );
        } else {
          // ignore: avoid_print
          print(message);
        }

        // Only write to log file on IO platforms
        if (_platform != null && _platform!.isIO) {
          _writeToLogFile(
            '$message${record.error != null ? '\nError: ${record.error}\nStack trace: ${record.stackTrace}' : ''}',
          );
        }
      });

      _initialized = true;
    }
  }

  static void _writeToLogFile(String message) {
    if (_platform == null || !_platform!.isIO) return;

    try {
      // Use platform abstraction for file writing
      _platform!.writeBytes(
        'ipfs.log',
        // Append mode not directly supported, so we read + write
        // For simplicity, just log to console on web
        _stringToBytes('$message\n'),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Failed to write to log file: $e');
    }
  }

  static Uint8List _stringToBytes(String s) {
    return Uint8List.fromList(s.codeUnits);
  }

  /// Log a debug message
  void debug(String message) {
    if (_debug) {
      _logger.fine('[DEBUG] $message');
    }
  }

  /// Log an info message
  void info(String message) {
    _logger.info('[INFO] $message');
  }

  /// Log a warning message
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning('[WARNING] $message', error, stackTrace);
  }

  /// Log an error message with optional error object and stack trace
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe('[ERROR] $message', error, stackTrace);
  }

  /// Log a verbose message
  void verbose(String message) {
    if (_verbose) {
      _logger.fine('[VERBOSE] $message');
    }
  }

  /// Set the log level
  void setLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        _logger.level = logging.Level.FINE;
        break;
      case 'info':
        _logger.level = logging.Level.INFO;
        break;
      case 'warning':
        _logger.level = logging.Level.WARNING;
        break;
      case 'error':
        _logger.level = logging.Level.SEVERE;
        break;
      default:
        throw ArgumentError('Invalid log level: $level');
    }
  }
}
