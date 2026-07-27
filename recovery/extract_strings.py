import re, pathlib, collections

out = pathlib.Path('analysis')
out.mkdir(exist_ok=True)

lib = pathlib.Path('apk_extracted/lib/arm64-v8a/libapp.so')
data = lib.read_bytes()
print(f'libapp.so size: {len(data)}')

# Extract printable UTF-8-ish strings length >= 4
strings = re.findall(rb'[\x20-\x7e]{4,}', data)
decoded = [s.decode('ascii', errors='ignore') for s in strings]
(out / 'libapp_all_strings.txt').write_text('\n'.join(decoded), encoding='utf-8')
print('total strings:', len(decoded))

def dump(name, pred):
    hits = sorted(set(s for s in decoded if pred(s)))
    (out / name).write_text('\n'.join(hits), encoding='utf-8')
    print(f'{name}: {len(hits)}')
    for h in hits[:80]:
        print(' ', h)
    if len(hits) > 80:
        print(f'  ... +{len(hits)-80} more')
    return hits

# URLs / hosts
dump('urls.txt', lambda s: s.startswith('http') or '://' in s or '.com' in s or '.br' in s)

# package-like dart paths / imports
dump('dart_paths.txt', lambda s: (
    'package:' in s or
    s.startswith('package:') or
    '/lib/' in s or
    s.endswith('.dart') or
    'br.com' in s or
    'ebd' in s.lower()
))

# UI / Portuguese domain terms
pt_keywords = (
    'classe', 'aluno', 'aluna', 'igreja', 'ebd', 'escola', 'bíblia', 'biblia',
    'registro', 'presença', 'presenca', 'chamada', 'professor', 'lição', 'licao',
    'trimestre', 'sala', 'visitante', 'oferta', 'culto', 'matrícula', 'matricula',
    'relatório', 'relatorio', 'anivers', 'batismo', 'membro', 'secretaria',
    'login', 'senha', 'email', 'usuário', 'usuario', 'salvar', 'excluir',
    'editar', 'adicionar', 'novo', 'nova', 'buscar', 'pesquisa', 'filtro',
    'data', 'hora', 'semana', 'domingo', 'lições', 'licoes'
)
dump('pt_ui_strings.txt', lambda s: any(k in s.lower() for k in pt_keywords) and len(s) < 200)

# JSON / API-ish
dump('json_apiish.txt', lambda s: (
    s.startswith('{') or s.startswith('[') or
    'api' in s.lower() or 'supabase' in s.lower() or 'firebase' in s.lower() or
    'graphql' in s.lower() or 'endpoint' in s.lower() or
    'Authorization' in s or 'Bearer' in s or
    'Content-Type' in s
))

# Class / type names (Dart VM often keeps type names)
dump('type_names.txt', lambda s: (
    re.fullmatch(r'[A-Z][A-Za-z0-9_]{2,60}', s) is not None or
    re.fullmatch(r'[a-z][a-z0-9_]{2,40}\.[A-Z][A-Za-z0-9_]+', s) is not None
))

# Plugin / channel names
dump('method_channels.txt', lambda s: (
    'plugins.flutter.io' in s or
    'dev.flutter' in s or
    'MethodChannel' in s or
    '/' in s and (s.count('/') >= 1) and re.search(r'[a-z]+\.[a-z]+', s) and len(s) < 120 and ' ' not in s
))

print('done')
