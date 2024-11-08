import 'dart:io';
import '../core/metrics/metrics_collector.dart';
import 'package:logging/logging.dart' as logging;

/// Custom logger for IPFS operations
class Logger {
  final logging.Logger _logger;
  static bool _initialized = false;
  static final MetricsCollector _metrics = MetricsCollector();

  /// Creates a new logger for the specified component
  Logger(String name) : _logger = logging.Logger(name) {
    _initializeIfNeeded();
  }

  static void _initializeIfNeeded() {
    if (!_initialized) {
      logging.hierarchicalLoggingEnabled = true;
      logging.Logger.root.level = logging.Level.INFO;
      
      logging.Logger.root.onRecord.listen((record) {
        final message = '${record.time}: ${record.level.name}: ${record.loggerName}: ${record.message}';
        
        if (record.error != null) {
          print('$message\nError: ${record.error}\nStack trace: ${record.stackTrace}');
          _metrics.recordError(
            'system',
            record.loggerName,
            record.error.toString(),
          );
        } else {
          print(message);
        }

        // Write to log file
        _writeToLogFile(message);
      });

      _initialized = true;
    }
  }

  static void _writeToLogFile(String message) {
    try {
      final logFile = File('ipfs.log');
      logFile.writeAsStringSync('$message\n', mode: FileMode.append);
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  /// Log a debug message
  void debug(String message) {
    _logger.fine(message);
  }

  /// Log an info message
  void info(String message) {
    _logger.info(message);
  }

  /// Log a warning message
  void warning(String message) {
    _logger.warning(message);
  }

  /// Log an error message with optional error object and stack trace
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
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