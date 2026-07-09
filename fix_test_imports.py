import re
import glob
import os

files = glob.glob('test/**/*.dart', recursive=True)

for f in files:
    try:
        with open(f, encoding='utf-8') as fh:
            content = fh.read()
        
        # Replace relative imports to lib/src with package imports
        new_content = re.sub(r"(import\s+['\"])\.\./\.\./\.\./lib/src/", r"\1package:dart_ipfs/src/", content)
        new_content = re.sub(r"(import\s+['\"])\.\./\.\./lib/src/", r"\1package:dart_ipfs/src/", new_content)
        # Also handle parts, exports, etc.
        new_content = re.sub(r"(export\s+['\"])\.\./\.\./\.\./lib/src/", r"\1package:dart_ipfs/src/", new_content)
        new_content = re.sub(r"(export\s+['\"])\.\./\.\./lib/src/", r"\1package:dart_ipfs/src/", new_content)
        
        if new_content != content:
            with open(f, encoding='utf-8', mode='w') as fh:
                fh.write(new_content)
            print(f'Updated: {f}')
    except Exception as e:
        print(f'Error processing {f}: {e}')

print('Done')
