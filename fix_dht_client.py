content = open('lib/src/protocols/dht/dht_client.dart', encoding='utf-8').read()
old = "import 'package:dart_ipfs_core/dart_ipfs_core.dart' hide Block, CID, IBlock, IBlockStore;"
new = "import '../../core/cid.dart';"
if old in content:
    content = content.replace(old, new, 1)
    open('lib/src/protocols/dht/dht_client.dart', 'w', encoding='utf-8').write(content)
    print('Replaced')
else:
    print('Old string not found')
