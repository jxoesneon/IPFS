// src/core/ipld/schema/ipld_schema.dart
import 'package:fixnum/fixnum.dart';

import '../../../proto/generated/ipld/data_model.pb.dart';
import '../../errors/ipld_errors.dart';

/// A single schema validation failure.
///
/// [path] is a precise location of the offending value inside the validated
/// node, rendered in the form `field "links".[2]."Hash"` — double-quoted
/// strings are map keys and bracketed integers are list indices. The root
/// node is rendered as `value`.
class SchemaValidationError {
  /// Creates a validation error at [path] with a human readable [message].
  const SchemaValidationError({required this.path, required this.message});

  /// Path to the offending value, e.g. `field "links".[2]."Hash"`.
  final String path;

  /// Human readable explanation of the mismatch.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Result of a detailed schema validation run.
class SchemaValidationResult {
  /// Creates a result holding every collected [errors].
  const SchemaValidationResult(this.errors);

  /// All collected validation errors, in traversal order.
  final List<SchemaValidationError> errors;

  /// Whether the node satisfied the schema type.
  bool get isValid => errors.isEmpty;

  @override
  String toString() =>
      isValid ? 'valid' : errors.map((e) => e.toString()).join('\n');
}

/// IPLD schema validator for structured data validation.
///
/// Validates IPLD nodes against type schemas including structs, maps, lists,
/// enums, unions, links, and scalar kinds. Supports the commonly-used subset
/// of the IPLD schema DSL (https://ipld.io/specs/schemas/):
///
/// * `type` declarations addressed by name.
/// * Kinds: `struct`, `map`, `list`, `enum`, `union`, `link`, `bytes`,
///   `string`, `int`, `float`, `bool`, `null`, `any`, `unit`, `copy`.
/// * Field modifiers `optional` and `nullable` on struct fields, and
///   `valueNullable` on map/list value types.
/// * Representation strategies: `map`, `listpairs`, `stringpairs`, `tuple`,
///   `stringjoin` (structs and maps); `kinded`, `keyed`, `envelope`/
///   `enveloped`, `inline`, `stringprefix`, `bytesprefix`/`byteprefix`
///   (unions); `string`, `int` (enums); `advanced` (accepted, not checked).
/// * Legacy extensions are preserved: `valueConstraint` (`min`, `max`,
///   `pattern`, `minLength`, `maxLength`), `required`/`optional` field lists,
///   `strict` unknown-key rejection, and `{"kind": "type", "valueType": ...}`
///   reference wrappers.
///
/// Two validation styles are available: [validate] returns a boolean for
/// backward compatibility, while [check] returns a [SchemaValidationResult]
/// carrying every error with a precise path. [validateOrThrow] throws
/// [IPLDSchemaError] with the first offending path.
class IPLDSchema {
  /// Creates an IPLD schema with [name] and schema definition.
  ///
  /// [schema] maps type names to type declarations, each a `Map` with a
  /// `kind` key plus kind-specific members.
  IPLDSchema(this.name, this._schema);
  final Map<String, dynamic> _schema;

  /// Schema name.
  final String name;

  static const _kindToLabel = <Kind, String>{
    Kind.NULL: 'null',
    Kind.BOOL: 'bool',
    Kind.INTEGER: 'int',
    Kind.FLOAT: 'float',
    Kind.STRING: 'string',
    Kind.BYTES: 'bytes',
    Kind.LIST: 'list',
    Kind.MAP: 'map',
    Kind.LINK: 'link',
    Kind.BIG_INT: 'bigint',
  };

  static const _labelToKind = <String, Kind>{
    'null': Kind.NULL,
    'bool': Kind.BOOL,
    'int': Kind.INTEGER,
    'float': Kind.FLOAT,
    'string': Kind.STRING,
    'bytes': Kind.BYTES,
    'list': Kind.LIST,
    'map': Kind.MAP,
    'link': Kind.LINK,
    'bigint': Kind.BIG_INT,
  };

  /// Non-kind type-level words usable as bare type terms.
  static const _specialKinds = {'any', 'unit'};

  /// Union representation strategy discriminant keys (spec aliases included).
  static const _unionStrategies = {
    'kinded',
    'keyed',
    'envelope',
    'enveloped',
    'inline',
    'stringprefix',
    'bytesprefix',
    'byteprefix',
    'advanced',
  };

  /// Validates an IPLD node against the schema type.
  ///
  /// Returns `true` when [node] matches the type named [typeName].
  /// Throws [IPLDSchemaError] when the schema itself is malformed (unknown
  /// type, missing `kind`, bad references). Use [check] for per-field error
  /// paths, or [validateOrThrow] to raise on mismatched data.
  Future<bool> validate(String typeName, IPLDNode node) async {
    return check(typeName, node).isValid;
  }

  /// Validates [node] against [typeName], collecting every mismatch with a
  /// precise path instead of stopping at the first boolean answer.
  ///
  /// Throws [IPLDSchemaError] for malformed schema definitions.
  SchemaValidationResult check(String typeName, IPLDNode node) {
    final typeSchema = _schema[typeName];
    if (typeSchema == null) {
      throw IPLDSchemaError('Type not found in schema: $typeName');
    }
    if (typeSchema is! Map) {
      throw IPLDSchemaError('Schema for type "$typeName" must be a map');
    }
    final validator = _SchemaValidator(_schema);
    validator._validateType(node, _asMap(typeSchema));
    return SchemaValidationResult(validator.errors);
  }

