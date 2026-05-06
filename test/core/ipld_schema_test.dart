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
      expect(
        () => schema.validate('UnknownType', node),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('union accepts any matching representation', () async {
      final asInt = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(1);
      final asStr = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'x';
      final asBool = IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = true;
      expect(await schema.validate('MyUnion', asInt), isTrue);
      expect(await schema.validate('MyUnion', asStr), isTrue);
      expect(await schema.validate('MyUnion', asBool), isFalse);
    });

    test('basic-type schemas reject mismatched kinds', () async {
      final s = IPLDSchema('Basics', {
        'Bool': {'kind': 'bool'},
        'Bytes': {
          'kind': 'bytes',
          'valueConstraint': {'minLength': 2, 'maxLength': 4},
        },
      });
      final boolNode = IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = false;
      expect(await s.validate('Bool', boolNode), isTrue);
      final wrong = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'no';
      expect(await s.validate('Bool', wrong), isFalse);

      final bytesOk = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = [1, 2, 3];
      final bytesShort = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = [1];
      final bytesLong = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = [1, 2, 3, 4, 5];
      expect(await s.validate('Bytes', bytesOk), isTrue);
      expect(await s.validate('Bytes', bytesShort), isFalse);
      expect(await s.validate('Bytes', bytesLong), isFalse);
    });

    test('string schemas honour pattern and maxLength', () async {
      final s = IPLDSchema('Strings', {
        'Hex': {
          'kind': 'string',
          'valueConstraint': {'pattern': r'^[0-9a-f]+$'},
        },
        'Bounded': {
          'kind': 'string',
          'valueConstraint': {'maxLength': 3},
        },
      });
      final ok = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'abc';
      final notHex = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'ZZZ';
      final tooLong = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'abcd';
      expect(await s.validate('Hex', ok), isTrue);
      expect(await s.validate('Hex', notHex), isFalse);
      expect(await s.validate('Bounded', tooLong), isFalse);
    });

    test('throws when schema kind is unknown', () async {
      final s = IPLDSchema('Bad', {
        'Bad': {'kind': 'mystery'},
      });
      final node = IPLDNode()..kind = Kind.NULL;
      expect(() => s.validate('Bad', node), throwsA(isA<IPLDSchemaError>()));
    });
  });
}
