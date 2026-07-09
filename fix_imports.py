import re
import glob

files = glob.glob('lib/**/*.dart', recursive=True)

for f in files:
    try:
        with open(f, encoding='utf-8') as fh:
            content = fh.read()
        
        # Add hide clause to dart_ipfs_core imports in umbrella package
        new_content = re.sub(
            r"import 'package:dart_ipfs_core/dart_ipfs_core\.dart';",
            r"import 'package:dart_ipfs_core/dart_ipfs_core.dart' hide Block, CID, IBlock, IBlockStore;",
            content
        )
        
        if new_content != content:
            with open(f, encoding='utf-8', mode='w') as fh:
                fh.write(new_content)
            print(f'Updated: {f}')
    except Exception as e:
        print(f'Error processing {f}: {e}')

print('Done')