  /// Validates [node] against [typeName], throwing [IPLDSchemaError] with the
  /// first precise error path when the node does not match.
  void validateOrThrow(String typeName, IPLDNode node) {
    final result = check(typeName, node);
    if (!result.isValid) {
      throw IPLDSchemaError(
        'Node does not match type "$typeName": ${result.errors.first}',
      );
    }
  }
}

/// A parsed struct field declaration.
class _Field {
  const _Field(
    this.name,
    this.term, {
    this.optional = false,
    this.nullable = false,
    this.specStyle = false,
  });

  final String name;
  final Object? term;
  final bool optional;
  final bool nullable;

  /// Whether the field used the spec `{type:, optional:, nullable:}` shape.
  final bool specStyle;
}

/// Stateful validation engine for a single [IPLDSchema.check] run.
class _SchemaValidator {
  _SchemaValidator(this._schema);

  final Map<String, dynamic> _schema;

  /// Accumulated validation errors.
  final List<SchemaValidationError> errors = [];

  /// Current path segments: `String` for map keys, `int` for list indices.
  final List<Object> _path = [];

  /// A map key exempt from struct unknown-key checks (inline union
  /// discriminant key).
  String? _allowedExtraKey;

  void _fail(String message) {
    errors.add(SchemaValidationError(path: _describePath(), message: message));
  }

  String _describePath() {
    if (_path.isEmpty) return 'value';
    final buffer = StringBuffer('field ');
    var first = true;
    for (final segment in _path) {
      if (!first) buffer.write('.');
      first = false;
      if (segment is int) {
        buffer
          ..write('[')
          ..write(segment)
          ..write(']');
      } else {
        buffer
          ..write('"')
          ..write(segment)
          ..write('"');
      }
    }
    return buffer.toString();
  }

  void _at(Object segment, void Function() body) {
    _path.add(segment);
    try {
      body();
    } finally {
      _path.removeLast();
    }
  }

  static String _kindLabel(Kind kind) =>
      IPLDSchema._kindToLabel[kind] ?? kind.name.toLowerCase();

  /// Validates [node] against a type definition map (a `{"kind": ...}` def).
  void _validateType(IPLDNode node, Map<String, dynamic> def) {
    var kind = def['kind'];
    if (kind == null) {
      if (def.containsKey('type')) {
        _validateTerm(node, def['type']);
        return;
      }
      throw IPLDSchemaError('Schema missing required "kind" field');
    }
    final normalized = _normalizeName('$kind');
    switch (normalized) {
      case 'type':
      case 'copy':
        _validateAliased(node, def);
      case 'any':
        break; // matches everything
      case 'unit':
        _validateUnit(node, def);
      case 'struct':
        _validateStruct(node, def);
      case 'union':
        _validateUnion(node, def);
      case 'enum':
        _validateEnum(node, def);
      case 'map':
        _validateMapType(node, def);
      case 'list':
        _validateListType(node, def);
      default:
        _validateScalar(node, normalized, def);
    }
  }

  /// Validates [node] against a type term: a type name `String`, a
  /// `{type: ...}` wrapper, or an inline `{"kind": ...}` definition.
  void _validateTerm(IPLDNode node, Object? term) {
    _validateType(node, _resolveTerm(term));
  }

  /// Chases `type`/`copy` aliases without recursing through type-name
  /// resolution, so degenerate cycles are caught while structural recursion
  /// on finite nodes remains legal.
  void _validateAliased(IPLDNode node, Map<String, dynamic> def) {
    final seen = <Object>{def};
    var current = def;
    while (true) {
      final ref = current['valueType'] ?? current['fromType'];
      if (ref == null) {
        throw IPLDSchemaError('Type reference missing valueType');
      }
      final resolved = _resolveTerm(ref);
      final k = _normalizeName('${resolved['kind']}');
      if (k == 'type' || k == 'copy') {
        if (!seen.add(resolved)) {
          throw IPLDSchemaError('Circular type reference: $ref');
        }
        current = resolved;
        continue;
      }
      _validateType(node, resolved);
      return;
    }
  }

  /// Resolves a type term to an inline type definition map.
  Map<String, dynamic> _resolveTerm(Object? term) {
    if (term is String) {
      final named = _schema[term];
      if (named is Map) return _asMap(named);
      final normalized = _normalizeName(term);
      if (IPLDSchema._labelToKind.containsKey(normalized) ||
          IPLDSchema._specialKinds.contains(normalized)) {
        return {'kind': normalized};
      }
      throw IPLDSchemaError('Referenced type not found: $term');
    }
    if (term is Map) {
      final map = _asMap(term);
      if (!map.containsKey('kind') && map.containsKey('type')) {
        return _resolveTerm(map['type']);
      }
      return map;
    }
    throw IPLDSchemaError('Invalid type term: $term');
  }

