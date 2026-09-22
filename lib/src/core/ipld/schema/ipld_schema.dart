// src/core/ipld/schema/ipld_schema.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';

import '../../../proto/generated/ipld/data_model.pb.dart';
import '../../cid.dart';
import '../../errors/ipld_errors.dart';

/// Resolves the node an [IPLDLink] points at.
///
/// Implementations typically wrap a block-store load path such as
/// `IPLDHandler.getNode`; use [IPLDSchema.linkResolverFromNodeLoader] to
/// adapt a `CID`-based loader. Returning `null` marks the target as
/// unavailable, which is reported as a validation error at the link's path
/// when the link type carries an `expectedType` clause.
typedef IPLDLinkResolver = Future<IPLDNode?> Function(IPLDLink link);

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
///   (unions); `string`, `int` (enums); `advanced` (see below).
/// * Link types may carry `expectedType` (e.g. `{"kind": "link",
///   "expectedType": "Foo"}`). When an [IPLDLinkResolver] is supplied —
///   per call or via the constructor — the link target is loaded and
///   validated against that type, with failures reported at the link's
///   path. Without a resolver links are kind-checked only.
/// * `advanced` representations name an ADL whose data-model shape is
///   declared in the schema's top-level `advanced` map (`{<adl>: <term>}`)
///   or the [adlTypes] registry. The ADL name is taken from
///   `representation: {advanced: <name>}`, or defaults to the type's own
///   name per the IPLD spec. A `representation` clause that explicitly
///   references an undeclared ADL name throws [IPLDSchemaError] when the
///   schema is constructed; ADLs that are merely unknown (no declared or
///   registered schema) skip validation leniently.
/// * Legacy extensions are preserved: `valueConstraint` (`min`, `max`,
///   `pattern`, `minLength`, `maxLength`), `required`/`optional` field lists,
///   `strict` unknown-key rejection, and `{"kind": "type", "valueType": ...}`
///   reference wrappers.
///
/// Two validation styles are available: [validate] returns a boolean for
/// backward compatibility, while [check] returns a [SchemaValidationResult]
/// carrying every error with a precise path. [validateOrThrow] throws
/// [IPLDSchemaError] with the first offending path. The synchronous
/// [check]/[validateOrThrow] entry points never resolve links; use
/// [checkAsync]/[validateOrThrowAsync] (or [validate] with a resolver) to
/// enforce link `expectedType` clauses.
class IPLDSchema {
  /// Creates an IPLD schema with [name] and schema definition.
  ///
  /// [schema] maps type names to type declarations, each a `Map` with a
  /// `kind` key plus kind-specific members. The reserved key `advanced`
  /// may hold a `Map` of ADL names to the type terms that describe their
  /// data-model nodes.
  ///
  /// [linkResolver] is the default resolver used by [validate] and
  /// [checkAsync] when a link type carries `expectedType`; passing a
  /// resolver per call overrides it. [adlTypes] registers extra ADL
  /// schemas — values are type terms (a type name or an inline `kind`
  /// definition) resolved in this schema, or an [IPLDSchema] whose
  /// ADL-named type is checked directly.
  ///
  /// Throws [IPLDSchemaError] immediately when a `representation` clause
  /// explicitly references an ADL name that is declared neither in the
  /// schema's `advanced` block nor in [adlTypes].
  IPLDSchema(
    this.name,
    this._schema, {
    IPLDLinkResolver? linkResolver,
    Map<String, Object?>? adlTypes,
  }) : _linkResolver = linkResolver,
       _adlTypes = adlTypes {
    _lintAdvancedDeclarations();
  }
  final Map<String, dynamic> _schema;
  final IPLDLinkResolver? _linkResolver;
  final Map<String, Object?>? _adlTypes;

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
  ///
  /// When [linkResolver] (or the resolver given to the constructor) is
  /// available, link `expectedType` clauses are enforced by loading each
  /// link target; otherwise links are kind-checked only.
  Future<bool> validate(
    String typeName,
    IPLDNode node, {
    IPLDLinkResolver? linkResolver,
  }) async {
    final resolver = linkResolver ?? _linkResolver;
    if (resolver == null) return check(typeName, node).isValid;
    return (await checkAsync(typeName, node, linkResolver: resolver)).isValid;
  }

