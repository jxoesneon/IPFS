import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('IPLDSchema', () {
    late IPLDSchema schema;

    setUp(() {
      final schemaMap = {
        'MyStruct': {
          'kind': 'struct',
          'fields': {
            'name': {
              'kind': 'string',
              'valueConstraint': {'minLength': 2},
            },
            'age': {
              'kind': 'int',
              'valueConstraint': {'min': 0, 'max': 150},
            },
            'tags': {
              'kind': 'list',
              'valueType': 'string',
            }, // Note: list handling in code might be missing?
          },
          'required': ['name', 'age'],
        },
        'MyInt': {
          'kind': 'int',
          'valueConstraint': {'min': 10},
        },
        'MyUnion': {
          'kind': 'union',
          'representation': {
            't1': {'kind': 'int'},
            't2': {'kind': 'string'},
          },
        },
      };
      schema = IPLDSchema('TestSchema', schemaMap);
    });

    test('validates valid struct', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap()
        ..mapValue.entries.addAll([
          MapEntry()
            ..key = 'name'
            ..value = (IPLDNode()
              ..kind = Kind.STRING
              ..stringValue = 'Alice'),
          MapEntry()
            ..key = 'age'
            ..value = (IPLDNode()
              ..kind = Kind.INTEGER
              ..intValue = Int64(30)),
        ]);

      expect(await schema.validate('MyStruct', node), isTrue);
    });

    test('validates struct missing required field', () async {
      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = IPLDMap()
        ..mapValue.entries.addAll([
          MapEntry()
            ..key = 'name'
            ..value = (IPLDNode()
              ..kind = Kind.STRING
              ..stringValue = 'Alice'),
        ]); // Missing age

      expect(await schema.validate('MyStruct', node), isFalse);
    });

    test('validates int constraint', () async {
      final valid = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(20);
      final invalid = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(5);

      expect(await schema.validate('MyInt', valid), isTrue);
      expect(await schema.validate('MyInt', invalid), isFalse);
    });

    test('validates string constraint (minLength)', () async {
      // Defined in MyStruct -> name
      // But I need to pass the field node directly relative to 'MyStruct' schema?
      // No, validate takes typeName.

      // Create simple String type
      final customSchema = IPLDSchema('StringSchema', {
        'MyStr': {
          'kind': 'string',
          'valueConstraint': {'minLength': 3},
        },
      });

      final valid = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'abc';
      final invalid = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'ab';

      expect(await customSchema.validate('MyStr', valid), isTrue);
      expect(await customSchema.validate('MyStr', invalid), isFalse);
    });

    test('throws on unknown type', () async {
      final node = IPLDNode()..kind = Kind.NULL;
      expect(() => schema.validate('UnknownType', node), throwsA(isA<IPLDSchemaError>()));
    });
  });
}
