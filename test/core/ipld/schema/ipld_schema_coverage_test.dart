import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

void main() {
  group('IPLDSchema Coverage Tests', () {
    test('validate with type reference', () async {
      final schema = IPLDSchema('test', {
        'baseType': {'kind': 'string'},
        'refType': {'kind': 'type', 'valueType': 'baseType'},
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'test';

      final result = await schema.validate('refType', node);
      expect(result, isTrue);
    });

    test('validate with union type', () async {
      final schema = IPLDSchema('test', {
        'stringType': {'kind': 'string'},
        'intType': {'kind': 'int'},
        'unionType': {
          'kind': 'union',
          'representation': {
            'str': {'kind': 'type', 'valueType': 'stringType'},
            'num': {'kind': 'type', 'valueType': 'intType'},
          },
        },
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'test';

      final result = await schema.validate('unionType', node);
      expect(result, isTrue);
    });

    test('validate with struct type and required fields', () async {
      final schema = IPLDSchema('test', {
        'person': {
          'kind': 'struct',
          'fields': {
            'name': {'kind': 'string'},
            'age': {'kind': 'int'},
          },
          'required': ['name'],
        },
      });

      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = (IPLDMap()
          ..entries.addAll([
            MapEntry()
              ..key = 'name'
              ..value = (IPLDNode()
                ..kind = Kind.STRING
                ..stringValue = 'John'),
          ]));

      final result = await schema.validate('person', node);
      expect(result, isTrue);
    });

    test('validate with struct type missing required field returns false', () async {
      final schema = IPLDSchema('test', {
        'person': {
          'kind': 'struct',
          'fields': {
            'name': {'kind': 'string'},
            'age': {'kind': 'int'},
          },
          'required': ['name', 'age'],
        },
      });

      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = (IPLDMap()
          ..entries.add(
            MapEntry()
              ..key = 'name'
              ..value = (IPLDNode()
                ..kind = Kind.STRING
                ..stringValue = 'John'),
          ));

      final result = await schema.validate('person', node);
      expect(result, isFalse);
    });

    test('validate with integer constraint min/max', () async {
      final schema = IPLDSchema('test', {
        'boundedInt': {
          'kind': 'int',
          'valueConstraint': {'min': 0, 'max': 100},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(50);

      final result = await schema.validate('boundedInt', node);
      expect(result, isTrue);
    });

    test('validate with integer constraint below min returns false', () async {
      final schema = IPLDSchema('test', {
        'boundedInt': {
          'kind': 'int',
          'valueConstraint': {'min': 0, 'max': 100},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(-10);

      final result = await schema.validate('boundedInt', node);
      expect(result, isFalse);
    });

    test('validate with integer constraint above max returns false', () async {
      final schema = IPLDSchema('test', {
        'boundedInt': {
          'kind': 'int',
          'valueConstraint': {'min': 0, 'max': 100},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(150);

      final result = await schema.validate('boundedInt', node);
      expect(result, isFalse);
    });

    test('validate with string constraint pattern', () async {
      final schema = IPLDSchema('test', {
        'email': {
          'kind': 'string',
          'valueConstraint': {'pattern': r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'test@example.com';

      final result = await schema.validate('email', node);
      expect(result, isTrue);
    });

    test('validate with string constraint minLength', () async {
      final schema = IPLDSchema('test', {
        'shortString': {
          'kind': 'string',
          'valueConstraint': {'minLength': 3},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'abc';

      final result = await schema.validate('shortString', node);
      expect(result, isTrue);
    });

    test('validate with string constraint minLength violation returns false', () async {
      final schema = IPLDSchema('test', {
        'shortString': {
          'kind': 'string',
          'valueConstraint': {'minLength': 3},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'ab';

      final result = await schema.validate('shortString', node);
      expect(result, isFalse);
    });

    test('validate with string constraint maxLength', () async {
      final schema = IPLDSchema('test', {
        'longString': {
          'kind': 'string',
          'valueConstraint': {'maxLength': 10},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'hello';

      final result = await schema.validate('longString', node);
      expect(result, isTrue);
    });

    test('validate with string constraint maxLength violation returns false', () async {
      final schema = IPLDSchema('test', {
        'longString': {
          'kind': 'string',
          'valueConstraint': {'maxLength': 10},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'this is too long';

      final result = await schema.validate('longString', node);
      expect(result, isFalse);
    });

    test('validate with bytes constraint minLength', () async {
      final schema = IPLDSchema('test', {
        'bytesType': {
          'kind': 'bytes',
          'valueConstraint': {'minLength': 2},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = Uint8List.fromList([1, 2, 3]);

      final result = await schema.validate('bytesType', node);
      expect(result, isTrue);
    });

    test('validate with bytes constraint maxLength', () async {
      final schema = IPLDSchema('test', {
        'bytesType': {
          'kind': 'bytes',
          'valueConstraint': {'maxLength': 5},
        },
      });

      final node = IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = Uint8List.fromList([1, 2, 3]);

      final result = await schema.validate('bytesType', node);
      expect(result, isTrue);
    });

    test('validate with struct type and optional fields', () async {
      final schema = IPLDSchema('test', {
        'person': {
          'kind': 'struct',
          'fields': {
            'name': {'kind': 'string'},
            'age': {'kind': 'int'},
          },
          'required': ['name'],
          'optional': ['age'],
        },
      });

      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = (IPLDMap()
          ..entries.addAll([
            MapEntry()
              ..key = 'name'
              ..value = (IPLDNode()
                ..kind = Kind.STRING
                ..stringValue = 'John'),
            MapEntry()
              ..key = 'age'
              ..value = (IPLDNode()
                ..kind = Kind.INTEGER
                ..intValue = Int64(30)),
          ]));

      final result = await schema.validate('person', node);
      expect(result, isTrue);
    });

    test('validate with struct type and strict validation', () async {
      final schema = IPLDSchema('test', {
        'strictStruct': {
          'kind': 'struct',
          'fields': {
            'name': {'kind': 'string'},
          },
          'strict': true,
        },
      });

      final node = IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = (IPLDMap()
          ..entries.addAll([
            MapEntry()
              ..key = 'name'
              ..value = (IPLDNode()
                ..kind = Kind.STRING
                ..stringValue = 'John'),
            MapEntry()
              ..key = 'unknown'
              ..value = (IPLDNode()
                ..kind = Kind.STRING
                ..stringValue = 'value'),
          ]));

      final result = await schema.validate('strictStruct', node);
      expect(result, isFalse);
    });

    test('validate throws for unknown type', () async {
      final schema = IPLDSchema('test', {});
      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'test';

      expect(
        () => schema.validate('unknown', node),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('validate throws for missing kind in schema', () async {
      final schema = IPLDSchema('test', {
        'invalidType': {},
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'test';

      expect(
        () => schema.validate('invalidType', node),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('validate throws for unknown kind', () async {
      final schema = IPLDSchema('test', {
        'invalidType': {'kind': 'unknown_kind'},
      });

      final node = IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = 'test';

      expect(
        () => schema.validate('invalidType', node),
        throwsA(isA<IPLDSchemaError>()),
      );
    });
  });
}
