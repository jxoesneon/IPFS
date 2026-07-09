import glob
import re

patterns = [
    r"import 'package:dart_ipfs_core/dart_ipfs_core\.dart'\s*$\s*import",
    r"import '[^']+';\s*hide\s+",
    r"import '[^']+';\s*show\s+",
    r"import '[^']+';{2,}",
]

broken_files = []
for f in glob.glob('lib/**/*.dart', recursive=True):
    try:
        with open(f, encoding='utf-8') as fh:
            content = fh.read()
        for p in patterns:
            if re.search(p, content, re.M):
                broken_files.append(f)
                break
    except Exception as e:
        print(f"Error reading {f}: {e}")

for f in broken_files:
    print(f)
