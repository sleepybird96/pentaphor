#!/usr/bin/env python3
"""Generate the native catalog or verify that a built app carries only approved art."""
import argparse
import json
import plistlib
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
    art_names = {entry['file'] for entry in approved}
    art_images = [image for image in images if image.name in art_names]
    assert len(art_images) == 60 and {image.name for image in art_images} == art_names
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    icon_names = set()
    for key in ('CFBundleIcons', 'CFBundleIcons~ipad'):
        primary = info.get(key, {}).get('CFBundlePrimaryIcon', {})
        icon_names.update(primary.get('CFBundleIconFiles', []))
    assert info['CFBundleIcons']['CFBundlePrimaryIcon']['CFBundleIconName'] == 'AppIcon'
    assert (app / 'Assets.car').is_file(), 'Compiled brand assets missing'
    icon_images = [image for image in images if image.name not in art_names]
    assert icon_images, 'App icon PNGs missing'
    assert all(image.stem.split('@')[0] in icon_names for image in icon_images), icon_images
    for item in app.rglob('*'):
        assert '.generation' not in item.parts, item
        if item.is_file():
            assert item.suffix not in {'.html', '.md', '.js', '.jsonl'}, item
            assert item.name not in {'manifest.json', 'prompts.txt'}, item
    print('PASS: 60 approved quest PNGs, app icon and compiled brand assets, no source/generation metadata')


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
