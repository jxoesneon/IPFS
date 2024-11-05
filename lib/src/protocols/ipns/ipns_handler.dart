class IPNSHandler {
  // Required record management
  Future<IPNSRecord> createRecord(CID target, PrivateKey key);
  Future<void> publishRecord(IPNSRecord record);
  Future<IPNSRecord> resolveRecord(String name);

  // Required validation
  bool validateRecord(IPNSRecord record) {
    // Check signature
    // Verify sequence number
    // Validate TTL
  }
}
