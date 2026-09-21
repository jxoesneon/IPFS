import 'dart:typed_data';

import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

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
IPLDNode bytesNode(List<int> v) => IPLDNode()
  ..kind = Kind.BYTES
  ..bytesValue = v;
IPLDNode nullNode() => IPLDNode()..kind = Kind.NULL;
IPLDNode linkNode() => IPLDNode()
  ..kind = Kind.LINK
  ..linkValue = (IPLDLink()
    ..version = 1
    ..codec = 'dag-cbor'
    ..multihash = Uint8List.fromList([0x12, 0x20]));
IPLDNode listNode(List<IPLDNode> values) => IPLDNode()
  ..kind = Kind.LIST
  ..listValue = (IPLDList()..values.addAll(values));
IPLDNode mapNode(Map<String, IPLDNode> entries) => IPLDNode()
  ..kind = Kind.MAP
  ..mapValue = (IPLDMap()
    ..entries.addAll(
      entries.entries.map(
        (e) => MapEntry()
          ..key = e.key
          ..value = e.value,
      ),
    ));
IPLDNode pairNode(String key, IPLDNode value) =>
    listNode([strNode(key), value]);

void main() {
  group('spec-style struct validation', () {
    final schema = IPLDSchema('spec', {
      'Person': {
        'kind': 'struct',
        'fields': {
          'name': {'type': 'String'},
          'age': {'type': 'Int', 'optional': true},
          'nick': {'type': 'String', 'optional': true, 'nullable': true},
        },
        'representation': {'map': <String, dynamic>{}},
      },
    });

    test('accepts valid node with optional fields absent', () async {
      final node = mapNode({'name': strNode('Ada')});
      expect(await schema.validate('Person', node), isTrue);
    });

    test('accepts nullable field set to null', () async {
      final node = mapNode({'name': strNode('Ada'), 'nick': nullNode()});
      expect(await schema.validate('Person', node), isTrue);
    });

    test('rejects missing required field with precise path', () {
      final result = schema.check('Person', mapNode({}));
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, 'field "name"');
      expect(result.errors.single.message, contains('missing required'));
    });

    test('rejects non-nullable field set to null', () {
      final result = schema.check(
        'Person',
        mapNode({'name': nullNode()}),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, 'field "name"');
      expect(result.errors.single.message, contains('not nullable'));
    });

    test('rejects unknown keys in map representation', () {
      final result = schema.check(
        'Person',
        mapNode({'name': strNode('Ada'), 'extra': strNode('x')}),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, 'field "extra"');
      expect(result.errors.single.message, contains('unknown field'));
    });

    test('rejects struct when node is not a map', () async {
      expect(await schema.validate('Person', strNode('nope')), isFalse);
    });

    test('rejects field value of wrong type', () async {
      final node = mapNode({'name': intNode(3)});
      expect(await schema.validate('Person', node), isFalse);
    });
  });

  group('precise error paths', () {
    final schema = IPLDSchema('paths', {
      'LinkEntry': {
        'kind': 'struct',
        'fields': {
          'Hash': {'type': 'Link'},
          'Name': {'type': 'String'},
        },
      },
      'Dir': {
        'kind': 'struct',
        'fields': {
          'links': {
            'type': {'kind': 'list', 'valueType': 'LinkEntry'},
          },
        },
      },
    });

    test('nested list-of-struct failure reports full path', () {
      final node = mapNode({
        'links': listNode([
          mapNode({'Hash': linkNode(), 'Name': strNode('a')}),
          mapNode({'Hash': linkNode(), 'Name': strNode('b')}),
          mapNode({'Hash': strNode('not-a-link'), 'Name': strNode('c')}),
        ]),
      });
      final result = schema.check('Dir', node);
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, 'field "links".[2]."Hash"');
    });

    test('validateOrThrow includes the path in the error', () {
      final node = mapNode({
        'links': listNode([
          mapNode({'Hash': strNode('bad')}),
        ]),
      });
      expect(
        () => schema.validateOrThrow('Dir', node),
        throwsA(
          isA<IPLDSchemaError>().having(
            (e) => e.message,
            'message',
            contains('field "links".[0]."Hash"'),
          ),
        ),
      );
    });
  });

  group('map kind', () {
    final schema = IPLDSchema('maps', {
      'Scores': {
        'kind': 'map',
        'keyType': 'String',
        'valueType': 'Int',
      },
      'NullableMap': {
        'kind': 'map',
        'keyType': 'String',
        'valueType': 'Int',
        'valueNullable': true,
      },
      'AnyMap': {'kind': 'map'},
      'Pairs': {
        'kind': 'map',
        'keyType': 'String',
        'valueType': 'Int',
        'representation': {
          'stringpairs': {'innerDelim': '=', 'entrySep': ','},
        },
      },
      'ListedPairs': {
        'kind': 'map',
        'keyType': 'String',
        'valueType': 'Int',
        'representation': {'listpairs': <String, dynamic>{}},
      },
    });

    test('validates typed map values', () async {
      expect(
        await schema.validate(
          'Scores',
          mapNode({'a': intNode(1), 'b': intNode(2)}),
        ),
        isTrue,
      );
      expect(
        await schema.validate(
          'Scores',
          mapNode({'a': strNode('x')}),
        ),
        isFalse,
      );
    });

    test('honours valueNullable', () async {
      expect(
        await schema.validate('NullableMap', mapNode({'a': nullNode()})),
        isTrue,
      );
      expect(
        await schema.validate('Scores', mapNode({'a': nullNode()})),
        isFalse,
      );
    });

    test('bare map kind accepts any map and rejects non-maps', () async {
      expect(await schema.validate('AnyMap', mapNode({'a': strNode('x')})),
          isTrue);
      expect(await schema.validate('AnyMap', listNode([])), isFalse);
    });

    test('stringpairs representation parses entries', () async {
      expect(await schema.validate('Pairs', strNode('a=1,b=2')), isTrue);
      final bad = schema.check('Pairs', strNode('a=1,b=nope'));
      expect(bad.isValid, isFalse);
      expect(bad.errors.single.path, 'field "b"');
      expect(await schema.validate('Pairs', strNode('a1b2')), isFalse);
    });

    test('listpairs representation validates pair lists', () async {
      expect(
        await schema.validate(
          'ListedPairs',
          listNode([pairNode('a', intNode(1)), pairNode('b', intNode(2))]),
        ),
        isTrue,
      );
      expect(
        await schema.validate(
          'ListedPairs',
          listNode([pairNode('a', strNode('x'))]),
        ),
        isFalse,
      );
      expect(
        await schema.validate('ListedPairs', listNode([strNode('a')])),
        isFalse,
      );
    });
  });

  group('list kind', () {
    final schema = IPLDSchema('lists', {
      'Ints': {'kind': 'list', 'valueType': 'Int'},
      'MaybeInts': {
        'kind': 'list',
        'valueType': 'Int',
        'valueNullable': true,
      },
      'AnyList': {'kind': 'list'},
    });

    test('validates element types', () async {
      expect(
        await schema.validate('Ints', listNode([intNode(1), intNode(2)])),
        isTrue,
      );
      final bad = schema.check(
        'Ints',
        listNode([intNode(1), strNode('x')]),
      );
      expect(bad.isValid, isFalse);
      expect(bad.errors.single.path, 'field [1]');
    });

    test('honours valueNullable', () async {
      expect(
        await schema.validate('MaybeInts', listNode([intNode(1), nullNode()])),
        isTrue,
      );
      expect(
        await schema.validate('Ints', listNode([nullNode()])),
        isFalse,
      );
    });

    test('bare list accepts any list', () async {
      expect(await schema.validate('AnyList', listNode([strNode('x')])),
          isTrue);
      expect(await schema.validate('AnyList', strNode('x')), isFalse);
    });
  });

  group('enum kind', () {
    final schema = IPLDSchema('enums', {
      'Color': {
        'kind': 'enum',
        'members': ['red', 'green', 'blue'],
        'representation': {'string': <String, dynamic>{}},
      },
      'Code': {
        'kind': 'enum',
        'members': ['ok', 'notFound', 'error'],
        'representation': {
          'int': {'ok': 0, 'notFound': 4, 'error': 9},
        },
      },
    });

    test('string representation accepts members only', () async {
      expect(await schema.validate('Color', strNode('green')), isTrue);
      expect(await schema.validate('Color', strNode('purple')), isFalse);
      expect(await schema.validate('Color', intNode(0)), isFalse);
    });

    test('int representation accepts mapped values only', () async {
      expect(await schema.validate('Code', intNode(4)), isTrue);
      expect(await schema.validate('Code', intNode(7)), isFalse);
      expect(await schema.validate('Code', strNode('ok')), isFalse);
    });
  });

  group('union kind', () {
    final schema = IPLDSchema('unions', {
      'Small': {
        'kind': 'struct',
        'fields': {'x': {'type': 'Int'}},
      },
      'Keyed': {
        'kind': 'union',
        'members': ['Int', 'String'],
        'representation': {
          'keyed': {'i': 'Int', 's': 'String'},
        },
      },
      'Kinded': {
        'kind': 'union',
        'members': ['Int', 'String', 'Small'],
        'representation': {
          'kinded': {'int': 'Int', 'string': 'String', 'map': 'Small'},
        },
      },
      'Enveloped': {
        'kind': 'union',
        'members': ['Int', 'String'],
        'representation': {
          'envelope': {
            'discriminantKey': 'tag',
            'table': {'i': 'Int', 's': 'String'},
          },
        },
      },
      'Inline': {
        'kind': 'union',
        'members': ['Circle', 'Square'],
        'representation': {
          'inline': {
            'discriminantKey': 'shape',
            'table': {'circle': 'Circle', 'square': 'Square'},
          },
        },
      },
      'Circle': {
        'kind': 'struct',
        'fields': {'radius': {'type': 'Float'}},
      },
      'Square': {
        'kind': 'struct',
        'fields': {'side': {'type': 'Float'}},
      },
      'HexName': {
        'kind': 'enum',
        'members': ['aa', 'bb'],
        'representation': {'string': <String, dynamic>{}},
      },
      'Prefixed': {
        'kind': 'union',
        'members': ['String', 'HexName'],
        'representation': {
          'stringprefix': {
            'delim': ':',
            'table': {'s': 'String', 'h': 'HexName'},
          },
        },
      },
      'BytePrefixed': {
        'kind': 'union',
        'members': ['Bytes'],
        'representation': {
          'bytesprefix': {
            'table': {0: 'Bytes'},
          },
        },
      },
    });

    test('keyed union dispatches on the single map key', () async {
      expect(await schema.validate('Keyed', mapNode({'i': intNode(4)})),
          isTrue);
      expect(await schema.validate('Keyed', mapNode({'s': strNode('x')})),
          isTrue);
      expect(await schema.validate('Keyed', mapNode({'s': intNode(1)})),
          isFalse);
      expect(
        await schema.validate(
          'Keyed',
          mapNode({'i': intNode(1), 's': strNode('x')}),
        ),
        isFalse,
      );
      expect(await schema.validate('Keyed', mapNode({'z': intNode(1)})),
          isFalse);
      expect(await schema.validate('Keyed', strNode('x')), isFalse);
    });

    test('kinded union dispatches on node kind', () async {
      expect(await schema.validate('Kinded', intNode(3)), isTrue);
      expect(await schema.validate('Kinded', strNode('hi')), isTrue);
      expect(
        await schema.validate('Kinded', mapNode({'x': intNode(1)})),
        isTrue,
      );
      expect(await schema.validate('Kinded', boolNode(true)), isFalse);
      // kinded dispatch still type-checks the member.
      expect(
        await schema.validate('Kinded', mapNode({'x': strNode('no')})),
        isFalse,
      );
    });

    test('envelope union reads discriminant and tag-keyed content', () async {
      expect(
        await schema.validate(
          'Enveloped',
          mapNode({'tag': strNode('i'), 'i': intNode(9)}),
        ),
        isTrue,
      );
      // Content key must equal the tag value.
      expect(
        await schema.validate(
          'Enveloped',
          mapNode({'tag': strNode('i'), 's': strNode('x')}),
        ),
        isFalse,
      );
      // Unknown tag rejected.
      expect(
        await schema.validate(
          'Enveloped',
          mapNode({'tag': strNode('z'), 'z': intNode(1)}),
        ),
        isFalse,
      );
      // Extra keys rejected.
      expect(
        await schema.validate(
          'Enveloped',
          mapNode({
            'tag': strNode('i'),
            'i': intNode(1),
            'extra': intNode(2),
          }),
        ),
        isFalse,
      );
    });

    test('inline union merges discriminant into member struct', () async {
      expect(
        await schema.validate(
          'Inline',
          mapNode({'shape': strNode('circle'), 'radius': floatNode(1.5)}),
        ),
        isTrue,
      );
      expect(
        await schema.validate(
          'Inline',
          mapNode({'shape': strNode('square'), 'side': floatNode(2)}),
        ),
        isTrue,
      );
      // Wrong member payload for the tag.
      expect(
        await schema.validate(
          'Inline',
          mapNode({'shape': strNode('circle'), 'side': floatNode(2)}),
        ),
        isFalse,
      );
      // Missing discriminant.
      expect(
        await schema.validate('Inline', mapNode({'radius': floatNode(1)})),
        isFalse,
      );
    });

    test('stringprefix union splits on the delimiter', () async {
      expect(await schema.validate('Prefixed', strNode('s:hello')), isTrue);
      expect(await schema.validate('Prefixed', strNode('h:aa')), isTrue);
      // Remainder validated against the member type (enum member here).
      expect(await schema.validate('Prefixed', strNode('h:zz')), isFalse);
      expect(await schema.validate('Prefixed', strNode('x:1')), isFalse);
      expect(await schema.validate('Prefixed', intNode(1)), isFalse);
    });

    test('bytesprefix union strips the leading byte', () async {
      expect(
        await schema.validate('BytePrefixed', bytesNode([0, 1, 2])),
        isTrue,
      );
      expect(
        await schema.validate('BytePrefixed', bytesNode([7, 1])),
        isFalse,
      );
      expect(await schema.validate('BytePrefixed', bytesNode([])), isFalse);
      expect(await schema.validate('BytePrefixed', strNode('x')), isFalse);
    });
  });

  group('struct representation strategies', () {
    final schema = IPLDSchema('reprs', {
      'Tuple': {
        'kind': 'struct',
        'fields': {
          'x': {'type': 'Int'},
          'y': {'type': 'Int'},
          'label': {'type': 'String', 'optional': true},
        },
        'representation': {
          'tuple': {
            'fieldOrder': ['x', 'y', 'label'],
          },
        },
      },
      'Joined': {
        'kind': 'struct',
        'fields': {
          'host': {'type': 'String'},
          'port': {'type': 'Int'},
        },
        'representation': {
          'stringjoin': {
            'join': ':',
            'fieldOrder': ['host', 'port'],
          },
        },
      },
      'Paired': {
        'kind': 'struct',
        'fields': {
          'name': {'type': 'String'},
          'age': {'type': 'Int'},
        },
        'representation': {
          'stringpairs': {'join': '=', 'entrySep': ','},
        },
      },
      'Listed': {
        'kind': 'struct',
        'fields': {
          'name': {'type': 'String'},
          'age': {'type': 'Int', 'optional': true},
        },
        'representation': {'listpairs': <String, dynamic>{}},
      },
    });

    test('tuple representation validates positional fields', () async {
      expect(
        await schema.validate('Tuple', listNode([intNode(1), intNode(2)])),
        isTrue,
      );
      expect(
        await schema.validate(
          'Tuple',
          listNode([intNode(1), intNode(2), strNode('p')]),
        ),
        isTrue,
      );
      // Missing required y.
      expect(await schema.validate('Tuple', listNode([intNode(1)])), isFalse);
      // Wrong element type.
      expect(
        await schema.validate(
          'Tuple',
          listNode([intNode(1), strNode('x')]),
        ),
        isFalse,
      );
      // Too many elements.
      expect(
        await schema.validate(
          'Tuple',
          listNode([intNode(1), intNode(2), strNode('p'), intNode(4)]),
        ),
        isFalse,
      );
      // Null mid-tuple for non-nullable field.
      expect(
        await schema.validate('Tuple', listNode([nullNode(), intNode(2)])),
        isFalse,
      );
    });

    test('stringjoin representation parses joined scalars', () async {
      expect(await schema.validate('Joined', strNode('host:8080')), isTrue);
      expect(await schema.validate('Joined', strNode('host:notanint')),
          isFalse);
      expect(await schema.validate('Joined', strNode('a:b:c')), isFalse);
      expect(await schema.validate('Joined', intNode(1)), isFalse);
    });

    test('struct stringpairs validates parsed entries', () async {
      expect(
        await schema.validate('Paired', strNode('name=ada,age=36')),
        isTrue,
      );
      expect(
        await schema.validate('Paired', strNode('name=ada,age=x')),
        isFalse,
      );
      // Missing required field.
      expect(await schema.validate('Paired', strNode('age=36')), isFalse);
      // Unknown key.
      expect(
        await schema.validate('Paired', strNode('name=ada,zzz=1')),
        isFalse,
      );
    });

    test('struct listpairs validates [key, value] lists', () async {
      expect(
        await schema.validate(
          'Listed',
          listNode([pairNode('name', strNode('ada'))]),
        ),
        isTrue,
      );
      expect(
        await schema.validate(
          'Listed',
          listNode([pairNode('name', strNode('ada')), pairNode('age',
              intNode(3))]),
        ),
        isTrue,
      );
      // Required field missing.
      expect(
        await schema.validate('Listed', listNode([pairNode('age',
            intNode(3))])),
        isFalse,
      );
      // Unknown key.
      expect(
        await schema.validate('Listed', listNode([pairNode('zz',
            strNode('1'))])),
        isFalse,
      );
    });
  });

  group('miscellaneous kinds and aliases', () {
    final schema = IPLDSchema('misc', {
      'Alias': {'kind': 'copy', 'fromType': 'Int'},
      'Anything': {'kind': 'any'},
      'Nothing': {'kind': 'unit'},
      'Linky': {'kind': 'link'},
      'Big': {'kind': 'bigint'},
      'Ref': {'kind': 'type', 'valueType': 'Alias'},
      'NullableFloat': {
        'kind': 'struct',
        'fields': {
          'v': {'type': 'Float', 'nullable': true},
        },
      },
    });

    test('copy delegates to the source type', () async {
      expect(await schema.validate('Alias', intNode(3)), isTrue);
      expect(await schema.validate('Alias', strNode('x')), isFalse);
      expect(await schema.validate('Ref', intNode(3)), isTrue);
    });

    test('any accepts every node kind', () async {
      expect(await schema.validate('Anything', strNode('x')), isTrue);
      expect(await schema.validate('Anything', mapNode({})), isTrue);
      expect(await schema.validate('Anything', nullNode()), isTrue);
    });

    test('unit accepts only null by default', () async {
      expect(await schema.validate('Nothing', nullNode()), isTrue);
      expect(await schema.validate('Nothing', strNode('x')), isFalse);
    });

    test('link requires the link kind', () async {
      expect(await schema.validate('Linky', linkNode()), isTrue);
      expect(await schema.validate('Linky', strNode('x')), isFalse);
    });

    test('nullable scalar field accepts null or value', () async {
      expect(
        await schema.validate('NullableFloat', mapNode({'v': nullNode()})),
        isTrue,
      );
      expect(
        await schema.validate(
          'NullableFloat',
          mapNode({'v': floatNode(1.25)}),
        ),
        isTrue,
      );
      // non-optional nullable field still required
      expect(
        await schema.validate('NullableFloat', mapNode({})),
        isFalse,
      );
    });
  });

  group('malformed schema definitions', () {
    test('missing kind throws', () {
      final s = IPLDSchema('bad', {
        'T': <String, dynamic>{'fields': <String, dynamic>{}},
      });
      expect(() => s.check('T', nullNode()), throwsA(isA<IPLDSchemaError>()));
    });

    test('unknown kind throws', () {
      final s = IPLDSchema('bad', {
        'T': {'kind': 'wat'},
      });
      expect(() => s.check('T', nullNode()), throwsA(isA<IPLDSchemaError>()));
    });

    test('dangling type reference throws', () {
      final s = IPLDSchema('bad', {
        'T': {'kind': 'type', 'valueType': 'Missing'},
      });
      expect(() => s.check('T', intNode(1)), throwsA(isA<IPLDSchemaError>()));
    });

    test('circular type alias throws instead of looping', () {
      final s = IPLDSchema('bad', {
        'A': {'kind': 'copy', 'fromType': 'B'},
        'B': {'kind': 'copy', 'fromType': 'A'},
      });
      expect(() => s.check('A', intNode(1)), throwsA(isA<IPLDSchemaError>()));
    });

    test('union without representation throws', () {
      final s = IPLDSchema('bad', {
        'U': {'kind': 'union'},
      });
      expect(() => s.check('U', intNode(1)), throwsA(isA<IPLDSchemaError>()));
    });

    test('inline union with non-struct member throws', () {
      final s = IPLDSchema('bad', {
        'U': {
          'kind': 'union',
          'representation': {
            'inline': {
              'discriminantKey': 'k',
              'table': {'x': 'Int'},
            },
          },
        },
      });
      expect(
        () => s.check('U', mapNode({'k': strNode('x')})),
        throwsA(isA<IPLDSchemaError>()),
      );
    });
  });

  group('result objects', () {
    test('check collects multiple errors', () {
      final s = IPLDSchema('r', {
        'T': {
          'kind': 'struct',
          'fields': {
            'a': {'type': 'Int'},
            'b': {'type': 'String'},
          },
        },
      });
      final result = s.check(
        'T',
        mapNode({'a': strNode('x'), 'b': intNode(1)}),
      );
      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.errors[0].path, 'field "a"');
      expect(result.errors[1].path, 'field "b"');
      expect(result.toString(), contains('field "a"'));
    });

    test('root-level failure uses the value path', () {
      final s = IPLDSchema('r', {
        'T': {'kind': 'string'},
      });
      final result = s.check('T', intNode(1));
      expect(result.errors.single.path, 'value');
    });
  });

  group('backward compatibility', () {
    test('validate returns a Future<bool>', () async {
      final s = IPLDSchema('compat', {
        'T': {'kind': 'int'},
      });
      final result = s.validate('T', intNode(1));
      expect(result, isA<Future<bool>>());
      expect(await result, isTrue);
    });

    test('legacy valueConstraint still enforced', () async {
      final s = IPLDSchema('compat', {
        'T': {
          'kind': 'int',
          'valueConstraint': {'min': 5},
        },
      });
      expect(await s.validate('T', intNode(3)), isFalse);
      expect(await s.validate('T', intNode(9)), isTrue);
    });

    test('legacy union representation maps still work', () async {
      final s = IPLDSchema('compat', {
        'U': {
          'kind': 'union',
          'representation': {
            'a': {'kind': 'int'},
            'b': {'kind': 'string'},
          },
        },
      });
      expect(await s.validate('U', intNode(1)), isTrue);
      expect(await s.validate('U', strNode('x')), isTrue);
      expect(await s.validate('U', boolNode(true)), isFalse);
    });

    test('legacy strict flag still rejects unknown fields', () async {
      final s = IPLDSchema('compat', {
        'S': {
          'kind': 'struct',
          'fields': {
            'a': {'kind': 'int'},
          },
          'strict': true,
        },
      });
      expect(
        await s.validate('S', mapNode({'a': intNode(1)})),
        isTrue,
      );
      expect(
        await s.validate(
          'S',
          mapNode({'a': intNode(1), 'b': intNode(2)}),
        ),
        isFalse,
      );
    });
  });
}