  /// Validates [node] against [typeName], collecting every mismatch with a
  /// precise path instead of stopping at the first boolean answer.
  ///
  /// This entry point is synchronous and therefore never resolves links:
  /// `expectedType` clauses are kind-checked only. Use [checkAsync] to
  /// enforce them.
  ///
  /// Throws [IPLDSchemaError] for malformed schema definitions.
  SchemaValidationResult check(String typeName, IPLDNode node) {
    final validator = _SchemaValidator(_schema, adlTypes: _adlTypes);
    validator._validateType(node, _typeDef(typeName), typeName: typeName);
    return SchemaValidationResult(validator.errors);
  }

  /// Validates [node] against [typeName] like [check], additionally
  /// resolving link targets when an [IPLDLinkResolver] is available.
  ///
  /// [linkResolver] overrides the constructor-supplied resolver; when both
  /// are absent this behaves exactly like [check] (links are kind-checked
  /// only). With a resolver, every `link` type carrying `expectedType`
  /// loads its target — transitively, so links inside resolved nodes are
  /// checked too — and reports mismatches at the link's path. A target
  /// that cannot be loaded produces an error rather than an exception;
  /// a `(target, expectedType)` pair is resolved once per call and cyclic
  /// links are validated once to guarantee termination.
  ///
  /// Throws [IPLDSchemaError] for malformed schema definitions.
  Future<SchemaValidationResult> checkAsync(
    String typeName,
    IPLDNode node, {
    IPLDLinkResolver? linkResolver,
  }) async {
    final resolver = linkResolver ?? _linkResolver;
    if (resolver == null) return check(typeName, node);
    final validator = _SchemaValidator(
      _schema,
      linkResolver: resolver,
      adlTypes: _adlTypes,
    );
    validator._validateType(node, _typeDef(typeName), typeName: typeName);
    while (validator._deferred.isNotEmpty) {
      final deferred = validator._deferred.removeAt(0);
      final relative = await deferred.run();
      if (relative.isEmpty) continue;
      final base = _describeSegments(deferred.path);
      for (final error in relative) {
        validator.errors.add(
          SchemaValidationError(
            path: _joinPaths(base, error.path),
            message: error.message,
          ),
        );
      }
    }
    return SchemaValidationResult(validator.errors);
  }

  /// Validates [node] against [typeName], throwing [IPLDSchemaError] with the
  /// first precise error path when the node does not match.
  ///
  /// Synchronous: never resolves links — see [check].
  void validateOrThrow(String typeName, IPLDNode node) {
    final result = check(typeName, node);
    if (!result.isValid) {
      throw IPLDSchemaError(
        'Node does not match type "$typeName": ${result.errors.first}',
      );
    }
  }

  /// As [validateOrThrow], but resolves link targets through [linkResolver]
  /// (or the constructor-supplied resolver) so `expectedType` clauses are
  /// enforced.
  Future<void> validateOrThrowAsync(
    String typeName,
    IPLDNode node, {
    IPLDLinkResolver? linkResolver,
  }) async {
    final result = await checkAsync(typeName, node, linkResolver: linkResolver);
    if (!result.isValid) {
      throw IPLDSchemaError(
        'Node does not match type "$typeName": ${result.errors.first}',
      );
    }
  }

  /// Adapts a `CID`-based node loader — e.g. `IPLDHandler.getNode`, the
  /// same block-fetch path used by selector execution — into an
  /// [IPLDLinkResolver]. Loader exceptions propagate and are reported as
  /// resolution failures at the link's path.
  static IPLDLinkResolver linkResolverFromNodeLoader(
    Future<IPLDNode?> Function(CID cid) loadNode,
  ) {
    return (link) => loadNode(
      CID.v1(link.codec, Multihash.decode(Uint8List.fromList(link.multihash))),
    );
  }

  /// Returns the type definition map for [typeName] or throws
  /// [IPLDSchemaError] when absent or not a map.
  Map<String, dynamic> _typeDef(String typeName) {
    final typeSchema = _schema[typeName];
    if (typeSchema == null) {
      throw IPLDSchemaError('Type not found in schema: $typeName');
    }
    if (typeSchema is! Map) {
      throw IPLDSchemaError('Schema for type "$typeName" must be a map');
    }
    return _asMap(typeSchema);
  }

