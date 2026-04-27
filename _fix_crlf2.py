import os

flutter_dir = '/mnt/c/dev/flutter'
fixed_count = 0
for root, dirs, files in os.walk(flutter_dir):
    for fname in files:
        fpath = os.path.join(root, fname)
        try:
            with open(fpath, 'rb') as fh:
                content = fh.read()
            if b'\r\n' in content:
                content = content.replace(b'\r\n', b'\n')
                with open(fpath, 'wb') as fh:
                    fh.write(content)
                fixed_count += 1
                print(f'Fixed: {fpath}')
        except (PermissionError, IsADirectoryError, OSError):
            pass

print(f'\nTotal fixed: {fixed_count}')
