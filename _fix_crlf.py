import os

files = [
    '/mnt/c/dev/flutter/bin/internal/shared.sh',
    '/mnt/c/dev/flutter/bin/flutter',
    '/mnt/c/dev/flutter/bin/dart',
]
for f in files:
    if os.path.exists(f):
        with open(f, 'rb') as fh:
            content = fh.read()
        if b'\r\n' in content:
            content = content.replace(b'\r\n', b'\n')
            with open(f, 'wb') as fh:
                fh.write(content)
            print(f'Fixed CRLF: {f}')
        else:
            print(f'Already LF: {f}')
    else:
        print(f'Not found: {f}')
