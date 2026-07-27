import re, pathlib
t = pathlib.Path('analysis/ebd_ui.xml').read_text(encoding='utf-8', errors='replace')
texts = re.findall(r'text="([^"]+)"', t)
print('UI TEXTS:')
for x in texts:
    if x.strip():
        print('-', x)
bounds = re.findall(r'text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', t)
print('\nTAPPABLE:')
for text,x1,y1,x2,y2 in bounds:
    if text.strip():
        cx=(int(x1)+int(x2))//2; cy=(int(y1)+int(y2))//2
        print(f'{cx},{cy} | {text}')
