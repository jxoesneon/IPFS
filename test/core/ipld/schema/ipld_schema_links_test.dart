// test/core/ipld/schema/ipld_schema_links_test.dart
//
// Tests for link `expectedType` enforcement (via an injected link
// resolver) and `advanced` (ADL) representation validation in
// lib/src/core/ipld/schema/ipld_schema.dart.

import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

IPLDNode strNode(String v) => IPLDNode()
  ..kind = Kind.STRING
  ..stringValue = v;
IPLDNode intNode(int v) => IPLDNode()
  ..kind = Kind.INTEGER
  ..intValue = Int64(v);
IPLDNode nullNode() => IPLDNode()..kind = Kind.NULL;
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

/// A well-formed sha2-256 multihash whose digest is derived from [seed].
Uint8List _multihash(int seed) =>
    Uint8List.fromList([0x12, 0x20, ...List.filled(31, 0), seed]);

/// A link node identified by [seed] so distinct targets are distinguishable.
IPLDNode linkNode(int seed, {String codec = 'dag-cbor'}) => IPLDNode()
  ..kind = Kind.LINK
  ..linkValue = (IPLDLink()
    ..version = 1
    ..codec = codec
    ..multihash = _multihash(seed));

String _storeKey(IPLDLink link) => '${link.codec}:${link.multihash.join('.')}';

/// A resolver backed by a simple in-memory store keyed on codec+multihash.
IPLDLinkResolver storeResolver(Map<String, IPLDNode?> store) =>
    (link) async => store[_storeKey(link)];

