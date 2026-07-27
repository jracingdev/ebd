import subprocess, time, pathlib, re

def sh(cmd):
    return subprocess.check_output(cmd, shell=True)

def dump(name):
    sh('adb shell uiautomator dump /sdcard/ebd_ui.xml')
    sh(f'adb pull /sdcard/ebd_ui.xml D:/EBD/recovery/analysis/{name}.xml')
    sh('adb shell screencap -p /sdcard/ebd_screen.png')
    sh(f'adb pull /sdcard/ebd_screen.png D:/EBD/recovery/analysis/{name}.png')
    t = pathlib.Path(f'D:/EBD/recovery/analysis/{name}.xml').read_text(encoding='utf-8', errors='replace')
    texts = [x for x in re.findall(r'text="([^"]+)"', t) if x.strip()]
    print(name, '=>', texts)
    return t

def tap_label(xml, label):
    for text,x1,y1,x2,y2 in re.findall(r'text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
        if text.strip() == label:
            cx=(int(x1)+int(x2))//2; cy=(int(y1)+int(y2))//2
            sh(f'adb shell input tap {cx} {cy}')
            print('tapped', label, cx, cy)
            time.sleep(1.2)
            return True
    print('NOT FOUND', label)
    return False

# ensure app foreground
sh('adb shell am start -n br.com.ebd.livro_registro/.MainActivity')
time.sleep(2)
xml = dump('ui_revistas')

for tab in ['Ofertas', 'Presença', 'Alunos']:
    if tap_label(xml if tab=='Ofertas' else pathlib.Path(f'D:/EBD/recovery/analysis/ui_{tab.lower()}.xml').read_text(encoding='utf-8', errors='replace') if False else dump(f'ui_tmp'), tab):
        pass
    # re-dump current for next
    xml = dump(f'ui_{tab.lower()}')

# scroll chips right to find more tabs
sh('adb shell input swipe 900 430 200 430 300')
time.sleep(0.8)
xml = dump('ui_after_swipe')
# try common leftover tabs
for tab in ['Painel', 'Backup', 'Turmas', 'Classes', 'Início', 'Inicio']:
    tap_label(xml, tab)
xml = dump('ui_final')
