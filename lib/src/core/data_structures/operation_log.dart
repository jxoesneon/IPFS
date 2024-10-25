// lib/src/core/data_structures/operation_log.dart

import 'dart:collection';
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum;
import '/../src/proto/dht/operation_log.pb.dart' as proto; // Import the generated Protobuf file
import 'cid.dart'; // Import CID class for logging CIDs
import 'node_type.dart'; // Import NodeType for logging node types
import '/../src/proto/dht/node_type.pbenum.dart'; // Import the NodeTypeProto enum directly

class OperationLogEntry {
  final DateTime timestamp;
  final String operation;
  final String details;
  final CID? cid; // Optional CID involved in the operation
  final NodeType? nodeType; // Optional NodeType involved in the operation

  OperationLogEntry({
    required this.timestamp,
    required this.operation,
    required this.details,
    this.cid,
    this.nodeType,
  });

  factory OperationLogEntry.fromProto(proto.OperationLogEntry pbEntry) {
    return OperationLogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(pbEntry.timestamp.toInt()),
      operation: pbEntry.operation,
      details: pbEntry.details,
      cid: pbEntry.hasCid() ? CID.fromProto(pbEntry.cid) : null,
      nodeType: pbEntry.hasNodeType()
          ? NodeTypeExtension.fromName(pbEntry.nodeType.name)
          : null,
    );
  }

  proto.OperationLogEntry toProto() {
    final pbEntry = proto.OperationLogEntry()
      ..timestamp = fixnum.Int64(timestamp.millisecondsSinceEpoch)
      ..operation = operation
      ..details = details;

    if (cid != null) {
      pbEntry.cid = cid!.toProto();
    }

    if (nodeType != null) {
      pbEntry.nodeType = NodeTypeProto.valueOf(nodeType!.index)!; // Use the imported enum
    }

    return pbEntry;
  }

  @override
  String toString() {
    return 'OperationLogEntry(timestamp: $timestamp, operation: $operation, details: $details, cid: ${cid?.toString() ?? 'N/A'}, nodeType: ${nodeType?.name ?? 'N/A'})';
  }
}

class OperationLog {
  final Queue<OperationLogEntry> _logEntries = Queue();

  void addEntry({
    required String operation,
    required String details,
    CID? cid,
    NodeType? nodeType,
  }) {
    final entry = OperationLogEntry(
      timestamp: DateTime.now(),
      operation: operation,
      details: details,
      cid: cid,
      nodeType: nodeType,
    );
    _logEntries.add(entry);
  }

  List<OperationLogEntry> getEntries() {
    return List.unmodifiable(_logEntries);
  }

  void clear() {
    _logEntries.clear();
  }

  Uint8List serialize() {
    final protoLog = proto.OperationLog()
      ..entries.addAll(_logEntries.map((entry) => entry.toProto()));
    return protoLog.writeToBuffer();
  }

  void deserialize(Uint8List data) {
    final protoLog = proto.OperationLog.fromBuffer(data);
    _logEntries.clear();
    _logEntries.addAll(protoLog.entries.map((pbEntry) => OperationLogEntry.fromProto(pbEntry)));
  }

  @override
  String toString() {
    return _logEntries.map((entry) => entry.toString()).join('\n');
  }
}
