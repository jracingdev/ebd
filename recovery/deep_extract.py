import re, pathlib, json

out = pathlib.Path('analysis')
decoded = (out / 'libapp_all_strings.txt').read_text(encoding='utf-8', errors='replace').splitlines()

# Portuguese / app-domain focused extraction
interesting = []
for s in decoded:
    if len(s) < 4 or len(s) > 300:
        continue
    # skip obvious framework noise
    low = s.lower()
    if any(x in low for x in (
        'flutter', 'dart:', 'widget', 'renderobject', 'semantics',
        'materialicons', 'cupertino', 'assert', 'exception', 'stack overflow',
        'null check', 'type cast', 'devtools', 'ticker', 'animationcontroller',
        'inheritedwidget', 'buildcontext', 'stateless', 'stateful',
        'application/vnd', 'http_proxy', 'channel-buffers'
    )):
        continue
    # keep Portuguese accents or domain keywords
    if re.search(r'[áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ]', s) or any(k in low for k in (
        'aluno', 'turma', 'classe', 'igreja', 'ebd', 'presen', 'chamada',
        'professor', 'lição', 'licao', 'trimestre', 'oferta', 'backup',
        'revista', 'domingo', 'visitante', 'relat', 'painel', 'secretaria',
        'cadastro', 'matric', 'batism', 'anivers', 'export', 'import',
        'pdf', 'drive', 'google', 'sqlite', 'hive', 'shared_pref',
        'isar', 'drift', 'floor', 'semana', 'lições', 'ausente', 'presente',
        'bibli', 'culto', 'salão', 'salao', 'departamento', 'superintend'
    )):
        interesting.append(s)

# unique preserving order
seen = set()
uniq = []
for s in interesting:
    if s not in seen:
        seen.add(s)
        uniq.append(s)

(out / 'app_domain_strings.txt').write_text('\n'.join(uniq), encoding='utf-8')
print(f'app_domain_strings: {len(uniq)}')
for s in uniq:
    print(s)

print('\n==== package: URIs ====')
pkgs = sorted(set(re.findall(r'package:([a-zA-Z0-9_]+)/', '\n'.join(decoded))))
print('\n'.join(pkgs))
(out / 'dart_packages.txt').write_text('\n'.join(pkgs), encoding='utf-8')

print('\n==== file:// build paths ====')
for s in decoded:
    if 'D:/' in s or 'D:\\' in s or '.dart' in s and ('lib/' in s or 'package:ebd' in s or 'livro' in s):
        if 'flutter' not in s.lower() and 'dart-sdk' not in s.lower():
            print(s)

print('\n==== likely screen/route names ====')
for s in decoded:
    if re.search(r'(Screen|Page|View|Route|Tab|Sheet|Dialog|Form|Controller|Repository|Service|Model|Provider|Notifier|Cubit|Bloc)$', s) and len(s) < 80:
        if not s.startswith('_') and 'Flutter' not in s and 'Render' not in s and 'Semantics' not in s:
            print(s)

print('\n==== JSON-like field names / snake_case keys ====')
keys = sorted(set(re.findall(r'\b[a-z][a-z0-9_]{2,40}\b', '\n'.join(uniq))))
# filter to likely model fields
modelish = [k for k in keys if '_' in k or k in (
    'alunos','turmas','classes','igreja','ofertas','presencas','trimestres',
    'revistas','backup','nome','idade','telefone','endereco','observacao',
    'presente','ausente','data','titulo','capa','arquivo'
)]
print('\n'.join(modelish[:200]))
