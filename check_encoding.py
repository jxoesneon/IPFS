import subprocess
import os

# Get list of modified files
result = subprocess.run(['git', 'status', '--short'], capture_output=True, text=True, cwd='c:/Users/josee/IPFS')
lines = result.stdout.split('\n')

modified_files = []
for line in lines:
    if line.startswith(' M ') or line.startswith('?? '):
        f = line[3:].strip()
        if f.endswith('.dart'):
            modified_files.append(f)

utf16_files = []
for f in modified_files:
    path = os.path.join('c:/Users/josee/IPFS', f)
    if not os.path.exists(path):
        continue
    with open(path, 'rb') as fh:
        data = fh.read(2)
    if data == b'\xff\xfe' or data == b'\xfe\xff':
        utf16_files.append(f)

if utf16_files:
    print('UTF-16 files:')
    for f in utf16_files:
        print(f)
else:
    print('No UTF-16 files found')
