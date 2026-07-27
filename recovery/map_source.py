import re, pathlib, collections

out = pathlib.Path('analysis')
decoded = (out / 'libapp_all_strings.txt').read_text(encoding='utf-8', errors='replace').splitlines()

# All package:livro_registro paths
paths = sorted(set(re.findall(r'package:livro_registro/[a-zA-Z0-9_./]+\.dart', '\n'.join(decoded))))
print('==== SOURCE FILES ====')
for p in paths:
    print(p)
(out / 'source_files.txt').write_text('\n'.join(paths), encoding='utf-8')

# Also any livro_registro without package:
alts = sorted(set(s for s in decoded if 'livro_registro' in s and len(s) < 200))
print('\n==== livro_registro refs ====')
for s in alts:
    print(s)

# Classes ending with Model/Entity/Service/Screen/Page/Repository etc related to app
print('\n==== APP CLASSES ====')
app_classes = []
for s in decoded:
    if re.fullmatch(r'[A-Z][A-Za-z0-9_]{2,60}', s):
        low = s.lower()
        if any(k in low for k in (
            'aluno','turma','classe','ebd','presen','oferta','revista','backup',
            'trimestre','igreja','chamada','report','relat','painel','attendance',
            'delivery','entrega','sunday','domingo','hive','store','dashboard'
        )) or s.endswith(('Screen','Page','Service','Repository','Controller','Notifier','Provider','Model','Entity','Adapter','Form','Sheet','Dialog','Tab','Card','Tile','Header','Footer','App','Store','Box')):
            # filter flutter noise
            if not any(x in s for x in ('Flutter','Render','Semantics','Cupertino','Material','Sliver','Scroll','Focus','Gesture','Animation','Theme','InkWell','Scaffold')):
                app_classes.append(s)

app_classes = sorted(set(app_classes))
for c in app_classes:
    print(c)
(out / 'app_classes.txt').write_text('\n'.join(app_classes), encoding='utf-8')

# Field-like keys near JSON
print('\n==== JSON KEY CANDIDATES ====')
# look for quoted keys style in strings - hard in binary; instead gather snake and camel used in app strings file
domain = (out / 'app_domain_strings.txt').read_text(encoding='utf-8', errors='replace').splitlines()
keys = set()
for s in decoded:
    if re.fullmatch(r'[a-z][a-zA-Z0-9]{2,40}', s) and any(k in s.lower() for k in (
        'aluno','turma','classe','presen','oferta','revista','backup','trimestre',
        'nome','idade','fone','tel','email','data','titulo','capa','obs','igreja',
        'present','absent','attend','export','import','version','created','updated'
    )):
        keys.add(s)
    if re.fullmatch(r'[a-z]+([A-Z][a-z0-9]+)+', s):  # camelCase
        if any(k in s.lower() for k in ('aluno','turma','presen','oferta','revista','backup','trimestre','attend','export','import','present','absent','cover','sunday','class')):
            keys.add(s)
for k in sorted(keys):
    print(k)
(out / 'json_keys.txt').write_text('\n'.join(sorted(keys)), encoding='utf-8')

# Full Portuguese UI strings (with accents) short enough to be labels
print('\n==== PT LABELS ====')
pt = []
for s in decoded:
    if re.search(r'[áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ]', s) and 3 < len(s) < 160:
        if not any(x in s for x in ('flutter','Exception','Error:','package:','http')):
            pt.append(s)
pt = sorted(set(pt))
for s in pt:
    print(s)
(out / 'pt_labels.txt').write_text('\n'.join(pt), encoding='utf-8')

# Betel URLs and hardcoded content
print('\n==== BETEL / HARDCODED ====')
for s in decoded:
    if 'betel' in s.lower() or 'editora' in s.lower() or 'trimestre 202' in s.lower():
        print(s)
