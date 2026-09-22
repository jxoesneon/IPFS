// test/core/ipld/schema/ipld_schema_repr_coverage_test.dart
//
// Coverage tests for schema representation strategies, map key types,
// union edge cases, and malformed-schema error branches in
// lib/src/core/ipld/schema/ipld_schema.dart.

import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  IPLDNode strNode(String v) => IPLDNode()
    ..kind = Kind.STRING
    ..stringValue = v;
  IPLDNode intNode(int v) => IPLDNode()
    ..kind = Kind.INTEGER
    ..intValue = Int64(v);
  IPLDNode floatNode(double v) => IPLDNode()
    ..kind = Kind.FLOAT
    ..floatValue = v;
  IPLDNode boolNode(bool v) => IPLDNode()
    ..kind = Kind.BOOL
    ..boolValue = v;
  IPLDNode nullNode() => IPLDNode()..kind = Kind.NULL;
  IPLDNode bytesNode(List<int> v) => IPLDNode()
    ..kind = Kind.BYTES
    ..bytesValue = v;
  IPLDNode listNode(List<IPLDNode> values) => IPLDNode()
    ..kind = Kind.LIST
    ..listValue = (IPLDList()..values.addAll(values));
  IPLDNode mapNode(Map<String, IPLDNode> entries) {
    final map = IPLDMap();
    for (final e in entries.entries) {
      map.entries.add(
        MapEntry()
          ..key = e.key
          ..value = e.value,
      );
    }
    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = map;
  }

  bool valid(Map<String, dynamic> schema, String type, IPLDNode node) =>
      IPLDSchema('t', schema).check(type, node).isValid;

  void expectSchemaThrows(
    Map<String, dynamic> schema,
    String type,
    IPLDNode node,
  ) {
    expect(
      () => IPLDSchema('t', schema).check(type, node),
      throwsA(isA<IPLDSchemaError>()),
    );
  }

  group('type declaration and term resolution', () {
    test('check rejects non-map type declarations', () {
      final schema = IPLDSchema('t', {'T': 'oops'});
      expect(
        () => schema.check('T', strNode('x')),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('type declarations may alias through a bare "type" key', () {
      final schema = <String, dynamic>{
        'T': {'type': 'string'},
      };
      expect(valid(schema, 'T', strNode('x')), isTrue);
      expect(valid(schema, 'T', intNode(1)), isFalse);
    });

    test('type terms may nest a "type" key inside a map', () {
      final schema = <String, dynamic>{
        'L': {
          'kind': 'list',
          'valueType': {'type': 'int'},
        },
      };
      expect(valid(schema, 'L', listNode([intNode(1)])), isTrue);
      expect(valid(schema, 'L', listNode([strNode('x')])), isFalse);
    });

    test('invalid (non-string, non-map) type terms throw', () {
      final schema = <String, dynamic>{
        'L': {'kind': 'list', 'valueType': 42},
      };
      expectSchemaThrows(schema, 'L', listNode([intNode(1)]));
    });

    test('type/copy references require valueType', () {
      expectSchemaThrows(
        <String, dynamic>{
          'T': {'kind': 'type'},
        },
        'T',
        strNode('x'),
      );
      expectSchemaThrows(
        <String, dynamic>{
          'T': {'kind': 'copy'},
        },
        'T',
        strNode('x'),
      );
    });
  });

  group('scalar valueConstraint on floats', () {
    final schema = <String, dynamic>{
      'F': {
        'kind': 'float',
        'valueConstraint': {'min': 0.5, 'max': 2.5},
      },
    };

    test('accepts values inside the range', () {
      expect(valid(schema, 'F', floatNode(1.5)), isTrue);
    });

    test('rejects values below the minimum', () {
      expect(valid(schema, 'F', floatNode(0.1)), isFalse);
    });

    test('rejects values above the maximum', () {
      expect(valid(schema, 'F', floatNode(9.9)), isFalse);
    });

    test('string pattern violations fail', () {
      final stringSchema = <String, dynamic>{
        'S': {
          'kind': 'string',
          'valueConstraint': {'pattern': r'^a+$'},
        },
      };
      expect(valid(stringSchema, 'S', strNode('aaa')), isTrue);
      expect(valid(stringSchema, 'S', strNode('bbb')), isFalse);
    });

    test('bytes length violations fail', () {
      final bytesSchema = <String, dynamic>{
        'B': {
          'kind': 'bytes',
          'valueConstraint': {'minLength': 2, 'maxLength': 4},
        },
      };
      expect(valid(bytesSchema, 'B', bytesNode([1])), isFalse);
      expect(valid(bytesSchema, 'B', bytesNode([1, 2, 3, 4, 5])), isFalse);
      expect(valid(bytesSchema, 'B', bytesNode([1, 2])), isTrue);
    });
  });

  group('unit representation modes', () {
    test('explicit null representation rejects non-null nodes', () {
      final schema = <String, dynamic>{
        'U': {'kind': 'unit', 'representation': 'null'},
      };
      expect(valid(schema, 'U', nullNode()), isTrue);
      expect(valid(schema, 'U', strNode('x')), isFalse);
    });

    test('advanced representation accepts any node', () {
      final schema = <String, dynamic>{
        'U': {'kind': 'unit', 'representation': 'advanced'},
      };
      expect(valid(schema, 'U', strNode('x')), isTrue);
    });

    Map<String, dynamic> unitSchema(String mode) => <String, dynamic>{
      'U': {
        'kind': 'unit',
        'representation': {
          'unit': {'representation': mode},
        },
      },
    };

    test('emptymap mode requires an empty map', () {
      final schema = unitSchema('emptymap');
      expect(valid(schema, 'U', mapNode({})), isTrue);
      expect(valid(schema, 'U', mapNode({'a': strNode('x')})), isFalse);
      expect(valid(schema, 'U', nullNode()), isFalse);
    });

    test('true mode requires the boolean true', () {
      final schema = unitSchema('true');
      expect(valid(schema, 'U', boolNode(true)), isTrue);
      expect(valid(schema, 'U', boolNode(false)), isFalse);
      expect(valid(schema, 'U', intNode(1)), isFalse);
    });

    test('false mode requires the boolean false', () {
      final schema = unitSchema('false');
      expect(valid(schema, 'U', boolNode(false)), isTrue);
      expect(valid(schema, 'U', boolNode(true)), isFalse);
    });

    test('0 and 1 modes require the matching integer', () {
      expect(valid(unitSchema('0'), 'U', intNode(0)), isTrue);
      expect(valid(unitSchema('0'), 'U', intNode(1)), isFalse);
      expect(valid(unitSchema('1'), 'U', intNode(1)), isTrue);
      expect(valid(unitSchema('1'), 'U', intNode(0)), isFalse);
      expect(valid(unitSchema('1'), 'U', strNode('1')), isFalse);
    });

    test('null mode through the nested unit config', () {
      final schema = unitSchema('null');
      expect(valid(schema, 'U', nullNode()), isTrue);
      expect(valid(schema, 'U', boolNode(true)), isFalse);
    });

    test('unknown unit modes throw', () {
      expectSchemaThrows(unitSchema('bogus'), 'U', strNode('x'));
    });
  });

  group('struct representation edge cases', () {
    test('advanced representation accepts any node', () {
      final schema = <String, dynamic>{
        'S': {'kind': 'struct', 'representation': 'advanced'},
      };
      expect(valid(schema, 'S', strNode('x')), isTrue);
    });

    test('unknown struct representation throws', () {
      final schema = <String, dynamic>{
        'S': {'kind': 'struct', 'representation': 'bogus'},
      };
      expectSchemaThrows(schema, 'S', mapNode({}));
    });

    test('struct fields must be a map', () {
      final schema = <String, dynamic>{
        'S': {'kind': 'struct', 'fields': 'nope'},
      };
      expectSchemaThrows(schema, 'S', mapNode({}));
    });

    test('required/optional declarations must be lists', () {
      final schema = <String, dynamic>{
        'S': {'kind': 'struct', 'fields': <String, dynamic>{}, 'required': 42},
      };
      expectSchemaThrows(schema, 'S', mapNode({}));
    });
  });

  group('tuple struct representation', () {
    test('rejects non-list nodes', () {
      final schema = <String, dynamic>{
        'S': {
          'kind': 'struct',
          'fields': {'a': 'string'},
          'representation': 'tuple',
        },
      };
      expect(valid(schema, 'S', mapNode({'a': strNode('x')})), isFalse);
      expect(valid(schema, 'S', listNode([strNode('x')])), isTrue);
    });

    test('fieldOrder entries must reference declared fields', () {
      final schema = <String, dynamic>{
        'S': {
          'kind': 'struct',
          'fields': {'a': 'string'},
          'representation': {
            'tuple': {
              'fieldOrder': ['a', 'ghost'],
            },
          },
        },
      };
      expectSchemaThrows(schema, 'S', listNode([strNode('x')]));
    });
  });

  group('stringjoin struct representation', () {
    test('fieldOrder entries must reference declared fields', () {
      final schema = <String, dynamic>{
        'S': {
          'kind': 'struct',
          'fields': {'a': 'string'},
          'representation': {
            'stringjoin': {
              'join': ':',
              'fieldOrder': ['a', 'ghost'],
            },
          },
        },
      };
      expectSchemaThrows(schema, 'S', strNode('x:y'));
    });

    test('parses bool and float fields', () {
      final schema = <String, dynamic>{
        'S': {
          'kind': 'struct',
          'fields': {'b': 'bool', 'f': 'float'},
          'representation': {
            'stringjoin': {
              'join': ':',
              'fieldOrder': ['b', 'f'],
            },
          },
        },
      };
      expect(valid(schema, 'S', strNode('true:1.5')), isTrue);
      expect(valid(schema, 'S', strNode('false:0.25')), isTrue);
      expect(valid(schema, 'S', strNode('maybe:1.5')), isFalse);
      expect(valid(schema, 'S', strNode('true:nope')), isFalse);
    });

    test('enum fields parse through their representation', () {
      final schema = <String, dynamic>{
        'E': {
          'kind': 'enum',
          'members': ['x', 'y'],
          'representation': {
            'int': {'x': 0, 'y': 1},
          },
        },
        'S': {
          'kind': 'struct',
          'fields': {'e': 'E', 's': 'string'},
          'representation': {
            'stringjoin': {
              'join': '-',
              'fieldOrder': ['e', 's'],
            },
          },
        },
      };
      expect(valid(schema, 'S', strNode('0-ok')), isTrue);
      expect(valid(schema, 'S', strNode('9-ok')), isFalse);
    });

    test('aliased field types resolve before parsing', () {
      final schema = <String, dynamic>{
        'Alias': {'kind': 'int'},
        'S': {
          'kind': 'struct',
          'fields': {
            'a': {'kind': 'type', 'valueType': 'Alias'},
          },
          'representation': {
            'stringjoin': {
              'join': ':',
              'fieldOrder': ['a'],
            },
          },
        },
      };
      expect(valid(schema, 'S', strNode('42')), isTrue);
      expect(valid(schema, 'S', strNode('x')), isFalse);
    });

    test('fields without a string-parseable representation throw', () {
      final copySchema = <String, dynamic>{
        'S': {
          'kind': 'struct',
          'fields': {
            'a': {'kind': 'copy'},
          },
          'representation': {
            'stringjoin': {
              'join': ':',
              'fieldOrder': ['a'],
            },
          },
        },
      };
      expectSchemaThrows(copySchema, 'S', strNode('x'));

      final mapFieldSchema = <String, dynamic>{
        'S': {
          'kind': 'struct',
          'fields': {
            'a': {'kind': 'map'},
          },
          'representation': {
            'stringjoin': {
              'join': ':',
              'fieldOrder': ['a'],
            },
          },
        },
      };
      expectSchemaThrows(mapFieldSchema, 'S', strNode('x'));
    });
  });

  group('stringpairs struct representation', () {
    Map<String, dynamic> schema() => <String, dynamic>{
      'S': {
        'kind': 'struct',
        'fields': {'a': 'string', 'b': 'string'},
        'representation': 'stringpairs',
      },
    };

    test('rejects non-string nodes', () {
      expect(valid(schema(), 'S', mapNode({})), isFalse);
    });

    test('rejects malformed entries without the inner delimiter', () {
      expect(valid(schema(), 'S', strNode('a=1&badentry')), isFalse);
    });

    test('rejects duplicate fields', () {
      expect(valid(schema(), 'S', strNode('a=1&a=2')), isFalse);
    });

    test('rejects unknown fields', () {
      expect(valid(schema(), 'S', strNode('zzz=1')), isFalse);
    });

    test('reports missing required fields', () {
      final required = <String, dynamic>{
        'S': {
          'kind': 'struct',
          'fields': {'a': 'string', 'b': 'string'},
          'required': ['a', 'b'],
          'representation': 'stringpairs',
        },
      };
      expect(valid(required, 'S', strNode('a=1')), isFalse);
      expect(valid(required, 'S', strNode('a=1&b=2')), isTrue);
    });
  });

  group('listpairs struct representation', () {
    Map<String, dynamic> schema() => <String, dynamic>{
      'S': {
        'kind': 'struct',
        'fields': {'a': 'string'},
        'representation': 'listpairs',
      },
    };

    IPLDNode pair(IPLDNode k, IPLDNode v) => listNode([k, v]);

    test('rejects non-list nodes', () {
      expect(valid(schema(), 'S', strNode('x')), isFalse);
    });

    test('rejects entries that are not two-element lists', () {
      expect(valid(schema(), 'S', listNode([strNode('x')])), isFalse);
      expect(
        valid(
          schema(),
          'S',
          listNode([
            listNode([strNode('a'), strNode('v'), strNode('extra')]),
          ]),
        ),
        isFalse,
      );
    });

    test('rejects non-string keys', () {
      expect(
        valid(schema(), 'S', listNode([pair(intNode(1), strNode('v'))])),
        isFalse,
      );
    });

    test('rejects unknown and duplicate fields', () {
      expect(
        valid(schema(), 'S', listNode([pair(strNode('zzz'), strNode('v'))])),
        isFalse,
      );
      expect(
        valid(
          schema(),
          'S',
          listNode([
            pair(strNode('a'), strNode('v')),
            pair(strNode('a'), strNode('w')),
          ]),
        ),
        isFalse,
      );
    });

    test('validates pair values against the field type', () {
      expect(
        valid(schema(), 'S', listNode([pair(strNode('a'), strNode('v'))])),
        isTrue,
      );
      expect(
        valid(schema(), 'S', listNode([pair(strNode('a'), intNode(1))])),
        isFalse,
      );
    });
  });

  group('map representations', () {
    test('explicit map representation still checks the kind', () {
      final schema = <String, dynamic>{
        'M': {'kind': 'map', 'representation': 'map'},
      };
      expect(valid(schema, 'M', mapNode({})), isTrue);
      expect(valid(schema, 'M', strNode('x')), isFalse);
    });

    test('advanced representation accepts any node', () {
      final schema = <String, dynamic>{
        'M': {'kind': 'map', 'representation': 'advanced'},
      };
      expect(valid(schema, 'M', strNode('x')), isTrue);
    });

    test('unknown map representation throws', () {
      final schema = <String, dynamic>{
        'M': {'kind': 'map', 'representation': 'bogus'},
      };
      expectSchemaThrows(schema, 'M', mapNode({}));
    });

    test('typed maps require a map node', () {
      final schema = <String, dynamic>{
        'M': {'kind': 'map', 'valueType': 'int'},
      };
      expect(valid(schema, 'M', strNode('x')), isFalse);
      expect(valid(schema, 'M', mapNode({'k': intNode(1)})), isTrue);
    });
  });

  group('listpairs map representation', () {
    Map<String, dynamic> schema({bool valueNullable = false}) =>
        <String, dynamic>{
          'M': {
            'kind': 'map',
            'valueType': 'int',
            'valueNullable': valueNullable,
            'representation': 'listpairs',
          },
        };

    test('rejects non-list nodes', () {
      expect(valid(schema(), 'M', mapNode({})), isFalse);
    });

    test('rejects malformed pairs and non-string keys', () {
      expect(valid(schema(), 'M', listNode([strNode('x')])), isFalse);
      expect(
        valid(
          schema(),
          'M',
          listNode([
            listNode([intNode(1), intNode(2)]),
          ]),
        ),
        isFalse,
      );
    });

    test('rejects null values unless valueNullable', () {
      final pair = listNode([strNode('k'), nullNode()]);
      expect(valid(schema(), 'M', listNode([pair])), isFalse);
      expect(valid(schema(valueNullable: true), 'M', listNode([pair])), isTrue);
    });

    test('validates pair values against valueType', () {
      expect(
        valid(
          schema(),
          'M',
          listNode([
            listNode([strNode('k'), intNode(2)]),
          ]),
        ),
        isTrue,
      );
      expect(
        valid(
          schema(),
          'M',
          listNode([
            listNode([strNode('k'), strNode('v')]),
          ]),
        ),
        isFalse,
      );
    });
  });

  group('stringpairs map representation', () {
    Map<String, dynamic> schema({Object? valueType = 'int'}) =>
        <String, dynamic>{
          'M': {
            'kind': 'map',
            'valueType': valueType,
            'representation': 'stringpairs',
          },
        };

    test('rejects non-string nodes', () {
      expect(valid(schema(), 'M', mapNode({})), isFalse);
    });

    test('accepts empty strings and valid entries', () {
      expect(valid(schema(), 'M', strNode('')), isTrue);
      expect(valid(schema(), 'M', strNode('k=5')), isTrue);
    });

    test('rejects malformed entries and unparseable values', () {
      expect(valid(schema(), 'M', strNode('badentry')), isFalse);
      expect(valid(schema(), 'M', strNode('k=x')), isFalse);
    });

    test('valueType must have a string-parseable representation', () {
      expectSchemaThrows(
        schema(valueType: {'kind': 'list'}),
        'M',
        strNode('k=v'),
      );
    });
  });

  group('map keyType validation', () {
    IPLDSchema schemaFor(Object? keyType) => IPLDSchema('t', <String, dynamic>{
      'M': {'kind': 'map', 'keyType': keyType, 'valueType': 'int'},
    });

    bool keyValid(Object? keyType, String key) =>
        schemaFor(keyType).check('M', mapNode({key: intNode(1)})).isValid;

    test('string and any keyTypes accept all keys', () {
      expect(keyValid('string', 'anything'), isTrue);
      expect(keyValid('any', 'anything'), isTrue);
    });

    test('int keyType parses keys', () {
      expect(keyValid('int', '5'), isTrue);
      expect(keyValid('int', '-7'), isTrue);
      expect(keyValid('int', 'abc'), isFalse);
    });

    test('enum keyType checks membership', () {
      final keyType = <String, dynamic>{
        'kind': 'enum',
        'members': ['red', 'green'],
      };
      expect(keyValid(keyType, 'red'), isTrue);
      expect(keyValid(keyType, 'blue'), isFalse);
    });

    test('enum keyType without members throws', () {
      expect(
        () => schemaFor(<String, dynamic>{
          'kind': 'enum',
        }).check('M', mapNode({'a': intNode(1)})),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('enum keyType with int representation parses int keys', () {
      final keyType = <String, dynamic>{
        'kind': 'enum',
        'members': ['a'],
        'representation': {
          'int': {'a': 0},
        },
      };
      expect(keyValid(keyType, '0'), isTrue);
      expect(keyValid(keyType, 'x'), isFalse);
    });

    test('type/copy keyTypes recurse into the referenced type', () {
      expect(
        keyValid(<String, dynamic>{'kind': 'type', 'valueType': 'int'}, '5'),
        isTrue,
      );
      expect(
        keyValid(<String, dynamic>{'kind': 'type', 'valueType': 'int'}, 'x'),
        isFalse,
      );
    });

    test('type/copy keyTypes without a reference throw', () {
      expect(
        () => schemaFor(<String, dynamic>{
          'kind': 'copy',
        }).check('M', mapNode({'a': intNode(1)})),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('unsupported keyType kinds throw', () {
      expect(
        () => schemaFor(<String, dynamic>{
          'kind': 'list',
        }).check('M', mapNode({'a': intNode(1)})),
        throwsA(isA<IPLDSchemaError>()),
      );
    });
  });

  group('list representation edge cases', () {
    test('unknown list representation throws', () {
      final schema = <String, dynamic>{
        'L': {'kind': 'list', 'representation': 'bogus'},
      };
      expectSchemaThrows(schema, 'L', listNode([]));
    });

    test('advanced representation accepts any list', () {
      final schema = <String, dynamic>{
        'L': {'kind': 'list', 'representation': 'advanced'},
      };
      expect(valid(schema, 'L', listNode([])), isTrue);
    });
  });

  group('enum edge cases', () {
    test('enum without members throws', () {
      final schema = <String, dynamic>{
        'E': {'kind': 'enum'},
      };
      expectSchemaThrows(schema, 'E', strNode('a'));
    });

    test('unknown enum representation throws', () {
      final schema = <String, dynamic>{
        'E': {
          'kind': 'enum',
          'members': ['a'],
          'representation': 'bogus',
        },
      };
      expectSchemaThrows(schema, 'E', strNode('a'));
    });
  });

  group('union dispatch and legacy forms', () {
    test('bare-string representation dispatches to the strategy', () {
      final kinded = <String, dynamic>{
        'U': {'kind': 'union', 'representation': 'kinded'},
      };
      // kinded without a table is a malformed schema.
      expectSchemaThrows(kinded, 'U', strNode('x'));

      final advanced = <String, dynamic>{
        'U': {'kind': 'union', 'representation': 'advanced'},
      };
      expect(valid(advanced, 'U', strNode('x')), isTrue);
    });

    test('legacy unions surface malformed member schemas', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {'x': 'MissingType'},
        },
      };
      expectSchemaThrows(schema, 'U', strNode('v'));
    });
  });

  group('envelope unions', () {
    Map<String, dynamic> schema() => <String, dynamic>{
      'U': {
        'kind': 'union',
        'representation': {
          'envelope': {
            'discriminantKey': 'tag',
            'table': {'a': 'string'},
          },
        },
      },
    };

    test('requires discriminantKey and table', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {'envelope': <String, dynamic>{}},
        },
      };
      expectSchemaThrows(schema, 'U', mapNode({}));
    });

    test('requires a map node', () {
      expect(valid(schema(), 'U', strNode('x')), isFalse);
    });

    test('requires a string discriminant entry', () {
      expect(valid(schema(), 'U', mapNode({'other': strNode('v')})), isFalse);
      expect(valid(schema(), 'U', mapNode({'tag': intNode(1)})), isFalse);
    });

    test('rejects extra keys and content keyed by unknown tags', () {
      expect(
        valid(
          schema(),
          'U',
          mapNode({'tag': strNode('a'), 'extra': strNode('v')}),
        ),
        isFalse,
      );
      expect(
        valid(
          schema(),
          'U',
          mapNode({'tag': strNode('zzz'), 'zzz': strNode('v')}),
        ),
        isFalse,
      );
    });

    test('accepts discriminant plus tag-keyed content', () {
      expect(
        valid(schema(), 'U', mapNode({'tag': strNode('a'), 'a': strNode('v')})),
        isTrue,
      );
    });

    test('the "enveloped" alias is accepted', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {
            'enveloped': {
              'discriminantKey': 'tag',
              'table': {'a': 'string'},
            },
          },
        },
      };
      expect(
        valid(schema, 'U', mapNode({'tag': strNode('a'), 'a': strNode('v')})),
        isTrue,
      );
    });
  });

  group('inline unions', () {
    Map<String, dynamic> schema() => <String, dynamic>{
      'S': {
        'kind': 'struct',
        'fields': {
          'x': {'type': 'int'},
        },
      },
      'U': {
        'kind': 'union',
        'representation': {
          'inline': {
            'discriminantKey': 'tag',
            'table': {'a': 'S'},
          },
        },
      },
    };

    test('requires discriminantKey and table', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {'inline': <String, dynamic>{}},
        },
      };
      expectSchemaThrows(schema, 'U', mapNode({}));
    });

    test('requires a map node', () {
      expect(valid(schema(), 'U', strNode('x')), isFalse);
    });

    test('requires a string discriminant entry', () {
      expect(valid(schema(), 'U', mapNode({'x': intNode(1)})), isFalse);
    });

    test('rejects tags missing from the table', () {
      expect(valid(schema(), 'U', mapNode({'tag': strNode('ghost')})), isFalse);
    });
  });

  group('stringprefix unions', () {
    test('dispatches on the longest matching prefix', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {
            'stringprefix': {'delim': '-', 'b': 'int', 'aa': 'string'},
          },
        },
      };
      expect(valid(schema, 'U', strNode('aa-zzz')), isTrue);
      expect(valid(schema, 'U', strNode('b-7')), isFalse);
      expect(valid(schema, 'U', strNode('zzz')), isFalse);
      expect(valid(schema, 'U', intNode(3)), isFalse);
    });

    test('requires a non-empty table', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {
            'stringprefix': {'delim': '-'},
          },
        },
      };
      expectSchemaThrows(schema, 'U', strNode('a-1'));
    });

    test('explicit tables must be maps', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {
            'stringprefix': {'table': 'nope'},
          },
        },
      };
      expectSchemaThrows(schema, 'U', strNode('a-1'));
    });
  });

  group('bytesprefix unions', () {
    test('strips the leading byte and validates the rest', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {
            'bytesprefix': {'0': 'bytes', '1': 'bytes'},
          },
        },
      };
      expect(valid(schema, 'U', bytesNode([0, 9, 9])), isTrue);
      expect(valid(schema, 'U', bytesNode([7, 9])), isFalse);
      expect(valid(schema, 'U', bytesNode([])), isFalse);
      expect(valid(schema, 'U', strNode('x')), isFalse);
    });

    test('requires a non-empty table', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {'bytesprefix': <String, dynamic>{}},
        },
      };
      expectSchemaThrows(schema, 'U', bytesNode([0]));
    });

    test('the "byteprefix" alias accepts int-keyed tables', () {
      final schema = <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {
            'byteprefix': {
              'table': {1: 'bytes'},
            },
          },
        },
      };
      expect(valid(schema, 'U', bytesNode([1, 2, 3])), isTrue);
      expect(valid(schema, 'U', bytesNode([2, 3])), isFalse);
    });
  });

  group('representation clause helpers', () {
    test('representation must be a string or map', () {
      final schema = <String, dynamic>{
        'S': {'kind': 'struct', 'representation': 42},
      };
      expectSchemaThrows(schema, 'S', mapNode({}));
    });
  });
}