  void _validateScalar(IPLDNode node, String kind, Map<String, dynamic> def) {
    final expected = IPLDSchema._labelToKind[kind];
    if (expected == null) {
      throw IPLDSchemaError('Unknown kind in schema: $kind');
    }
    if (node.kind != expected) {
      _fail('expected $kind, found ${_kindLabel(node.kind)}');
      return;
    }
    if (def.containsKey('valueConstraint')) {
      _validateConstraint(node, def['valueConstraint']);
    }
  }

  void _validateConstraint(IPLDNode node, dynamic constraint) {
    if (constraint is! Map) return;
    switch (node.kind) {
      case Kind.INTEGER:
        final value = node.intValue.toInt();
        final min = constraint['min'];
        final max = constraint['max'];
        if (min is num && value < min) {
          _fail('int $value is less than minimum $min');
        }
        if (max is num && value > max) {
          _fail('int $value is greater than maximum $max');
        }
      case Kind.FLOAT:
        final value = node.floatValue;
        final min = constraint['min'];
        final max = constraint['max'];
        if (min is num && value < min) {
          _fail('float $value is less than minimum $min');
        }
        if (max is num && value > max) {
          _fail('float $value is greater than maximum $max');
        }
      case Kind.STRING:
        final pattern = constraint['pattern'];
        if (pattern is String && !RegExp(pattern).hasMatch(node.stringValue)) {
          _fail('string does not match pattern $pattern');
        }
        final minLength = constraint['minLength'];
        final maxLength = constraint['maxLength'];
        if (minLength is num && node.stringValue.length < minLength) {
          _fail('string is shorter than minLength $minLength');
        }
        if (maxLength is num && node.stringValue.length > maxLength) {
          _fail('string is longer than maxLength $maxLength');
        }
      case Kind.BYTES:
        final minLength = constraint['minLength'];
        final maxLength = constraint['maxLength'];
        if (minLength is num && node.bytesValue.length < minLength) {
          _fail('bytes are shorter than minLength $minLength');
        }
        if (maxLength is num && node.bytesValue.length > maxLength) {
          _fail('bytes are longer than maxLength $maxLength');
        }
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------
  // Unit
  // ---------------------------------------------------------------------

  void _validateUnit(IPLDNode node, Map<String, dynamic> def) {
    final rep = _reprKind(def);
    if (rep == null || rep == 'null') {
      if (node.kind != Kind.NULL) {
        _fail('expected null unit, found ${_kindLabel(node.kind)}');
      }
      return;
    }
    var mode = rep;
    if (rep == 'unit') {
      final cfg = _reprConfig(def, 'unit');
      mode = _normalizeName('${cfg['representation'] ?? 'null'}');
    }
    if (rep == 'advanced') return;
    switch (mode) {
      case 'null':
        if (node.kind != Kind.NULL) {
          _fail('expected null unit, found ${_kindLabel(node.kind)}');
        }
      case 'emptymap':
        if (node.kind != Kind.MAP || node.mapValue.entries.isNotEmpty) {
          _fail('expected empty map unit, found ${_kindLabel(node.kind)}');
        }
      case 'true':
        if (node.kind != Kind.BOOL || !node.boolValue) {
          _fail('expected true unit, found ${_kindLabel(node.kind)}');
        }
      case 'false':
        if (node.kind != Kind.BOOL || node.boolValue) {
          _fail('expected false unit, found ${_kindLabel(node.kind)}');
        }
      case '0':
        if (node.kind != Kind.INTEGER || node.intValue.toInt() != 0) {
          _fail('expected 0 unit, found ${_kindLabel(node.kind)}');
        }
      case '1':
        if (node.kind != Kind.INTEGER || node.intValue.toInt() != 1) {
          _fail('expected 1 unit, found ${_kindLabel(node.kind)}');
        }
      default:
        throw IPLDSchemaError('Unknown unit representation: $mode');
    }
  }

  // ---------------------------------------------------------------------
  // Structs
  // ---------------------------------------------------------------------

  void _validateStruct(IPLDNode node, Map<String, dynamic> def) {
    final rep = _reprKind(def);
    switch (rep ?? 'map') {
      case 'map':
        _validateStructMap(node, def);
      case 'tuple':
        _validateStructTuple(node, def);
      case 'stringjoin':
        _validateStructStringJoin(node, def);
      case 'stringpairs':
        _validateStructStringPairs(node, def);
      case 'listpairs':
        _validateStructListPairs(node, def);
      case 'advanced':
        break; // ADL projections cannot be validated without the layout.
      default:
        throw IPLDSchemaError('Unknown struct representation: $rep');
    }
  }

  /// Parses the `fields` map plus legacy `required`/`optional` lists into
  /// uniform [_Field] descriptors.
  Map<String, _Field> _parseFields(Map<String, dynamic> def) {
    final fieldsRaw = def['fields'];
    final required = _stringSet(def['required']);
    final optionalList = _stringSet(def['optional']);
    final fields = <String, _Field>{};
    if (fieldsRaw == null) return fields;
    if (fieldsRaw is! Map) {
      throw IPLDSchemaError('Struct "fields" must be a map');
    }
    fieldsRaw.forEach((key, value) {
      final fieldName = '$key';
      if (value is Map && !value.containsKey('kind')) {
        // Spec style: {type: ..., optional: ..., nullable: ...}.
        fields[fieldName] = _Field(
          fieldName,
          value['type'],
          optional: value['optional'] == true || optionalList.contains(fieldName),
          nullable: value['nullable'] == true,
          specStyle: true,
        );
      } else {
        // Legacy style: the value itself is the type spec; absence is allowed
        // unless the field is listed under `required`. Inline modifiers are
        // also honoured when present.
        final inlineOptional = value is Map && value['optional'] == true;
        final inlineNullable = value is Map && value['nullable'] == true;
        fields[fieldName] = _Field(
          fieldName,
          value,
          optional: inlineOptional ||
              optionalList.contains(fieldName) ||
              !required.contains(fieldName),
          nullable: inlineNullable,
        );
      }
    });
    return fields;
  }

  void _validateStructMap(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.MAP) {
      _fail('expected map for struct, found ${_kindLabel(node.kind)}');
      return;
    }
    final fields = _parseFields(def);
    // Spec-style structs reject unknown keys; legacy structs only when
    // `strict: true`.
    final strict =
        def['strict'] == true || fields.values.any((f) => f.specStyle);

    final present = <String, IPLDNode>{};
    for (final entry in node.mapValue.entries) {
      present.putIfAbsent(entry.key, () => entry.value);
    }

    for (final field in fields.values) {
      _at(field.name, () {
        final value = present[field.name];
        if (value == null) {
          if (!field.optional) {
            _fail('missing required field "${field.name}"');
          }
          return;
        }
        _validateFieldValue(value, field);
      });
    }

    if (strict) {
      for (final entry in node.mapValue.entries) {
        if (!fields.containsKey(entry.key) && entry.key != _allowedExtraKey) {
          _at(entry.key, () => _fail('unknown field "${entry.key}"'));
        }
      }
    }
  }

  void _validateFieldValue(IPLDNode value, _Field field) {
    if (value.kind == Kind.NULL) {
      if (!field.nullable) {
        _fail('field "${field.name}" is not nullable');
      }
      return;
    }
    _validateTerm(value, field.term);
  }

  void _validateStructTuple(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.LIST) {
      _fail('expected list for tuple struct, found ${_kindLabel(node.kind)}');
      return;
    }
    final fields = _parseFields(def);
    final cfg = _reprConfig(def, 'tuple');
    final order = _stringList(cfg['fieldOrder']) ?? fields.keys.toList();
    final values = node.listValue.values;
    if (values.length > order.length) {
      _fail('tuple has ${values.length} elements; at most '
          '${order.length} allowed');
    }
    for (var i = 0; i < order.length; i++) {
      final field = fields[order[i]];
      if (field == null) {
        throw IPLDSchemaError(
          'tuple fieldOrder references unknown field "${order[i]}"',
        );
      }
      _at(i, () {
        if (i >= values.length) {
          if (!field.optional) {
            _fail('missing required field "${field.name}"');
          }
          return;
        }
        final value = values[i];
        if (value.kind == Kind.NULL) {
          // In tuple representation, a null is only legal for nullable
          // fields; absent optionals must trail off the end of the list.
          if (!field.nullable) {
            _fail('field "${field.name}" is not nullable');
          }
          return;
        }
        _validateTerm(value, field.term);
      });
    }
  }

