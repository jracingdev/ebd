import os, json, zlib, re, pathlib

base = pathlib.Path('apk_extracted')
fa = base / 'assets' / 'flutter_assets'
out = pathlib.Path('analysis')
out.mkdir(exist_ok=True)

print('==== FontManifest ====')
font = (fa / 'FontManifest.json').read_text(encoding='utf-8')
print(font)
(out / 'FontManifest.json').write_text(font, encoding='utf-8')

print('==== NativeAssets ====')
native = (fa / 'NativeAssetsManifest.json').read_text(encoding='utf-8')
print(native)

print('==== AssetManifest.bin ====')
data = (fa / 'AssetManifest.bin').read_bytes()
print('len', len(data))
print(data)
print('ascii strings:', re.findall(rb'[\x20-\x7e]{3,}', data))

print('==== NOTICES packages ====')
notices = zlib.decompress((fa / 'NOTICES.Z').read_bytes())
text = notices.decode('utf-8', errors='replace')
(out / 'notices_decoded.txt').write_text(text, encoding='utf-8')

# Flutter license file: packages often appear as comma-separated on a line before license body
pkgs = set()
# Pattern used by flutter: first line(s) are package names separated by commas
for block in re.split(r'\n-+\n', text):
    first = block.strip().split('\n', 1)[0] if block.strip() else ''
    for part in first.split(','):
        name = part.strip()
        if re.fullmatch(r'[a-z][a-z0-9_]{1,80}', name):
            pkgs.add(name)

# Also scan all short identifier lines
for line in text.splitlines():
    s = line.strip()
    if re.fullmatch(r'[a-z][a-z0-9_]{1,80}', s):
        pkgs.add(s)

# Filter out common license noise words
noise = {
    'the', 'and', 'or', 'of', 'to', 'in', 'for', 'by', 'as', 'is', 'on', 'an',
    'all', 'any', 'not', 'from', 'with', 'this', 'that', 'are', 'be', 'at',
    'software', 'license', 'copyright', 'permission', 'notice', 'apache',
    'mit', 'bsd', 'gpl', 'lgpl', 'mozilla', 'foundation', 'inc', 'ltd',
}
pkgs = sorted(p for p in pkgs if p not in noise and len(p) > 2)
(out / 'packages_from_notices.txt').write_text('\n'.join(pkgs), encoding='utf-8')
print('packages found:', len(pkgs))
for p in pkgs:
    print(' -', p)

print('wrote analysis files')
