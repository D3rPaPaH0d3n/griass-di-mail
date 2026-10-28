#!/usr/bin/env python3
"""Fetch exact Ubuntu dependency sources listed beside a native release.
Copyright 2026 Markus Kainer <projekt@kainer.co.at>
SPDX-License-Identifier: GPL-3.0-only
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import uuid
import urllib.parse
import urllib.request


def digest(path, algorithm):
    result = hashlib.new(algorithm)
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('index', type=Path)
    parser.add_argument('destination', type=Path, nargs='?', default=Path('native-dependency-sources'))
    parser.add_argument('--package', action='append', help='Limit to this source package (repeatable)')
    parser.add_argument('--list', action='store_true', help='Print source URLs without downloading')
    parser.add_argument('--verify-existing', action='store_true', help='Verify local files without network access')
    args = parser.parse_args()
    sources = json.loads(args.index.read_text())['sources']
    selected = set(args.package or [])
    if selected:
        known = {item['source_package'] for item in sources}
        if selected - known:
            parser.error('Unknown source package: ' + ', '.join(sorted(selected - known)))
        sources = [item for item in sources if item['source_package'] in selected]
    for source in sources:
        for item in source['files']:
            name = item['name']
            algorithm = item['checksum_algorithm']
            checksum = item['checksum']
            url = urllib.parse.urlsplit(item['url'])
            if (not name or Path(name).name != name or name in ('.', '..') or
                    url.scheme != 'https' or url.username or url.password or
                    url.hostname not in ('archive.ubuntu.com', 'security.ubuntu.com') or
                    algorithm not in ('sha256', 'sha512') or
                    not re.fullmatch(r'[0-9a-f]{' + str(hashlib.new(algorithm).digest_size * 2) + r'}', checksum)):
                raise SystemExit('Invalid source index entry: ' + name)
            target = args.destination / name
            if args.list:
                print(item['url'])
                continue
            if target.exists():
                if target.stat().st_size != item['size'] or digest(target, algorithm) != checksum:
                    raise SystemExit('Existing source differs; preserved without overwrite: ' + str(target))
                print('OK', name)
                continue
            if args.verify_existing:
                raise SystemExit('Missing source file: ' + str(target))
            args.destination.mkdir(parents=True, exist_ok=True)
            # Never execute downloaded inputs; verify bytes before atomic rename.
            temporary = target.with_name(target.name + '.' + uuid.uuid4().hex + '.part')
            request = urllib.request.Request(item['url'], headers={'User-Agent': 'Griass-di-Mail-source-fetch/1.0'})
            try:
                with urllib.request.urlopen(request, timeout=60) as response, temporary.open('xb') as output:
                    count = 0
                    for chunk in iter(lambda: response.read(1024 * 1024), b''):
                        count += len(chunk)
                        if count > item['size']:
                            raise ValueError('Source exceeds indexed size: ' + name)
                        output.write(chunk)
                if temporary.stat().st_size != item['size'] or digest(temporary, algorithm) != checksum:
                    raise ValueError('Source checksum differs: ' + name)
                temporary.rename(target)
                print('Verified', name)
            finally:
                if temporary.exists():
                    temporary.unlink()


if __name__ == '__main__':
    main()
