class BitswapHandler {
  // Required message types
  Future<void> sendWant(CID cid, int priority);
  Future<void> sendBlock(Block block, PeerID recipient);
  Future<void> sendHave(CID cid, PeerID recipient);

  // Required behaviors
  Future<void> handleNewPartner(PeerID peer);
  Future<void> handleWantlist(List<WantlistEntry> entries);

  // Session management
  BitswapSession createSession() {
    // Handle discovery, requesting, and receiving blocks
  }
}