  /// Rejects `representation` clauses that explicitly reference an ADL
  /// name declared neither in the schema's `advanced` block nor in
  /// [adlTypes] — a malformed schema, surfaced at construction time.
  void _lintAdvancedDeclarations() {
    final declared = <String>{};
    final block = _schema['advanced'];
    if (block != null) {
      if (block is! Map) {
        throw IPLDSchemaError('Schema "advanced" declarations must be a map');
      }
      declared.addAll(block.keys.map((key) => '$key'));
    }
    final external = _adlTypes;
    if (external != null) declared.addAll(external.keys);

    final seen = <Object>{};
    void walk(Object? value) {
      if (value is Map) {
        if (!seen.add(value)) return;
        final rep = value['representation'];
        if (rep is Map && rep.containsKey('advanced')) {
          final cfg = rep['advanced'];
          final ref = cfg is String
              ? cfg
              : cfg is Map && cfg['name'] is String
              ? cfg['name'] as String
              : null;
          if (ref != null && ref.isNotEmpty && !declared.contains(ref)) {
            throw IPLDSchemaError(
              'advanced representation references undeclared ADL "$ref"',
            );
          }
        }
        value.forEach((_, v) => walk(v));
      } else if (value is List) {
        for (final element in value) {
          walk(element);
        }
      }
    }

    walk(_schema);
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
  _SchemaValidator(
    this._schema, {
    IPLDLinkResolver? linkResolver,
    Map<String, Object?>? adlTypes,
  }) : _linkResolver = linkResolver,
       _adlTypes = adlTypes;

  final Map<String, dynamic> _schema;

  /// Resolver for link `expectedType` checks; null disables resolution.
  final IPLDLinkResolver? _linkResolver;

  /// Extra ADL registry (`{<adl>: <term-or-IPLDSchema>}`) consulted when the
  /// schema's own `advanced` block does not declare a name.
  final Map<String, Object?>? _adlTypes;

  /// Accumulated validation errors.
  final List<SchemaValidationError> errors = [];

  /// Current path segments: `String` for map keys, `int` for list indices.
  final List<Object> _path = [];

  /// Absolute path prefix under which deferred link checks are recorded.
  /// Empty at the document root; set to the link's path while a resolved
  /// link target is being validated so nested links queue with absolute
  /// paths while error paths stay relative to the target.
  List<Object> _pathPrefix = const [];

  /// Name of the type whose definition is currently being validated —
  /// used to derive the implicit ADL name for bare `advanced`
  /// representations (the type name is the ADL name). Null while inside
  /// anonymous inline definitions.
  String? _currentTypeName;

  /// Deferred checks that need `await` (link target resolution), in
  /// encounter order. Drained by [IPLDSchema.checkAsync].
  final List<_DeferredCheck> _deferred = [];

  /// Per-call cache of link target validations keyed by target identity and
  /// expected type; a `null` value marks an in-flight check so cyclic
  /// links terminate.
  final Map<String, List<SchemaValidationError>?> _linkResults = {};

  /// A map key exempt from struct unknown-key checks (inline union
  /// discriminant key).
  String? _allowedExtraKey;

  void _fail(String message) {
    errors.add(SchemaValidationError(path: _describePath(), message: message));
  }

  String _describePath() => _describeSegments(_path);

  /// The absolute path of the current node, including any enclosing
  /// resolved-link prefix.
  List<Object> _absolutePath() => [..._pathPrefix, ..._path];

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
  ///
  /// [typeName] is the schema name [def] was reached through, if any; it
  /// becomes the implicit ADL name for `advanced` representations. Inline
  /// definitions clear the name so a bare `advanced` repr cannot
  /// accidentally attribute the enclosing type's ADL.
  void _validateType(
    IPLDNode node,
    Map<String, dynamic> def, {
    String? typeName,
  }) {
    final savedName = _currentTypeName;
    _currentTypeName = typeName;
    try {
      _validateTypeBody(node, def);
    } finally {
      _currentTypeName = savedName;
    }
  }

  void _validateTypeBody(IPLDNode node, Map<String, dynamic> def) {
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
    _validateType(node, _resolveTerm(term), typeName: _termTypeName(term));
  }

  /// Returns the schema type name a term refers to, unwrapping
  /// `{type: ...}` wrappers, or null for anonymous/inline terms.
  String? _termTypeName(Object? term) {
    var t = term;
    while (t is Map && !t.containsKey('kind') && t.containsKey('type')) {
      t = t['type'];
    }
    if (t is String && _schema[t] is Map && t != 'advanced') return t;
    return null;
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
      _validateType(node, resolved, typeName: _termTypeName(ref));
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
    if (kind == 'link') {
      _checkLinkExpectedType(node, def);
      return;
    }
    if (def.containsKey('valueConstraint')) {
      _validateConstraint(node, def['valueConstraint']);
    }
  }

  // ---------------------------------------------------------------------
  // Links
  // ---------------------------------------------------------------------

  /// Queues an `expectedType` check for a link node. Without a resolver the
  /// link is only kind-checked, matching historical behavior.
  void _checkLinkExpectedType(IPLDNode node, Map<String, dynamic> def) {
    final expected = def['expectedType'];
    final resolver = _linkResolver;
    if (expected == null || resolver == null) return;
    final path = _absolutePath();
    final link = node.linkValue;
    _deferred.add(
      _DeferredCheck(path, () => _runLinkCheck(path, link, expected)),
    );
  }

  /// Resolves [link] and validates the target against [expectedType],
  /// returning errors with paths relative to the resolved node. Results are
  /// cached per `(target, expectedType)` pair so repeated links share the
  /// outcome and cyclic graphs terminate.
  Future<List<SchemaValidationError>> _runLinkCheck(
    List<Object> path,
    IPLDLink link,
    Object? expectedType,
  ) async {
    final key = _linkKey(link, expectedType);
    final cached = _linkResults[key];
    if (cached != null) return cached;
    if (_linkResults.containsKey(key)) {
      // The same pair is being validated further up the stack; treat this
      // edge as satisfied so cyclic links terminate. Errors, if any, are
      // already reported at the first occurrence's path.
      return const [];
    }
    _linkResults[key] = null;

    IPLDNode? target;
    try {
      target = await _linkResolver!(link);
    } catch (e) {
      return _linkResults[key] = [
        SchemaValidationError(
          path: 'value',
          message: 'link resolution failed: $e',
        ),
      ];
    }
    if (target == null) {
      return _linkResults[key] = const [
        SchemaValidationError(path: 'value', message: 'link target not found'),
      ];
    }

    // Validate the target with paths relative to it (clear `_path`), while
    // `_pathPrefix` keeps nested link checks anchored at the link's
    // absolute path.
    final savedPrefix = _pathPrefix;
    final savedPath = List<Object>.of(_path);
    _pathPrefix = path;
    _path.clear();
    final mark = errors.length;
    try {
      _validateTerm(target, expectedType);
    } finally {
      _pathPrefix = savedPrefix;
      _path
        ..clear()
        ..addAll(savedPath);
    }
    final relative = errors.sublist(mark);
    errors.length = mark;
    return _linkResults[key] = relative;
  }

  /// Cache key for a link target/expected-type pair.
  String _linkKey(IPLDLink link, Object? expectedType) {
    final typeKey = expectedType is String
        ? 'n:$expectedType'
        : 'i:${identityHashCode(expectedType)}';
    return '${link.codec}:${base64Encode(link.multihash)}|$typeKey';
  }

  // ---------------------------------------------------------------------
  // Advanced (ADL) representations
  // ---------------------------------------------------------------------

  /// Validates a node whose type uses an `advanced` representation.
  ///
  /// The ADL name comes from [cfg] (`representation: {advanced: <name>}`
  /// or `{advanced: {name: <name>}}`); when absent it defaults to the
  /// enclosing type's name, per the spec rule that the type name is the
  /// ADL name. A declared ADL validates the node against its registered
  /// term; an unknown ADL skips validation (spec leniency). An *explicit*
  /// reference to an undeclared name is a schema error — normally caught
  /// at construction by [IPLDSchema._lintAdvancedDeclarations].
  void _validateAdvancedRepr(IPLDNode node, Object? cfg) {
    String? adlName;
    var explicit = false;
    if (cfg is String && cfg.isNotEmpty) {
      adlName = cfg;
      explicit = true;
    } else if (cfg is Map) {
      final name = cfg['name'];
      if (name is String && name.isNotEmpty) {
        adlName = name;
        explicit = true;
      }
    }
    adlName ??= _currentTypeName;
    if (adlName == null) return;

    final (found, term) = _lookupAdl(adlName);
    if (!found) {
      // coverage:ignore-start
      if (explicit) {
        throw IPLDSchemaError(
          'advanced representation references undeclared ADL "$adlName"',
        );
      }
      // coverage:ignore-end
      return; // unknown ADL: no registered schema — skip validation
    }
    if (term == null) return; // declared without a node schema — skip
    if (term is IPLDSchema) {
      // A fully registered schema validates the node against its
      // ADL-named type.
      final result = term.check(adlName, node);
      final base = _describePath();
      for (final error in result.errors) {
        errors.add(
          SchemaValidationError(
            path: _joinPaths(base, error.path),
            message: 'ADL "$adlName": ${error.message}',
          ),
        );
      }
      return;
    }
    _validateTerm(node, term);
  }

  /// Looks up an ADL declaration: `(true, term)` when [name] is declared in
  /// the schema's `advanced` block or the [adlTypes] registry.
  (bool, Object?) _lookupAdl(String name) {
    final block = _schema['advanced'];
    if (block is Map && block.containsKey(name)) {
      return (true, block[name]);
    }
    final external = _adlTypes;
    if (external != null && external.containsKey(name)) {
      return (true, external[name]);
    }
    return (false, null);
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
    if (rep == 'advanced') {
      _validateAdvancedRepr(node, _reprValue(def, 'advanced'));
      return;
    }
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
        _validateAdvancedRepr(node, _reprValue(def, 'advanced'));
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
          optional:
              value['optional'] == true || optionalList.contains(fieldName),
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
          optional:
              inlineOptional ||
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
      _fail(
        'tuple has ${values.length} elements; at most '
        '${order.length} allowed',
      );
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
      _fail(
        'stringjoin expects ${order.length} fields joined by "$join"; '
        'found ${parts.length} parts',
      );
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
    final typed =
        def.containsKey('keyType') ||
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
        _validateAdvancedRepr(node, _reprValue(def, 'advanced'));
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
    final rep = _reprKind(def);
    if (rep != null && rep != 'list' && rep != 'advanced') {
      throw IPLDSchemaError('Unknown list representation: $rep');
    }
    // ADL representations define their own node shape, so the list kind
    // check must not run first.
    if (rep == 'advanced') {
      _validateAdvancedRepr(node, _reprValue(def, 'advanced'));
      return;
    }
    if (node.kind != Kind.LIST) {
      _fail('expected list, found ${_kindLabel(node.kind)}');
      return;
    }
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
          _fail(
            'expected enum int member, found ${_kindLabel(node.kind)}'
            '${node.kind == Kind.INTEGER ? ' ${node.intValue}' : ''}',
          );
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
      // Tentatively validate against the member on this validator so link
      // resolution and ADL settings apply; roll back errors and queued
      // link checks when the member does not match.
      final errorMark = errors.length;
      final deferredMark = _deferred.length;
      try {
        _validateTerm(node, entry.value);
      } on IPLDSchemaError {
        rethrow; // malformed member schema must surface
      }
      if (errors.length == errorMark) return;
      errors.length = errorMark;
      _deferred.length = deferredMark;
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
        _validateAdvancedRepr(node, cfgRaw);
      // coverage:ignore-start
      default:
        throw IPLDSchemaError('Unknown union representation: $strategy');
      // coverage:ignore-end
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
      _validateType(node, resolved, typeName: _termTypeName(term));
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
    final table = cfg.containsKey('table') ? _asMap(cfg['table']) : cfg;
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

  /// Returns the raw value under `representation.<kind>` (any shape:
  /// string, map, or null), or null when the representation is a bare
  /// string or the key is absent.
  Object? _reprValue(Map<String, dynamic> def, String kind) {
    final rep = def['representation'];
    if (rep is Map) return rep[kind];
    return null;
  }
}

/// A queued asynchronous check: [run] produces errors whose paths are
/// relative to the node at [path] (absolute segments, root = `[]`).
class _DeferredCheck {
  const _DeferredCheck(this.path, this.run);

  /// Absolute path segments of the node the deferred check applies to.
  final List<Object> path;

  /// Produces errors with paths relative to the checked node.
  final Future<List<SchemaValidationError>> Function() run;
}

/// Renders path segments (`String` map keys, `int` list indices) in the
/// `field "links".[2]."Hash"` form; an empty path renders as `value`.
String _describeSegments(List<Object> path) {
  if (path.isEmpty) return 'value';
  final buffer = StringBuffer('field ');
  var first = true;
  for (final segment in path) {
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

/// Joins a rendered [base] path with a rendered [sub] path relative to it.
String _joinPaths(String base, String sub) {
  if (sub == 'value') return base;
  if (base == 'value') return sub;
  return '$base.${sub.substring('field '.length)}';
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