void main() {
  final docSchema = <String, dynamic>{
    'Payload': {
      'kind': 'struct',
      'fields': {
        'name': {'type': 'String'},
      },
    },
    'Doc': {
      'kind': 'struct',
      'fields': {
        'data': {
          'type': {'kind': 'link', 'expectedType': 'Payload'},
        },
      },
    },
  };

  final doc = mapNode({'data': linkNode(1)});
  final goodPayload = mapNode({'name': strNode('ok')});
  final badPayload = intNode(7);

  group('link expectedType with resolver', () {
    test('matching target passes', () async {
      final schema = IPLDSchema('t', docSchema);
      final result = await schema.checkAsync(
        'Doc',
        doc,
        linkResolver: storeResolver({
          _storeKey(linkNode(1).linkValue): goodPayload,
        }),
      );
      expect(result.isValid, isTrue);
    });

    test('wrong-typed target fails at the link path', () async {
      final schema = IPLDSchema('t', docSchema);
      final result = await schema.checkAsync(
        'Doc',
        doc,
        linkResolver: storeResolver({
          _storeKey(linkNode(1).linkValue): badPayload,
        }),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, 'field "data"');
      expect(result.errors.single.message, contains('expected map'));
    });

    test('missing target reports a defined error', () async {
      final schema = IPLDSchema('t', docSchema);
      final result = await schema.checkAsync(
        'Doc',
        doc,
        linkResolver: (link) async => null,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, 'field "data"');
      expect(result.errors.single.message, contains('link target not found'));
    });

    test('resolver exceptions surface as resolution failures', () async {
      final schema = IPLDSchema('t', docSchema);
      final result = await schema.checkAsync(
        'Doc',
        doc,
        linkResolver: (link) async => throw StateError('boom'),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, 'field "data"');
      expect(result.errors.single.message, contains('link resolution failed'));
    });

    test('inline expectedType term validates the resolved target', () async {
      final schema = IPLDSchema('t', <String, dynamic>{
        'Root': {
          'kind': 'link',
          'expectedType': {'kind': 'string'},
        },
      });
      final key = _storeKey(linkNode(1).linkValue);
      final ok = await schema.checkAsync(
        'Root',
        linkNode(1),
        linkResolver: storeResolver({key: strNode('v')}),
      );
      expect(ok.isValid, isTrue);
      final bad = await schema.checkAsync(
        'Root',
        linkNode(1),
        linkResolver: storeResolver({key: intNode(3)}),
      );
      expect(bad.isValid, isFalse);
    });

    test('validate enforces expectedType with a per-call resolver', () async {
      final schema = IPLDSchema('t', docSchema);
      expect(
        await schema.validate(
          'Doc',
          doc,
          linkResolver: storeResolver({
            _storeKey(linkNode(1).linkValue): goodPayload,
          }),
        ),
        isTrue,
      );
      expect(
        await schema.validate(
          'Doc',
          doc,
          linkResolver: storeResolver({
            _storeKey(linkNode(1).linkValue): badPayload,
          }),
        ),
        isFalse,
      );
    });

    test('constructor resolver is used by validate and checkAsync', () async {
      final schema = IPLDSchema(
        't',
        docSchema,
        linkResolver: storeResolver({
          _storeKey(linkNode(1).linkValue): badPayload,
        }),
      );
      expect(await schema.validate('Doc', doc), isFalse);
      expect(
        (await schema.checkAsync('Doc', doc)).errors.single.path,
        'field "data"',
      );
    });

    test('validateOrThrowAsync raises on mismatched targets', () async {
      final schema = IPLDSchema('t', docSchema);
      await expectLater(
        schema.validateOrThrowAsync(
          'Doc',
          doc,
          linkResolver: storeResolver({
            _storeKey(linkNode(1).linkValue): badPayload,
          }),
        ),
        throwsA(isA<IPLDSchemaError>()),
      );
      await schema.validateOrThrowAsync(
        'Doc',
        doc,
        linkResolver: storeResolver({
          _storeKey(linkNode(1).linkValue): goodPayload,
        }),
      );
    });

    test(
      'links nested inside resolved targets are checked transitively',
      () async {
        final chainSchema = <String, dynamic>{
          'Chain': {
            'kind': 'struct',
            'fields': {
              'val': {'type': 'String'},
              'next': {
                'type': {'kind': 'link', 'expectedType': 'Chain'},
                'optional': true,
              },
            },
          },
          'Root': {
            'kind': 'struct',
            'fields': {
              'head': {
                'type': {'kind': 'link', 'expectedType': 'Chain'},
              },
            },
          },
        };
        final schema = IPLDSchema('t', chainSchema);
        final store = <String, IPLDNode?>{
          _storeKey(linkNode(1).linkValue): mapNode({
            'val': strNode('a'),
            'next': linkNode(2),
          }),
          _storeKey(linkNode(2).linkValue): mapNode({
            'val': intNode(3), // deep violation
          }),
        };
        final result = await schema.checkAsync(
          'Root',
          mapNode({'head': linkNode(1)}),
          linkResolver: storeResolver(store),
        );
        expect(result.isValid, isFalse);
        expect(result.errors.single.path, 'field "head"."next"."val"');
      },
    );

    test(
      'repeated links to one target resolve once and report per path',
      () async {
        var calls = 0;
        IPLDNode? resolver(IPLDLink link) {
          calls++;
          return badPayload;
        }

        final schema = IPLDSchema('t', <String, dynamic>{
          'Payload': docSchema['Payload'],
          'Pair': {
            'kind': 'struct',
            'fields': {
              'a': {
                'type': {'kind': 'link', 'expectedType': 'Payload'},
              },
              'b': {
                'type': {'kind': 'link', 'expectedType': 'Payload'},
              },
            },
          },
        });
        final same = linkNode(9);
        final result = await schema.checkAsync(
          'Pair',
          mapNode({'a': same, 'b': linkNode(9)}),
          linkResolver: (link) async => resolver(link),
        );
        expect(calls, 1);
        expect(
          result.errors.map((e) => e.path),
          containsAll(['field "a"', 'field "b"']),
        );
      },
    );

    test('cyclic links terminate via the result cache', () async {
      final schema = IPLDSchema('t', <String, dynamic>{
        'Loop': {
          'kind': 'struct',
          'fields': {
            'next': {
              'type': {'kind': 'link', 'expectedType': 'Loop'},
              'optional': true,
            },
          },
        },
        'Root': {'kind': 'link', 'expectedType': 'Loop'},
      });
      final store = <String, IPLDNode?>{
        _storeKey(linkNode(1).linkValue): mapNode({'next': linkNode(1)}),
      };
      final result = await schema.checkAsync(
        'Root',
        linkNode(1),
        linkResolver: storeResolver(store),
      );
      expect(result.isValid, isTrue);
    });

    test('expectedType inside a list validates each element target', () async {
      final schema = IPLDSchema('t', <String, dynamic>{
        'Payload': docSchema['Payload'],
        'Docs': {
          'kind': 'list',
          'valueType': {'kind': 'link', 'expectedType': 'Payload'},
        },
      });
      final store = <String, IPLDNode?>{
        _storeKey(linkNode(1).linkValue): goodPayload,
        _storeKey(linkNode(2).linkValue): badPayload,
      };
      final result = await schema.checkAsync(
        'Docs',
        listNode([linkNode(1), linkNode(2)]),
        linkResolver: storeResolver(store),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, 'field [1]');
    });

    test('linkResolverFromNodeLoader adapts a CID-based loader', () async {
      final cid = CID.v1('dag-cbor', Multihash.decode(_multihash(1)));
      final byCid = <String, IPLDNode>{cid.toString(): goodPayload};
      final schema = IPLDSchema(
        't',
        docSchema,
        linkResolver: IPLDSchema.linkResolverFromNodeLoader(
          (c) async => byCid[c.toString()],
        ),
      );
      expect(await schema.validate('Doc', doc), isTrue);
    });

    test('loader exceptions from the adapter fail the link', () async {
      final schema = IPLDSchema(
        't',
        docSchema,
        linkResolver: IPLDSchema.linkResolverFromNodeLoader(
          (c) async => throw IPLDLinkError('Block not found: $c'),
        ),
      );
      final result = await schema.checkAsync('Doc', doc);
      expect(result.isValid, isFalse);
      expect(result.errors.single.message, contains('link resolution failed'));
    });
  });

  group('link expectedType without resolver', () {
    test('sync check only kind-checks links', () {
      final schema = IPLDSchema('t', docSchema);
      expect(schema.check('Doc', doc).isValid, isTrue);
      expect(
        schema.check('Doc', mapNode({'data': intNode(1)})).isValid,
        isFalse,
      );
    });

    test('checkAsync without a resolver behaves like check', () async {
      final schema = IPLDSchema('t', docSchema);
      expect((await schema.checkAsync('Doc', doc)).isValid, isTrue);
    });
  });

  group('advanced representations', () {
    test('implicit ADL name (type name) validates against declared term', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'MyAdl': {'kind': 'map', 'representation': 'advanced'},
        'advanced': {'MyAdl': 'String'},
      });
      expect(schema.check('MyAdl', strNode('x')).isValid, isTrue);
      final result = schema.check('MyAdl', intNode(1));
      expect(result.isValid, isFalse);
      expect(result.errors.single.message, contains('expected string'));
    });

    test('explicit ADL name validates against its declared term', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'T': {
          'kind': 'struct',
          'representation': {'advanced': 'Hamt'},
        },
        'advanced': {
          'Hamt': {'kind': 'map'},
        },
      });
      expect(schema.check('T', mapNode({})).isValid, isTrue);
      expect(schema.check('T', strNode('x')).isValid, isFalse);
    });

    test('ADL declarations may point at named types in the same schema', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'Inner': {
          'kind': 'struct',
          'fields': {
            'n': {'type': 'Int'},
          },
        },
        'T': {'kind': 'list', 'representation': 'advanced'},
        'advanced': {'T': 'Inner'},
      });
      expect(schema.check('T', mapNode({'n': intNode(1)})).isValid, isTrue);
      expect(schema.check('T', mapNode({'n': strNode('x')})).isValid, isFalse);
    });

    test('union advanced representation validates against the ADL term', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'U': {
          'kind': 'union',
          'representation': {'advanced': 'U1'},
        },
        'advanced': {'U1': 'String'},
      });
      expect(schema.check('U', strNode('x')).isValid, isTrue);
      expect(schema.check('U', intNode(1)).isValid, isFalse);
    });

    test('map-form advanced representation names the ADL', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'T': {
          'kind': 'map',
          'representation': {
            'advanced': {'name': 'Hamt'},
          },
        },
        'advanced': {'Hamt': 'String'},
      });
      expect(schema.check('T', strNode('x')).isValid, isTrue);
      expect(schema.check('T', intNode(1)).isValid, isFalse);
    });

    test('map-form advanced representation without a name falls back', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'T': {
          'kind': 'map',
          'representation': {
            'advanced': {'other': 'ignored'},
          },
        },
        'advanced': {'T': 'String'},
      });
      expect(schema.check('T', strNode('x')).isValid, isTrue);
      expect(schema.check('T', intNode(1)).isValid, isFalse);
    });

    test('adlTypes registry supplies ADL terms', () {
      final schema = IPLDSchema(
        't',
        <String, dynamic>{
          'T': {
            'kind': 'map',
            'representation': {'advanced': 'Ext'},
          },
        },
        adlTypes: {'Ext': 'Int'},
      );
      expect(schema.check('T', intNode(3)).isValid, isTrue);
      expect(schema.check('T', strNode('x')).isValid, isFalse);
    });

    test('adlTypes may register a full IPLDSchema for the ADL', () {
      final adl = IPLDSchema('adl', <String, dynamic>{
        'Ext': {'kind': 'string'},
      });
      final schema = IPLDSchema(
        't',
        <String, dynamic>{
          'T': {
            'kind': 'map',
            'representation': {'advanced': 'Ext'},
          },
        },
        adlTypes: {'Ext': adl},
      );
      expect(schema.check('T', strNode('x')).isValid, isTrue);
      final result = schema.check('T', intNode(1));
      expect(result.isValid, isFalse);
      expect(result.errors.single.message, contains('ADL "Ext"'));
    });

    test('unknown ADL is tolerated at validation time', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'U': {'kind': 'unit', 'representation': 'advanced'},
        'M': {'kind': 'map', 'representation': 'advanced'},
      });
      expect(schema.check('U', strNode('x')).isValid, isTrue);
      expect(schema.check('M', intNode(1)).isValid, isTrue);
    });

    test('anonymous inline defs cannot derive an ADL name and are skipped', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'S': {
          'kind': 'struct',
          'fields': {
            'blob': {
              'type': {'kind': 'map', 'representation': 'advanced'},
            },
          },
        },
      });
      expect(schema.check('S', mapNode({'blob': intNode(4)})).isValid, isTrue);
    });

    test('declared ADL with a null term skips validation', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'T': {
          'kind': 'map',
          'representation': {'advanced': 'Empty'},
        },
        'advanced': {'Empty': null},
      });
      expect(schema.check('T', intNode(1)).isValid, isTrue);
    });

    test(
      'schema referencing an undeclared ADL is rejected at construction',
      () {
        expect(
          () => IPLDSchema('t', <String, dynamic>{
            'T': {
              'kind': 'list',
              'representation': {'advanced': 'Nope'},
            },
          }),
          throwsA(isA<IPLDSchemaError>()),
        );
        expect(
          () => IPLDSchema('t', <String, dynamic>{
            'T': {
              'kind': 'map',
              'representation': {
                'advanced': {'name': 'Nope'},
              },
            },
          }),
          throwsA(isA<IPLDSchemaError>()),
        );
      },
    );

    test('undeclared ADL references are rejected inside nested defs', () {
      expect(
        () => IPLDSchema('t', <String, dynamic>{
          'S': {
            'kind': 'struct',
            'fields': {
              'm': {
                'type': {
                  'kind': 'map',
                  'representation': {'advanced': 'Nope'},
                },
              },
            },
          },
        }),
        throwsA(isA<IPLDSchemaError>()),
      );
      expect(
        () => IPLDSchema('t', <String, dynamic>{
          'T': {'kind': 'map'},
          'advanced': {
            'A': {
              'kind': 'list',
              'representation': {'advanced': 'B'},
            },
          },
        }),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('a non-map advanced block is rejected at construction', () {
      expect(
        () => IPLDSchema('t', <String, dynamic>{
          'T': {'kind': 'map'},
          'advanced': 'nope',
        }),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('advanced declarations satisfy explicit references', () {
      final schema = IPLDSchema('t', <String, dynamic>{
        'T': {
          'kind': 'map',
          'representation': {'advanced': 'Ok'},
        },
        'advanced': {'Ok': 'Bool'},
      });
      expect(
        schema
            .check(
              'T',
              IPLDNode()
                ..kind = Kind.BOOL
                ..boolValue = true,
            )
            .isValid,
        isTrue,
      );
    });
  });
}
