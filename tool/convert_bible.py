# -*- coding: utf-8 -*-
"""Converte midvash almeida-livre.json para o asset compacto do app."""
import json
from pathlib import Path

src = Path(r'D:\EBD\assets\bible\_full_raw.json')
dst = Path(r'D:\EBD\assets\bible\almeida_1819.json')

OSIS_TO_ID = {
    'Gen': 'gen', 'Exod': 'exo', 'Lev': 'lev', 'Num': 'num', 'Deut': 'deu',
    'Josh': 'jos', 'Judg': 'jui', 'Ruth': 'rut', '1Sam': '1sa', '2Sam': '2sa',
    '1Kgs': '1rs', '2Kgs': '2rs', '1Chr': '1cr', '2Chr': '2cr', 'Ezra': 'esd',
    'Neh': 'nee', 'Esth': 'est', 'Job': 'jo', 'Ps': 'sal', 'Prov': 'pro',
    'Eccl': 'ecl', 'Song': 'can', 'Isa': 'isa', 'Jer': 'jer', 'Lam': 'lam',
    'Ezek': 'eze', 'Dan': 'dan', 'Hos': 'ose', 'Joel': 'joe', 'Amos': 'amo',
    'Obad': 'oba', 'Jonah': 'jon', 'Mic': 'miq', 'Nah': 'naa', 'Hab': 'hab',
    'Zeph': 'sof', 'Hag': 'age', 'Zech': 'zac', 'Mal': 'mal', 'Matt': 'mat',
    'Mark': 'mar', 'Luke': 'luc', 'John': 'joao', 'Acts': 'ato', 'Rom': 'rom',
    '1Cor': '1co', '2Cor': '2co', 'Gal': 'gal', 'Eph': 'ef', 'Phil': 'fp',
    'Col': 'cl', '1Thess': '1ts', '2Thess': '2ts', '1Tim': '1tm', '2Tim': '2tm',
    'Titus': 'tt', 'Phlm': 'fm', 'Heb': 'hb', 'Jas': 'tg', '1Pet': '1pe',
    '2Pet': '2pe', '1John': '1jo', '2John': '2jo', '3John': '3jo', 'Jude': 'jd',
    'Rev': 'ap',
}

NAMES = {
    'gen': 'Gênesis', 'exo': 'Êxodo', 'lev': 'Levítico', 'num': 'Números',
    'deu': 'Deuteronômio', 'jos': 'Josué', 'jui': 'Juízes', 'rut': 'Rute',
    '1sa': '1 Samuel', '2sa': '2 Samuel', '1rs': '1 Reis', '2rs': '2 Reis',
    '1cr': '1 Crônicas', '2cr': '2 Crônicas', 'esd': 'Esdras', 'nee': 'Neemias',
    'est': 'Ester', 'jo': 'Jó', 'sal': 'Salmos', 'pro': 'Provérbios',
    'ecl': 'Eclesiastes', 'can': 'Cânticos', 'isa': 'Isaías', 'jer': 'Jeremias',
    'lam': 'Lamentações', 'eze': 'Ezequiel', 'dan': 'Daniel', 'ose': 'Oséias',
    'joe': 'Joel', 'amo': 'Amós', 'oba': 'Obadias', 'jon': 'Jonas',
    'miq': 'Miquéias', 'naa': 'Naum', 'hab': 'Habacuque', 'sof': 'Sofonias',
    'age': 'Ageu', 'zac': 'Zacarias', 'mal': 'Malaquias', 'mat': 'Mateus',
    'mar': 'Marcos', 'luc': 'Lucas', 'joao': 'João', 'ato': 'Atos',
    'rom': 'Romanos', '1co': '1 Coríntios', '2co': '2 Coríntios', 'gal': 'Gálatas',
    'ef': 'Efésios', 'fp': 'Filipenses', 'cl': 'Colossenses',
    '1ts': '1 Tessalonicenses', '2ts': '2 Tessalonicenses', '1tm': '1 Timóteo',
    '2tm': '2 Timóteo', 'tt': 'Tito', 'fm': 'Filemom', 'hb': 'Hebreus',
    'tg': 'Tiago', '1pe': '1 Pedro', '2pe': '2 Pedro', '1jo': '1 João',
    '2jo': '2 João', '3jo': '3 João', 'jd': 'Judas', 'ap': 'Apocalipse',
}


def main() -> None:
    with src.open(encoding='utf-8') as f:
        data = json.load(f)

    out_books = {}
    order = []
    for b in data['books']:
        osis = b['book']
        bid = OSIS_TO_ID.get(osis)
        if not bid:
            raise SystemExit(f'Missing mapping for {osis}')
        testament = 'AT' if b.get('testament') == 'OT' else 'NT'
        chapters = []
        for ch in b['chapters']:
            verses = [v['text'] for v in sorted(ch['verses'], key=lambda x: x['number'])]
            chapters.append(verses)
        out_books[bid] = {
            'name': NAMES[bid],
            'testament': testament,
            'chapters': chapters,
        }
        order.append(bid)

    out = {
        'meta': {
            'id': 'almeida1819',
            'label': 'Almeida 1819',
            'license': 'public-domain',
            'source': 'midvash/bible-data (almeida-livre)',
            'note': (
                'Texto de domínio público (João Ferreira de Almeida, edição 1819 / Bíblia Livre). '
                'ARA, RA, SBB e NTLH exigem licença e não estão embutidas.'
            ),
        },
        'order': order,
        'books': out_books,
    }

    with dst.open('w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))

    print('books', len(out_books))
    print('size', dst.stat().st_size)
    print('joao1', out_books['joao']['chapters'][0][0][:80])
    print('sal23', out_books['sal']['chapters'][22][0][:80])
    print('chapters', sum(len(b['chapters']) for b in out_books.values()))
    print('verses', sum(len(c) for b in out_books.values() for c in b['chapters']))


if __name__ == '__main__':
    main()
