import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/config/config.dart'; // Adjust the import path as necessary

void main() {
  group('IPFSConfig', () {
    test('Default constructor sets default values', () {
      final config = IPFSConfig();

      expect(config.addresses, ['/ip4/0.0.0.0/tcp/4001', '/ip6/::/tcp/4001']);
      expect(config.bootstrapPeers.length, 4);
      expect(config.datastorePath, './ipfs_data');
      expect(config.keystorePath, './ipfs_keystore');
      expect(config.maxConnections, 100);
      expect(config.enablePubSub, true);
      expect(config.enableDHT, true);
      expect(config.enableCircuitRelay, true);
      expect(config.enableContentRouting, true);
      expect(config.enableDNSLinkResolution, true);
      expect(config.enableIPLD, true);
      expect(config.enableGraphsync, true);
      expect(config.enableMetrics, true);
      expect(config.enableLogging, true);
      expect(config.logLevel, 'info');
      expect(config.enableQuotaManagement, true);
      expect(config.defaultDiskQuota, 1073741824); // 1 GB
      expect(config.defaultBandwidthQuota, 1048576); // 1 MB/s
      expect(config.garbageCollectionEnabled, true);
      expect(config.garbageCollectionInterval, Duration(hours: 24));
      
      // Check default SecurityConfig values
      final security = config.security;
      expect(security.enableTLS, false);
      expect(security.tlsCertificatePath, isNull);
      expect(security.tlsPrivateKeyPath, isNull);
    });

    test('Custom constructor sets provided values', () {
      final customSecurity = SecurityConfig(
        enableTLS: true,
        tlsCertificatePath: '/path/to/cert',
        tlsPrivateKeyPath: '/path/to/key',
      );

      final config = IPFSConfig(
        addresses: ['/ip4/127.0.0.1/tcp/5001'],
        bootstrapPeers: ['/dnsaddr/custom.peer'],
        datastorePath: '/custom/datastore',
        keystorePath: '/custom/keystore',
        maxConnections: 50,
        enablePubSub: false,
        enableDHT: false,
        enableCircuitRelay: false,
        enableContentRouting: false,
        enableDNSLinkResolution: false,
        enableIPLD: false,
        enableGraphsync: false,
        enableMetrics: false,
        enableLogging: false,
        logLevel: 'debug',
        enableQuotaManagement: false,
        defaultDiskQuota: 2147483648, // 2 GB
        defaultBandwidthQuota: 2097152, // 2 MB/s
        garbageCollectionEnabled: false,
        garbageCollectionInterval: Duration(hours: 12),
        security: customSecurity,
      );

      expect(config.addresses, ['/ip4/127.0.0.1/tcp/5001']);
      expect(config.bootstrapPeers.length, 1);
      expect(config.datastorePath, '/custom/datastore');
      expect(config.keystorePath, '/custom/keystore');
      expect(config.maxConnections, 50);
      expect(config.enablePubSub, false);
      expect(config.enableDHT, false);
      expect(config.enableCircuitRelay, false);
      expect(config.enableContentRouting, false);
      expect(config.enableDNSLinkResolution, false);
      expect(config.enableIPLD, false);
      expect(config.enableGraphsync, false);
      expect(config.enableMetrics, false);
      expect(config.enableLogging, false);
      expect(config.logLevel, 'debug');
      expect(config.enableQuotaManagement, false);
      expect(config.defaultDiskQuota, 2147483648); // 2 GB
      expect(config.defaultBandwidthQuota, 2097152); // 2 MB/s
      expect(config.garbageCollectionEnabled, false);
      expect(
          config.garbageCollectionInterval.inHours == Duration(hours: 12, minutes: 0).inHours, true);

      
     // Check custom SecurityConfig values
     final security = config.security;
    	expect(security.enableTLS,true );
    	expect(security.tlsCertificatePath,'/path/to/cert' );
    	expect(security.tlsPrivateKeyPath,'/path/to/key' );
    });
    
});
}