// test/services/pinning/remote_pinning_service_manager_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_ipfs/src/services/pinning/pinning_service_api.dart';
import 'package:dart_ipfs/src/services/pinning/remote_pinning_service.dart';

void main() {
  group('RemotePinningService manager', () {
    late Directory tempDir;
    late File configFile;
    late RemotePinningService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('remote_pinning_test');
      configFile = File('${tempDir.path}/remote_pins.json');
      service = RemotePinningService(configPath: configFile.path);
    });

    tearDown(() async {
      service.dispose();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } on PathAccessException {
          // Windows may keep the temp directory locked briefly; system cleanup
          // will handle it.
        }
      }
    });

    test('addService, hasService, listServices and getClient', () {
      service.addService(
        name: 'pinata',
        endpoint: 'https://pin.example.com',
        token: 'secret',
      );
      expect(service.hasService('pinata'), isTrue);
      expect(service.serviceNames, equals(['pinata']));
      final services = service.listServices();
      expect(services, hasLength(1));
      expect(services.first['name'], equals('pinata'));
      expect(services.first['endpoint'], equals('https://pin.example.com'));
      expect(service.getClient('pinata'), isA<PinningServiceAPIClient>());
    });

    test('addService duplicate throws', () {
      service.addService(name: 'pinata', endpoint: 'https://a', token: 't');
      expect(
        () => service.addService(name: 'pinata', endpoint: 'https://b', token: 't'),
        throwsArgumentError,
      );
    });

    test('removeService removes and throws for missing', () {
      service.addService(name: 'pinata', endpoint: 'https://a', token: 't');
      service.removeService('pinata');
      expect(service.hasService('pinata'), isFalse);
      expect(() => service.removeService('pinata'), throwsArgumentError);
    });

    test('load and listRemotePins filter', () async {
      configFile.writeAsStringSync(jsonEncode({
        'services': [
          {'name': 'pinata', 'endpoint': 'https://a', 'token': 't'},
        ],
        'remotePins': [
          {
            'cid': 'QmA',
            'serviceName': 'pinata',
            'requestId': 'req1',
            'status': 'queued',
            'name': 'pin-a',
          },
          {
            'cid': 'QmB',
            'serviceName': 'pinata',
            'requestId': 'req2',
            'status': 'pinned',
          },
        ],
      }));
      await service.load();
      expect(service.remotePins, hasLength(2));
      expect(service.listRemotePins(serviceName: 'pinata'), hasLength(2));
      expect(
        service.listRemotePins(status: PinStatus.pinned),
        hasLength(1),
      );
      final pin = service.listRemotePins(status: PinStatus.pinned).first;
      expect(pin.cid, equals('QmB'));
      expect(pin.toJson()['status'], equals('pinned'));
    });

    test('save persists services and pins', () async {
      service.addService(name: 'pinata', endpoint: 'https://a', token: 't');
      // _saveConfig is unawaited; give it a moment to finish writing.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.load();
      expect(configFile.existsSync(), isTrue);
      final content = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      expect(content['services'], hasLength(1));
    });

    test('services getter returns registered configs', () {
      service.addService(name: 'a', endpoint: 'https://a', token: 't');
      service.addService(name: 'b', endpoint: 'https://b', token: 't');
      expect(service.services, hasLength(2));
    });

    test('dispose clears clients', () {
      service.addService(name: 'a', endpoint: 'https://a', token: 't');
      service.dispose();
      expect(() => service.getClient('a'), throwsArgumentError);
    });
  });
}
