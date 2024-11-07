class IPFSDirectoryService {
  final IPFSDirectoryManager _directoryManager;

  IPFSDirectoryService(String rootPath)
      : _directoryManager = IPFSDirectoryManager(rootPath);

  Future<IPFSNode> createDirectory(String path) async {
    // Create a new directory node
    final node = IPFSNode.directory(
      cid: await _generateCID(path),
      links: [],
    );

    // Add to directory manager
    _directoryManager.addEntry(IPFSDirectoryEntry(
      name: path.split('/').last,
      hash: node.cid.bytes,
      size: node.size,
      isDirectory: true,
    ));

    return node;
  }
}
