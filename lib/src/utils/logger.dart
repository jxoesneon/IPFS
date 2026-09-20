// src/utils/logger.dart
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart' as logging;

import '../core/config/ipfs_config.dart';
import '../core/metrics/metrics_collector.dart';
import '../platform/platform.dart';

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
  static bool _structured = false;
  static MetricsCollector? _metrics;
  static IpfsPlatform? _platform;
  final bool _debug;
  final bool _verbose;

  /// Initializes the global metrics collector for all loggers.
  static void initializeMetrics(IPFSConfig config) {
    _metrics = MetricsCollector(config);
    _structured = config.enableStructuredLogging;
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
        String message;

        if (_structured) {
          final logMap = {
            'timestamp': timestamp,
            'level': record.level.name,
            'logger': record.loggerName,
            'message': record.message,
          };
          if (record.error != null) {
            logMap['error'] = record.error.toString();
          }
          if (record.stackTrace != null) {
            logMap['stackTrace'] = record.stackTrace.toString();
          }
          message = 'JSON_LOG:${jsonEncode(logMap)}';
        } else {
          message =
              '$timestamp [${record.level.name}] [${record.loggerName}] '
              '${record.message}';
        }

        if (record.error != null) {
          _metrics?.recordError(
            'system',
            record.error!,
            record.stackTrace ?? StackTrace.current,
          );
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

  static IOSink? _logSink;

  static void _writeToLogFile(String message) {
    if (_platform == null || !_platform!.isIO) return;

    try {
      // Containers set IPFS_LOG_STDOUT so log collection sees daemon logs.
      if (Platform.environment['IPFS_LOG_STDOUT'] == '1') {
        stdout.writeln(message);
        return;
      }
      // Use platform abstraction for file writing. Use a per-process log file
      // to avoid conflicts when multiple tests/nodes run in parallel.
      final logFile = Platform.environment['IPFS_LOG_FILE'] ?? 'ipfs_$pid.log';
      _logSink ??= File(logFile).openWrite(mode: FileMode.append);
      _logSink!.writeln(message);
    } catch (e) {
      // Silently fail if log file write fails to avoid recursive issues or unwanted output
    }
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
    _logger.level = _levelFor(level);
  }

  /// Sets the root logger level, affecting every [Logger] that has not had
  /// [setLevel] called on it. Unknown values fall back to `info` and emit a
  /// warning rather than failing.
  static void setGlobalLevel(String level) {
    _initializeIfNeeded();
    logging.Logger.root.level = _levelFor(level, fallback: true);
  }

  static logging.Level _levelFor(String level, {bool fallback = false}) {
    switch (level.toLowerCase()) {
      case 'debug':
        return logging.Level.FINE;
      case 'info':
        return logging.Level.INFO;
      case 'warning':
        return logging.Level.WARNING;
      case 'error':
        return logging.Level.SEVERE;
      default:
        if (fallback) {
          logging.Logger.root.warning(
            'Unknown log level "$level"; falling back to info',
          );
          return logging.Level.INFO;
        }
        throw ArgumentError('Invalid log level: $level');
    }
  }
}
