#!/usr/bin/env python3
"""Generate the native catalog or verify that a built app carries only approved art."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Pentaphor/Resources/art-catalog.json'


def approved_catalog():
    source = (ROOT / 'design/quest-art-data.js').read_text()
    entries = json.loads(source[source.index('['):source.rindex(']') + 1])
    assert len(entries) == 60 and len({entry['id'] for entry in entries}) == 60
    for entry in entries:
        assert (ROOT / 'assets/quest-art' / entry['file']).is_file(), entry['file']
    return entries


def verify(app):
    approved = approved_catalog()
    assert json.loads((app / 'art-catalog.json').read_text()) == approved
    images = list(app.rglob('*.png'))
    assert len(images) == 60, f'Expected 60 PNGs; found {len(images)}'
    assert {image.name for image in images} == {entry['file'] for entry in approved}
    for item in app.rglob('*'):
        assert '.generation' not in item.parts, item
        if item.is_file():
            assert item.suffix not in {'.html', '.md', '.js', '.jsonl'}, item
            assert item.name not in {'manifest.json', 'prompts.txt'}, item
    print('PASS: 60 approved PNGs, matching catalog, no source/generation metadata')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['generate', 'verify'])
    parser.add_argument('app', nargs='?', type=Path)
    args = parser.parse_args()
    if args.command == 'generate':
        CATALOG.write_text(json.dumps(approved_catalog(), ensure_ascii=False, indent=2) + '\n')
        print('Generated catalog for 60 approved images')
    else:
        if args.app is None:
            parser.error('verify requires the built .app path')
        verify(args.app)
