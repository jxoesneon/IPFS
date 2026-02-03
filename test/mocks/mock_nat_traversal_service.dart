import 'package:dart_ipfs/src/network/nat_traversal_service.dart';

class MockNatTraversalService implements NatTraversalService {
  final List<String> mappedProtocols = ['TCP', 'UDP'];
  final List<int> mappedPorts = [];
  final List<int> unmappedPorts = [];
  bool shouldFail = false;
  bool shouldThrow = false;
  List<String> lastMappingResult = [];

  @override
  Future<List<String>> mapPort(int port, {Duration? leaseDuration}) async {
    if (shouldThrow) throw Exception('NAT service error');
    mappedPorts.add(port);
    if (shouldFail) {
      lastMappingResult = [];
      return [];
    }
    lastMappingResult = mappedProtocols;
    return mappedProtocols;
  }

  @override
  Future<void> unmapPort(int port) async {
    if (shouldThrow) throw Exception('NAT service unmap error');
    unmappedPorts.add(port);
  }
}

