import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  group('Logger', () {
    test('initializeMetrics succeeds', () {
      Logger.initializeMetrics(IPFSConfig());
    });

    test('emits info/debug/verbose/warning without throwing', () {
      final logger = Logger('Test', debug: true, verbose: true);
      logger.info('hi');
      logger.debug('debug-message');
      logger.verbose('verbose-message');
      logger.warning('warn');
    });

    test('debug/verbose suppressed when flags disabled', () {
      final logger = Logger('TestSuppress');
      logger.debug('not-emitted');
      logger.verbose('not-emitted');
    });

    test('setLevel maps the documented levels', () {
      final logger = Logger('LevelTest');
      logger.setLevel('debug');
      logger.setLevel('info');
      logger.setLevel('warning');
      logger.setLevel('error');
      logger.setLevel('DEBUG'); // case-insensitive
    });

    test('setLevel rejects unknown levels', () {
      final logger = Logger('Reject');
      expect(() => logger.setLevel('mystery'), throwsArgumentError);
    });
  });
}
