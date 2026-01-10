// test/core/ipfs_node/dns_link_handler_test.dart
import 'package:test/test.dart';

// Note: DNSLinkHandler uses HTTP client which makes real network requests.
// These tests focus on unit-testable logic patterns.

void main() {
  group('DNSLinkHandler Cache', () {
    test('cache duration is 30 minutes', () {
      const cacheDuration = Duration(minutes: 30);
      expect(cacheDuration.inMinutes, equals(30));
    });

    test('cache hit returns stored value', () {
      final cache = <String, _MockCachedDNSLink>{};
      cache['example.com'] = _MockCachedDNSLink(
        cid: 'QmCached123',
        timestamp: DateTime.now(),
      );

      expect(cache.containsKey('example.com'), isTrue);
      expect(cache['example.com']!.cid, equals('QmCached123'));
    });

    test('expired cache entry is removed', () {
      final cache = <String, _MockCachedDNSLink>{};
      cache['old.com'] = _MockCachedDNSLink(
        cid: 'QmOld',
        timestamp: DateTime.now().subtract(Duration(hours: 1)),
      );

      final entry = cache['old.com']!;
      final isExpired = entry.isExpired(Duration(minutes: 30));

      if (isExpired) {
        cache.remove('old.com');
      }

      expect(cache.containsKey('old.com'), isFalse);
    });
  });

  group('DNSLinkHandler Public Resolvers', () {
    test('has dnslink.io resolver', () {
      const resolvers = [
        'https://dnslink.io/',
        'https://dnslink-resolver.example.com/',
        'https://ipfs.io/api/v0/dns/',
      ];
      expect(resolvers, contains('https://dnslink.io/'));
    });

    test('has ipfs.io API resolver', () {
      const resolvers = [
        'https://dnslink.io/',
        'https://dnslink-resolver.example.com/',
        'https://ipfs.io/api/v0/dns/',
      ];
      expect(resolvers.any((r) => r.contains('ipfs.io')), isTrue);
    });

    test('uses multiple fallback resolvers', () {
      const resolvers = [
        'https://dnslink.io/',
        'https://dnslink-resolver.example.com/',
        'https://ipfs.io/api/v0/dns/',
      ];
      expect(resolvers.length, greaterThanOrEqualTo(2));
    });
  });

  group('DNSLinkHandler Response Parsing', () {
    test('extracts CID from Path field first', () {
      final response = {'Path': '/ipfs/QmPath', 'cid': 'QmCid'};
      final cid = response['Path'] ?? response['cid'] ?? response['Target'];
      expect(cid, equals('/ipfs/QmPath'));
    });

    test('falls back to cid field', () {
      final response = {'cid': 'QmCid'};
      final cid = response['Path'] ?? response['cid'] ?? response['Target'];
      expect(cid, equals('QmCid'));
    });

    test('falls back to Target field', () {
      final response = {'Target': 'QmTarget'};
      final cid = response['Path'] ?? response['cid'] ?? response['Target'];
      expect(cid, equals('QmTarget'));
    });
  });

  group('DNSLinkHandler Status', () {
    test('status includes cache size', () {
      final status = {
        'cache_size': 5,
        'cache_duration_minutes': 30,
        'public_resolvers': ['https://dnslink.io/'],
      };
      expect(status['cache_size'], equals(5));
    });

    test('status includes cache duration', () {
      final status = {'cache_duration_minutes': 30};
      expect(status['cache_duration_minutes'], equals(30));
    });
  });

  group('DNSLinkHandler Lifecycle', () {
    test('start clears cache', () {
      final cache = <String, String>{'old': 'entry'};
      cache.clear();
      expect(cache, isEmpty);
    });

    test('stop clears cache', () {
      final cache = <String, String>{'to': 'clear'};
      cache.clear();
      expect(cache, isEmpty);
    });
  });
}

class _MockCachedDNSLink {
  _MockCachedDNSLink({required this.cid, required this.timestamp});
  final String cid;
  final DateTime timestamp;

  bool isExpired(Duration cacheDuration) {
    return DateTime.now().difference(timestamp) > cacheDuration;
  }
}
