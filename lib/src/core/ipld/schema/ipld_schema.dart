// src/core/ipld/schema/ipld_schema.dart
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

/// IPLD schema validator for structured data validation.
///
/// Validates IPLD nodes against type schemas including structs,
/// unions, and basic types with optional constraints.
class IPLDSchema {
  /// Creates an IPLD schema with [name] and schema definition.
  IPLDSchema(this.name, this._schema);
  final Map<String, dynamic> _schema;

  /// Schema name.
  final String name;
  static const _advancedTypes = {
    'link': Kind.LINK,
    'bytes': Kind.BYTES,
    'string': Kind.STRING,
    'bool': Kind.BOOL,
    'int': Kind.INTEGER,
    'float': Kind.FLOAT,
    'null': Kind.NULL,
    'map': Kind.MAP,
    'list': Kind.LIST,
  };

  /// Validates an IPLD node against the schema type.
  Future<bool> validate(String typeName, IPLDNode node) async {
    final typeSchema = _schema[typeName];
    if (typeSchema == null) {
      throw IPLDSchemaError('Type not found in schema: $typeName');
    }

    try {
      return _validateNode(node, typeSchema as Map<String, dynamic>);
    } catch (e) {
      throw IPLDSchemaError('Validation error: $e');
    }
  }

  bool _validateNode(IPLDNode node, Map<String, dynamic> schema) {
    final kind = schema['kind'];
    if (kind == null) {
      throw IPLDSchemaError('Schema missing required "kind" field');
    }

    // Handle type references
    if (kind == 'type') {
      final ref = schema['valueType'];
      if (ref == null) {
        throw IPLDSchemaError('Type reference missing valueType');
      }
      final refSchema = _schema[ref];
      if (refSchema == null) {
        throw IPLDSchemaError('Referenced type not found: $ref');
      }
      return _validateNode(node, refSchema as Map<String, dynamic>);
    }

    // Handle unions
    if (kind == 'union') {
      final representatives = schema['representation'] as Map<String, dynamic>?;
      if (representatives == null) {
        throw IPLDSchemaError('Union missing representation');
      }

      for (final type in representatives.values) {
        try {
          if (_validateNode(node, type as Map<String, dynamic>)) {
            return true;
          }
        } catch (_) {
          continue;
        }
      }
      return false;
    }

    // Handle structs
    if (kind == 'struct') {
      if (node.kind != Kind.MAP) return false;
      final fields = schema['fields'] as Map<String, dynamic>?;
      if (fields == null) return true;

      final required = schema['required'] as List<String>? ?? [];

      for (final requiredField in required) {
        if (!node.mapValue.entries.any((e) => e.key == requiredField)) {
          return false;
        }
      }

      return _validateMap(node.mapValue, schema);
    }

    // Handle basic types
    final expectedKind = _advancedTypes[kind];
    if (expectedKind == null) {
      throw IPLDSchemaError('Unknown kind in schema: $kind');
    }

    if (node.kind != expectedKind) return false;

    // Additional constraints
    if (schema.containsKey('valueConstraint')) {
      return _validateConstraint(node, schema['valueConstraint']);
    }

    return true;
  }

  bool _validateConstraint(IPLDNode node, dynamic constraint) {
    switch (node.kind) {
      case Kind.INTEGER:
        if (constraint is Map) {
          final min = constraint['min'] as int?;
          final max = constraint['max'] as int?;
          final value = node.intValue.toInt();
          if (min != null && value < min) return false;
          if (max != null && value > max) return false;
        }
        break;
      case Kind.STRING:
        if (constraint is Map) {
          final pattern = constraint['pattern'] as String?;
          if (pattern != null) {
            return RegExp(pattern).hasMatch(node.stringValue);
          }
          final minLength = constraint['minLength'] as int?;
          final maxLength = constraint['maxLength'] as int?;
          if (minLength != null && node.stringValue.length < minLength) {
            return false;
          }
          if (maxLength != null && node.stringValue.length > maxLength) {
            return false;
          }
        }
        break;
      case Kind.BYTES:
        if (constraint is Map) {
          final minLength = constraint['minLength'] as int?;
          final maxLength = constraint['maxLength'] as int?;
          if (minLength != null && node.bytesValue.length < minLength) {
            return false;
          }
          if (maxLength != null && node.bytesValue.length > maxLength) {
            return false;
          }
        }
        break;
      default:
        return true;
    }
    return true;
  }

  bool _validateMap(IPLDMap map, Map<String, dynamic> schema) {
    final fields = schema['fields'] as Map<String, dynamic>?;
    if (fields == null) return true;

    // Check each field in the map against schema
    for (final entry in map.entries) {
      final fieldSchema = fields[entry.key];
      if (fieldSchema == null) {
        // If strict validation is required, return false for unknown fields
        if (schema['strict'] == true) return false;
        continue;
      }

      // Validate the field value against its schema
      if (!_validateNode(entry.value, fieldSchema as Map<String, dynamic>)) {
        return false;
      }
    }

    // Check for required fields
    final required = schema['required'] as List<String>? ?? [];
    for (final requiredField in required) {
      if (!map.entries.any((e) => e.key == requiredField)) {
        return false;
      }
    }

    // Check for optional fields
    final optional = schema['optional'] as List<String>? ?? [];
    for (final entry in map.entries) {
      if (!required.contains(entry.key) && !optional.contains(entry.key)) {
        // If strict validation is required, return false for unknown fields
        if (schema['strict'] == true) return false;
      }
    }

    return true;
  }
}

