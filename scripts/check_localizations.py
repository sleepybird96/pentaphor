"""Check resource parity and printf placeholders without touching user data."""
import collections
import json
from pathlib import Path
import plistlib
import re
import sys

def placeholders(value):
    return collections.Counter(re.findall(r'%(?:\d+\$)?(?:#@\w+@|(?:ll|l)?[diuf@])', value.replace('%%', '')))

def validate(english, korean):
    errors = []
    if english.keys() != korean.keys():
        errors.append('Localization keys differ: ' + str(sorted(english.keys() ^ korean.keys())))
    for key in english.keys() & korean.keys():
        left, right = english[key], korean[key]
        if isinstance(left, dict) and isinstance(right, dict):
            # Plural categories may differ by language; metadata and each available form must agree.
            for name in left.keys() & right.keys():
                a, b = left[name], right[name]
                if isinstance(a, dict) and isinstance(b, dict):
                    if 'other' not in a or 'other' not in b:
                        errors.append(f'{key}: missing other plural')
                    for form in ['one','other','zero','two','few','many']:
                        if form in b and placeholders(a.get('other','')) != placeholders(b[form]):
                            errors.append(f'{key}: incompatible plural placeholder')
                elif a != b:
                    errors.append(f'{key}: incompatible plural metadata')
        elif not isinstance(left, str) or not isinstance(right, str) or placeholders(left) != placeholders(right):
            errors.append(f'{key}: incompatible placeholders')
    return errors

def read_strings(path):
    pairs = re.findall(r'("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*")\s*;', path.read_text())
    result = {json.loads(k): json.loads(v) for k,v in pairs}
    if len(result) != len(pairs): raise ValueError(f'Duplicate keys: {path}')
    return result

def main():
    root = Path(__file__).resolve().parents[1]
    errors=[]
    for base in [root/'Pentaphor/Resources',root/'Packages/PentaphorCore/Sources/PentaphorCore/Resources']:
        for filename in ['Localizable.strings','Localizable.stringsdict']:
            paths=[base/f'{lang}.lproj'/filename for lang in ['en','ko']]
            if not any(p.exists() for p in paths): continue
            if not all(p.exists() for p in paths): errors.append(f'Missing peer resource: {base}/{filename}'); continue
            values=[read_strings(p) if p.suffix=='.strings' else plistlib.loads(p.read_bytes()) for p in paths]
            errors.extend(validate(*values))
    for error in errors: print(error)
    if errors:return 1
    print('Korean/English keys and format placeholders match.')
    return 0
if __name__ == '__main__': sys.exit(main())
