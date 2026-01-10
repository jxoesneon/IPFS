import 'dart:collection';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

import '../../proto/generated/core/cid.pb.dart';
import '../../proto/generated/core/node_type.pbenum.dart';
import '../../proto/generated/core/operation_log.pb.dart';

/// A single entry in the operation log.
///
/// Records an operation with timestamp, details, and optional CID/node type.
class OperationLogEntry {
  /// Creates an operation log entry.
  OperationLogEntry({
    required this.timestamp,
    required this.operation,
    required this.details,
    this.cid,
    this.nodeType,
  });

  /// Creates an [OperationLogEntry] from its protobuf representation.
  factory OperationLogEntry.fromProto(OperationLogEntryProto pbEntry) {
    return OperationLogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(pbEntry.timestamp.toInt()),
      operation: pbEntry.operation,
      details: pbEntry.details,
      cid: pbEntry.hasCid() ? CID.fromProto(pbEntry.cid) : null,
      nodeType: pbEntry.hasNodeType() ? pbEntry.nodeType : null,
    );
  }

  /// When the operation occurred.
  final DateTime timestamp;

  /// The operation type (e.g., 'add', 'remove', 'pin').
  final String operation;

  /// Human-readable details about the operation.
  final String details;

  /// The CID involved, if any.
  final CID? cid;

  /// The node type involved, if any.
  final NodeTypeProto? nodeType;

  /// Converts this entry to its protobuf representation.
  OperationLogEntryProto toProto() {
    final pbEntry = OperationLogEntryProto();
    return pbEntry
      ..timestamp = fixnum.Int64(timestamp.millisecondsSinceEpoch)
      ..operation = operation
      ..details = details
      ..cid = cid?.toProto() ?? IPFSCIDProto()
      ..nodeType = nodeType!;
  }

  @override
  String toString() {
    return 'OperationLogEntry(timestamp: $timestamp, operation: $operation, details: $details, cid: ${cid?.toString() ?? 'N/A'}, nodeType: ${nodeType?.name ?? 'N/A'})';
  }
}

/// A circular log of operations performed on the datastore.
class OperationLog {
  final Queue<OperationLogEntry> _logEntries = Queue();

  /// Records a new operation in the log.
  void addEntry({
    required String operation,
    required String details,
    CID? cid,
    NodeTypeProto? nodeType,
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

  /// Returns an immutable list of all log entries.
  List<OperationLogEntry> getEntries() {
    return List.unmodifiable(_logEntries);
  }

  /// Clears all entries from the log.
  void clear() {
    _logEntries.clear();
  }

  /// Serializes the entire log to a byte array.
  Uint8List serialize() {
    final protoLog = OperationLogProto()
      ..entries.addAll(_logEntries.map((entry) => entry.toProto()));
    return protoLog.writeToBuffer();
  }

  /// Deserializes a log from a byte array, replacing all entries.
  void deserialize(Uint8List data) {
    final protoLog = OperationLogProto.fromBuffer(data);
    _logEntries.clear();
    _logEntries.addAll(
      protoLog.entries.map((pbEntry) => OperationLogEntry.fromProto(pbEntry)),
    );
  }

  @override
  String toString() {
    return _logEntries.map((entry) => entry.toString()).join('\n');
  }
}