  void _validateStructStringJoin(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.STRING) {
      _fail(
        'expected string for stringjoin struct, '
        'found ${_kindLabel(node.kind)}',
      );
      return;
    }
    final fields = _parseFields(def);
    final cfg = _reprConfig(def, 'stringjoin');
    final join = '${cfg['join'] ?? cfg['delim'] ?? ':'}';
    final order = _stringList(cfg['fieldOrder']) ?? fields.keys.toList();
    final parts = node.stringValue.split(join);
    if (parts.length != order.length) {
      _fail('stringjoin expects ${order.length} fields joined by "$join"; '
          'found ${parts.length} parts');
      return;
    }
    for (var i = 0; i < order.length; i++) {
      final field = fields[order[i]];
      if (field == null) {
        throw IPLDSchemaError(
          'stringjoin fieldOrder references unknown field "${order[i]}"',
        );
      }
      _at(order[i], () => _validateStringForm(parts[i], field));
    }
  }

  void _validateStructStringPairs(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.STRING) {
      _fail(
        'expected string for stringpairs struct, '
        'found ${_kindLabel(node.kind)}',
      );
      return;
    }
    final fields = _parseFields(def);
    final cfg = _reprConfig(def, 'stringpairs');
    final innerDelim = '${cfg['innerDelim'] ?? cfg['join'] ?? '='}';
    final entrySep = '${cfg['entrySep'] ?? '&'}';
    final seen = <String>{};
    if (node.stringValue.isNotEmpty) {
      for (final entry in node.stringValue.split(entrySep)) {
        final split = entry.indexOf(innerDelim);
        if (split < 0) {
          _fail('malformed stringpairs entry "$entry"');
          continue;
        }
        final key = entry.substring(0, split);
        final raw = entry.substring(split + innerDelim.length);
        final field = fields[key];
        _at(key, () {
          if (field == null) {
            _fail('unknown field "$key"');
            return;
          }
          if (!seen.add(key)) {
            _fail('duplicate field "$key"');
            return;
          }
          _validateStringForm(raw, field);
        });
      }
    }
    _checkMissingFields(fields, seen);
  }

  void _validateStructListPairs(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.LIST) {
      _fail(
        'expected list for listpairs struct, found ${_kindLabel(node.kind)}',
      );
      return;
    }
    final fields = _parseFields(def);
    final seen = <String>{};
    final values = node.listValue.values;
    for (var i = 0; i < values.length; i++) {
      _at(i, () {
        final pair = values[i];
        if (pair.kind != Kind.LIST || pair.listValue.values.length != 2) {
          _fail('listpairs entry must be a two-element list');
          return;
        }
        final keyNode = pair.listValue.values[0];
        if (keyNode.kind != Kind.STRING) {
          _fail('listpairs key must be a string');
          return;
        }
        final key = keyNode.stringValue;
        final field = fields[key];
        if (field == null) {
          _fail('unknown field "$key"');
          return;
        }
        if (!seen.add(key)) {
          _fail('duplicate field "$key"');
          return;
        }
        _at(key, () => _validateFieldValue(pair.listValue.values[1], field));
      });
    }
    _checkMissingFields(fields, seen);
  }

  void _checkMissingFields(Map<String, _Field> fields, Set<String> seen) {
    for (final field in fields.values) {
      if (!field.optional && !seen.contains(field.name)) {
        _at(field.name, () => _fail('missing required field "${field.name}"'));
      }
    }
  }

  /// Validates a raw string form (from `stringjoin`/`stringpairs`) against a
  /// field whose type must have a string-parseable representation.
  void _validateStringForm(String raw, _Field field) {
    final resolved = _resolveTerm(field.term);
    final scalar = _scalarKindOf(resolved);
    if (scalar == null) {
      throw IPLDSchemaError(
        'field "${field.name}" has no string-parseable representation',
      );
    }
    final parsed = _nodeFromString(raw, resolved, scalar);
    if (parsed == null) {
      _fail('cannot parse "$raw" as ${_kindLabelForDef(resolved, scalar)}');
      return;
    }
    _validateType(parsed, resolved);
  }

  /// Returns the string-parseable scalar kind name for [def], or null when
  /// the type cannot be represented inside `stringjoin`/`stringpairs`.
  String? _scalarKindOf(Map<String, dynamic> def) {
    final kind = _normalizeName('${def['kind']}');
    switch (kind) {
      case 'string':
      case 'int':
      case 'float':
      case 'bool':
        return kind;
      case 'enum':
        return _reprKind(def) == 'int' ? 'int' : 'string';
      case 'type':
      case 'copy':
        final ref = def['valueType'] ?? def['fromType'];
        if (ref == null) return null;
        return _scalarKindOf(_resolveTerm(ref));
      default:
        return null;
    }
  }

  String _kindLabelForDef(Map<String, dynamic> def, String scalar) =>
      _normalizeName('${def['kind']}') == 'enum' ? 'enum' : scalar;

  IPLDNode? _nodeFromString(
    String raw,
    Map<String, dynamic> def,
    String scalar,
  ) {
    switch (scalar) {
      case 'string':
        return IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = raw;
      case 'int':
        final value = int.tryParse(raw);
        if (value == null) return null;
        return IPLDNode()
          ..kind = Kind.INTEGER
          ..intValue = Int64(value);
      case 'float':
        final value = double.tryParse(raw);
        if (value == null) return null;
        return IPLDNode()
          ..kind = Kind.FLOAT
          ..floatValue = value;
      case 'bool':
        if (raw == 'true') {
          return IPLDNode()
            ..kind = Kind.BOOL
            ..boolValue = true;
        }
        if (raw == 'false') {
          return IPLDNode()
            ..kind = Kind.BOOL
            ..boolValue = false;
        }
        return null;
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------
  // Maps
  // ---------------------------------------------------------------------

  void _validateMapType(IPLDNode node, Map<String, dynamic> def) {
    final typed = def.containsKey('keyType') ||
        def.containsKey('valueType') ||
        def.containsKey('valueNullable');
    final rep = _reprKind(def);
    if (!typed && (rep == null || rep == 'map')) {
      if (node.kind != Kind.MAP) {
        _fail('expected map, found ${_kindLabel(node.kind)}');
      }
      return;
    }
    switch (rep ?? 'map') {
      case 'map':
        _validateMapMap(node, def);
      case 'listpairs':
        _validateMapListPairs(node, def);
      case 'stringpairs':
        _validateMapStringPairs(node, def);
      case 'advanced':
        break;
      default:
        throw IPLDSchemaError('Unknown map representation: $rep');
    }
  }

  void _validateMapMap(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.MAP) {
      _fail('expected map, found ${_kindLabel(node.kind)}');
      return;
    }
    final keyType = def['keyType'];
    final valueType = def['valueType'];
    final valueNullable = def['valueNullable'] == true;
    for (final entry in node.mapValue.entries) {
      _at(entry.key, () {
        if (keyType != null) _validateMapKey(entry.key, keyType);
        final value = entry.value;
        if (value.kind == Kind.NULL) {
          if (!valueNullable) _fail('map value is not nullable');
          return;
        }
        if (valueType != null) _validateTerm(value, valueType);
      });
    }
  }

  void _validateMapListPairs(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.LIST) {
      _fail('expected list for listpairs map, found ${_kindLabel(node.kind)}');
      return;
    }
    final keyType = def['keyType'];
    final valueType = def['valueType'];
    final valueNullable = def['valueNullable'] == true;
    final values = node.listValue.values;
    for (var i = 0; i < values.length; i++) {
      _at(i, () {
        final pair = values[i];
        if (pair.kind != Kind.LIST || pair.listValue.values.length != 2) {
          _fail('listpairs entry must be a two-element list');
          return;
        }
        final keyNode = pair.listValue.values[0];
        if (keyNode.kind != Kind.STRING) {
          _fail('listpairs key must be a string');
          return;
        }
        if (keyType != null) _validateMapKey(keyNode.stringValue, keyType);
        final value = pair.listValue.values[1];
        if (value.kind == Kind.NULL) {
          if (!valueNullable) _fail('map value is not nullable');
          return;
        }
        if (valueType != null) {
          _at(keyNode.stringValue, () => _validateTerm(value, valueType));
        }
      });
    }
  }

  void _validateMapStringPairs(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.STRING) {
      _fail(
        'expected string for stringpairs map, found ${_kindLabel(node.kind)}',
      );
      return;
    }
    final cfg = _reprConfig(def, 'stringpairs');
    final innerDelim = '${cfg['innerDelim'] ?? cfg['join'] ?? '='}';
    final entrySep = '${cfg['entrySep'] ?? '&'}';
    final keyType = def['keyType'];
    final valueType = def['valueType'];
    if (node.stringValue.isEmpty) return;
    for (final entry in node.stringValue.split(entrySep)) {
      final split = entry.indexOf(innerDelim);
      if (split < 0) {
        _fail('malformed stringpairs entry "$entry"');
        continue;
      }
      final key = entry.substring(0, split);
      final raw = entry.substring(split + innerDelim.length);
      _at(key, () {
        if (keyType != null) _validateMapKey(key, keyType);
        if (valueType != null) {
          final resolved = _resolveTerm(valueType);
          final scalar = _scalarKindOf(resolved);
          if (scalar == null) {
            throw IPLDSchemaError(
              'map valueType has no string-parseable representation',
            );
          }
          final parsed = _nodeFromString(raw, resolved, scalar);
          if (parsed == null) {
            _fail('cannot parse "$raw" as $scalar');
            return;
          }
          _validateType(parsed, resolved);
        }
      });
    }
  }

  /// Validates a data-model map key string against the declared `keyType`.
  void _validateMapKey(String key, Object? keyType) {
    final resolved = _resolveTerm(keyType);
    final kind = _normalizeName('${resolved['kind']}');
    switch (kind) {
      case 'string':
      case 'any':
        break;
      case 'int':
        if (int.tryParse(key) == null) {
          _fail('map key "$key" is not a valid int');
        }
      case 'enum':
        final members = _stringList(resolved['members'] ?? resolved['values']);
        if (members == null) {
          throw IPLDSchemaError('Enum keyType missing members');
        }
        if (_reprKind(resolved) == 'int') {
          if (int.tryParse(key) == null) {
            _fail('map key "$key" is not a valid int enum member');
          }
        } else if (!members.contains(key)) {
          _fail('map key "$key" is not an enum member');
        }
      case 'type':
      case 'copy':
        final ref = resolved['valueType'] ?? resolved['fromType'];
        if (ref == null) {
          throw IPLDSchemaError('Type reference missing valueType');
        }
        _validateMapKey(key, ref);
      default:
        throw IPLDSchemaError(
          'unsupported map keyType kind: ${resolved['kind']}',
        );
    }
  }

  // ---------------------------------------------------------------------
  // Lists
  // ---------------------------------------------------------------------

  void _validateListType(IPLDNode node, Map<String, dynamic> def) {
    if (node.kind != Kind.LIST) {
      _fail('expected list, found ${_kindLabel(node.kind)}');
      return;
    }
    final rep = _reprKind(def);
    if (rep != null && rep != 'list' && rep != 'advanced') {
      throw IPLDSchemaError('Unknown list representation: $rep');
    }
    if (rep == 'advanced') return;
    final valueType = def['valueType'];
    if (valueType == null) return; // bare `list` kind check only
    final valueNullable = def['valueNullable'] == true;
    final values = node.listValue.values;
    for (var i = 0; i < values.length; i++) {
      _at(i, () {
        final value = values[i];
        if (value.kind == Kind.NULL) {
          if (!valueNullable) _fail('list element is not nullable');
          return;
        }
        _validateTerm(value, valueType);
      });
    }
  }

  // ---------------------------------------------------------------------
  // Enums
  // ---------------------------------------------------------------------

  void _validateEnum(IPLDNode node, Map<String, dynamic> def) {
    final members = _stringList(def['members'] ?? def['values']);
    if (members == null) {
      throw IPLDSchemaError('Enum missing members');
    }
    final rep = _reprKind(def) ?? 'string';
    switch (rep) {
      case 'string':
        if (node.kind != Kind.STRING || !members.contains(node.stringValue)) {
          _fail(
            'expected enum member of ${members.join('|')}, '
            'found ${_kindLabel(node.kind)}'
            '${node.kind == Kind.STRING ? ' "${node.stringValue}"' : ''}',
          );
        }
      case 'int':
        final table = _reprConfig(def, 'int');
        final allowed = table.values
            .map((v) => v is num ? v.toInt() : int.tryParse('$v'))
            .toSet();
        if (node.kind != Kind.INTEGER ||
            !allowed.contains(node.intValue.toInt())) {
          _fail('expected enum int member, found ${_kindLabel(node.kind)}'
              '${node.kind == Kind.INTEGER ? ' ${node.intValue}' : ''}');
        }
      default:
        throw IPLDSchemaError('Unknown enum representation: $rep');
    }
  }

  // ---------------------------------------------------------------------
  // Unions
  // ---------------------------------------------------------------------

  void _validateUnion(IPLDNode node, Map<String, dynamic> def) {
    final rep = def['representation'];
    if (rep is Map && rep.isNotEmpty) {
      final strategy = _normalizeName('${rep.keys.first}');
      if (IPLDSchema._unionStrategies.contains(strategy)) {
        _validateUnionRepr(node, strategy, rep[rep.keys.first]);
        return;
      }
      // Legacy shape: {tag: inline-type-spec} — try each member.
      _validateLegacyUnion(node, rep);
      return;
    }
    if (rep is String && IPLDSchema._unionStrategies.contains(rep)) {
      _validateUnionRepr(node, _normalizeName(rep), null);
      return;
    }
    throw IPLDSchemaError('Union missing representation');
  }

  void _validateLegacyUnion(IPLDNode node, Map<dynamic, dynamic> rep) {
    for (final entry in rep.entries) {
      final probe = _SchemaValidator(_schema);
      try {
        probe._validateTerm(node, entry.value);
      } on IPLDSchemaError {
        rethrow; // malformed member schema must surface
      }
      if (probe.errors.isEmpty) return;
    }
    _fail('value does not match any union member');
  }

  void _validateUnionRepr(IPLDNode node, String strategy, Object? cfgRaw) {
    final cfg = cfgRaw is Map ? _asMap(cfgRaw) : <String, dynamic>{};
    switch (strategy) {
      case 'kinded':
        _unionKinded(node, cfg);
      case 'keyed':
        _unionKeyed(node, cfg);
      case 'envelope':
      case 'enveloped':
        _unionEnveloped(node, cfg);
      case 'inline':
        _unionInline(node, cfg);
      case 'stringprefix':
        _unionStringPrefix(node, cfg);
      case 'bytesprefix':
      case 'byteprefix':
        _unionBytePrefix(node, cfg);
      case 'advanced':
        break;
      default:
        throw IPLDSchemaError('Unknown union representation: $strategy');
    }
  }

  void _unionKinded(IPLDNode node, Map<String, dynamic> table) {
    if (table.isEmpty) {
      throw IPLDSchemaError('kinded union requires a kind table');
    }
    final normalized = <String, Object?>{};
    table.forEach((k, v) => normalized[_normalizeName(k)] = v);
    final term = normalized[_kindLabel(node.kind)];
    if (term == null) {
      _fail('no union member for kind ${_kindLabel(node.kind)}');
      return;
    }
    _validateTerm(node, term);
  }

  void _unionKeyed(IPLDNode node, Map<String, dynamic> table) {
    if (node.kind != Kind.MAP) {
      _fail('expected map for keyed union, found ${_kindLabel(node.kind)}');
      return;
    }
    final entries = node.mapValue.entries;
    if (entries.length != 1) {
      _fail('keyed union requires a map with exactly one entry');
      return;
    }
    final key = entries.first.key;
    final term = table[key];
    if (term == null) {
      _fail('no union member for key "$key"');
      return;
    }
    _at(key, () => _validateTerm(entries.first.value, term));
  }

  void _unionEnveloped(IPLDNode node, Map<String, dynamic> cfg) {
    final discriminantKey = cfg['discriminantKey'];
    final table = cfg['table'];
    if (discriminantKey is! String || table is! Map) {
      throw IPLDSchemaError(
        'envelope union requires discriminantKey and table',
      );
    }
    if (node.kind != Kind.MAP) {
      _fail('expected map for envelope union, found ${_kindLabel(node.kind)}');
      return;
    }
    final entries = node.mapValue.entries;
    String? tag;
    for (final entry in entries) {
      if (entry.key == discriminantKey && entry.value.kind == Kind.STRING) {
        tag = entry.value.stringValue;
      }
    }
    if (tag == null) {
      _fail('envelope union missing string discriminant "$discriminantKey"');
      return;
    }
    // The content entry must be keyed by the tag value itself.
    IPLDNode? content;
    var extraKeys = 0;
    for (final entry in entries) {
      if (entry.key == tag) {
        content = entry.value;
      } else if (entry.key != discriminantKey) {
        extraKeys++;
      }
    }
    if (content == null || extraKeys > 0) {
      _fail('envelope union requires exactly discriminant and "$tag" keys');
      return;
    }
    final term = _asMap(table)[tag];
    if (term == null) {
      _fail('no union member for envelope tag "$tag"');
      return;
    }
    _at(tag, () => _validateTerm(content!, term));
  }

  void _unionInline(IPLDNode node, Map<String, dynamic> cfg) {
    final discriminantKey = cfg['discriminantKey'];
    final table = cfg['table'];
    if (discriminantKey is! String || table is! Map) {
      throw IPLDSchemaError('inline union requires discriminantKey and table');
    }
    if (node.kind != Kind.MAP) {
      _fail('expected map for inline union, found ${_kindLabel(node.kind)}');
      return;
    }
    String? tag;
    for (final entry in node.mapValue.entries) {
      if (entry.key == discriminantKey && entry.value.kind == Kind.STRING) {
        tag = entry.value.stringValue;
      }
    }
    if (tag == null) {
      _fail('inline union missing string discriminant "$discriminantKey"');
      return;
    }
    final term = _asMap(table)[tag];
    if (term == null) {
      _fail('no union member for inline tag "$tag"');
      return;
    }
    final resolved = _resolveTerm(term);
    if (_normalizeName('${resolved['kind']}') != 'struct') {
      throw IPLDSchemaError(
        'inline union members must be structs, got ${resolved['kind']}',
      );
    }
    final saved = _allowedExtraKey;
    _allowedExtraKey = discriminantKey;
    try {
      _validateType(node, resolved);
    } finally {
      _allowedExtraKey = saved;
    }
  }

  void _unionStringPrefix(IPLDNode node, Map<String, dynamic> cfg) {
    if (node.kind != Kind.STRING) {
      _fail(
        'expected string for stringprefix union, '
        'found ${_kindLabel(node.kind)}',
      );
      return;
    }
    final delim = '${cfg['delim'] ?? ''}';
    final table = cfg.containsKey('table')
        ? _asMap(cfg['table'])
        : (Map<String, dynamic>.of(cfg)..remove('delim'));
    if (table.isEmpty) {
      throw IPLDSchemaError('stringprefix union requires a table');
    }
    // Longest prefixes first so more specific tags win.
    final prefixes = table.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final value = node.stringValue;
    for (final prefix in prefixes) {
      if (value.startsWith('$prefix$delim')) {
        final rest = value.substring(prefix.length + delim.length);
        _validateTerm(
          IPLDNode()
            ..kind = Kind.STRING
            ..stringValue = rest,
          table[prefix],
        );
        return;
      }
    }
    _fail('no union member prefix matched "$value"');
  }

  void _unionBytePrefix(IPLDNode node, Map<String, dynamic> cfg) {
    if (node.kind != Kind.BYTES) {
      _fail(
        'expected bytes for bytesprefix union, '
        'found ${_kindLabel(node.kind)}',
      );
      return;
    }
    final table =
        cfg.containsKey('table') ? _asMap(cfg['table']) : cfg;
    if (table.isEmpty) {
      throw IPLDSchemaError('bytesprefix union requires a table');
    }
    final bytes = node.bytesValue;
    if (bytes.isEmpty) {
      _fail('bytesprefix union requires at least one byte');
      return;
    }
    final prefix = bytes.first;
    // `_asMap` stringifies keys, so int-keyed tables are already normalized.
    final term = table['$prefix'];
    if (term == null) {
      _fail('no union member for byte prefix $prefix');
      return;
    }
    _validateTerm(
      IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = bytes.sublist(1),
      term,
    );
  }

  // ---------------------------------------------------------------------
  // Representation clause helpers
  // ---------------------------------------------------------------------

  /// Returns the single discriminant key of a `representation` clause, or
  /// null when absent. Accepts both map (`{map: {}}`) and bare-string
  /// (`'map'`) spellings.
  String? _reprKind(Map<String, dynamic> def) {
    final rep = def['representation'];
    if (rep == null) return null;
    if (rep is String) return _normalizeName(rep);
    if (rep is Map) {
      if (rep.isEmpty) return null;
      return _normalizeName('${rep.keys.first}');
    }
    throw IPLDSchemaError('Invalid representation clause');
  }

  /// Returns the config map nested under `representation.<kind>`.
  Map<String, dynamic> _reprConfig(Map<String, dynamic> def, String kind) {
    final rep = def['representation'];
    if (rep is Map) {
      final cfg = rep[kind];
      if (cfg is Map) return _asMap(cfg);
    }
    return <String, dynamic>{};
  }
}

/// Coerces a loose map to `Map<String, dynamic>` with stringified keys.
Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    // Note: `MapEntry` resolves to the generated protobuf class here, so
    // build the copy imperatively instead of using `Map.map`.
    final out = <String, dynamic>{};
    value.forEach((k, v) => out['$k'] = v);
    return out;
  }
  throw IPLDSchemaError('Expected map in schema, got $value');
}

/// Lowercases and canonicalizes kind/type/representation names
/// (`integer`→`int`, `boolean`→`bool`).
String _normalizeName(String name) {
  final lowered = name.toLowerCase();
  return switch (lowered) {
    'integer' => 'int',
    'boolean' => 'bool',
    _ => lowered,
  };
}

List<String>? _stringList(Object? value) {
  if (value == null) return null;
  if (value is List) return value.map((e) => '$e').toList();
  throw IPLDSchemaError('Expected list of strings, got $value');
}

Set<String> _stringSet(Object? value) => _stringList(value)?.toSet() ?? {};
