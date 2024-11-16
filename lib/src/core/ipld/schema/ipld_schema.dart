// src/core/ipld/schema/ipld_schema.dart
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';

class IPLDSchema {
  final Map<String, dynamic> _schema;
  final String name;

  IPLDSchema(this.name, this._schema);

  Future<bool> validate(String typeName, IPLDNode node) async {
    final typeSchema = _schema[typeName];
    if (typeSchema == null) {
      throw IPLDSchemaError('Type not found in schema: $typeName');
    }

    try {
      return _validateNode(node, typeSchema);
    } catch (e) {
      throw IPLDSchemaError('Validation error: $e');
    }
  }

  bool _validateNode(IPLDNode node, Map<String, dynamic> schema) {
    final kind = schema['kind'];

    switch (node.kind) {
      case Kind.MAP:
        return _validateMap(node.mapValue, schema);
      case Kind.LIST:
        return _validateList(node.listValue, schema);
      case Kind.LINK:
        return _validateLink(node.linkValue, schema);
      case Kind.STRING:
        return kind == 'string';
      case Kind.INTEGER:
        return kind == 'int';
      case Kind.FLOAT:
        return kind == 'float';
      case Kind.BOOL:
        return kind == 'bool';
      case Kind.BYTES:
        return kind == 'bytes';
      case Kind.NULL:
        return kind == 'null';
      default:
        return false;
    }
  }

  bool _validateMap(IPLDMap map, Map<String, dynamic> schema) {
    if (schema['kind'] != 'map') return false;

    final fields = schema['fields'] as Map<String, dynamic>?;
    if (fields == null) return true;

    for (final entry in map.entries) {
      final fieldSchema = fields[entry.key];
      if (fieldSchema == null) continue;
      if (!_validateNode(entry.value, fieldSchema)) return false;
    }

    return true;
  }

  bool _validateList(IPLDList list, Map<String, dynamic> schema) {
    if (schema['kind'] != 'list') return false;

    final valueSchema = schema['valueType'];
    if (valueSchema == null) return true;

    for (final value in list.values) {
      if (!_validateNode(value, valueSchema)) return false;
    }

    return true;
  }

  bool _validateLink(IPLDLink link, Map<String, dynamic> schema) {
    return schema['kind'] == 'link';
  }
}
