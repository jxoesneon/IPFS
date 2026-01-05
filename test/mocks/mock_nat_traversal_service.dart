import 'package:dart_ipfs/src/network/nat_traversal_service.dart';

class MockNatTraversalService implements NatTraversalService {
  final List<String> mappedProtocols = ['TCP', 'UDP'];
  final List<int> mappedPorts = [];
  final List<int> unmappedPorts = [];

  @override
  Future<List<String>> mapPort(int port, {Duration? leaseDuration}) async {
    mappedPorts.add(port);
    return mappedProtocols;
  }

  @override
  Future<void> unmapPort(int port) async {
    unmappedPorts.add(port);
  }
}
