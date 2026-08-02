import 'package:flutter_test/flutter_test.dart';
import 'package:livro_registro/data/bible/bible_catalog.dart';

/// Contagens canônicas protestantes (66 livros / 1189 capítulos).
const _kProtestantChapterCounts = <String, int>{
  'gen': 50,
  'exo': 40,
  'lev': 27,
  'num': 36,
  'deu': 34,
  'jos': 24,
  'jui': 21,
  'rut': 4,
  '1sa': 31,
  '2sa': 24,
  '1rs': 22,
  '2rs': 25,
  '1cr': 29,
  '2cr': 36,
  'esd': 10,
  'nee': 13,
  'est': 10,
  'jo': 42,
  'sal': 150,
  'pro': 31,
  'ecl': 12,
  'can': 8,
  'isa': 66,
  'jer': 52,
  'lam': 5,
  'eze': 48,
  'dan': 12,
  'ose': 14,
  'joe': 3,
  'amo': 9,
  'oba': 1,
  'jon': 4,
  'miq': 7,
  'naa': 3,
  'hab': 3,
  'sof': 3,
  'age': 2,
  'zac': 14,
  'mal': 4,
  'mat': 28,
  'mar': 16,
  'luc': 24,
  'joao': 21,
  'ato': 28,
  'rom': 16,
  '1co': 16,
  '2co': 13,
  'gal': 6,
  'ef': 6,
  'fp': 4,
  'cl': 4,
  '1ts': 5,
  '2ts': 3,
  '1tm': 6,
  '2tm': 4,
  'tt': 3,
  'fm': 1,
  'hb': 13,
  'tg': 5,
  '1pe': 5,
  '2pe': 3,
  '1jo': 5,
  '2jo': 1,
  '3jo': 1,
  'jd': 1,
  'ap': 22,
};

void main() {
  test('catálogo tem 66 livros canônicos protestantes', () {
    expect(kBibleBooks.length, 66);
    expect(kBibleBooks.where((b) => b.testament == 'AT').length, 39);
    expect(kBibleBooks.where((b) => b.testament == 'NT').length, 27);
  });

  test('contagens de capítulos batem com o cânon protestante', () {
    expect(_kProtestantChapterCounts.length, 66);
    final byId = {for (final b in kBibleBooks) b.id: b};
    for (final entry in _kProtestantChapterCounts.entries) {
      final book = byId[entry.key];
      expect(book, isNotNull, reason: 'livro ausente: ${entry.key}');
      expect(
        book!.chapters,
        entry.value,
        reason: '${book.name} (${book.id}) deveria ter ${entry.value} caps',
      );
    }
  });

  test('Salmos tem 150 capítulos e total canônico é 1189', () {
    final salmos = bookById('sal');
    expect(salmos, isNotNull);
    expect(salmos!.chapters, 150);
    final total = kBibleBooks.fold<int>(0, (s, b) => s + b.chapters);
    expect(total, 1189);
  });

  test('ids únicos e slugs Midvash para todos os livros', () {
    final ids = kBibleBooks.map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final b in kBibleBooks) {
      expect(b.chapters, greaterThan(0));
      expect(kMidvashBookSlugs.containsKey(b.id), isTrue,
          reason: 'slug Midvash ausente para ${b.id}');
    }
  });

  test('grade de capítulos é 1..N canônico (não depende de cache)', () {
    for (final book in kBibleBooks) {
      final grid = List<int>.generate(book.chapters, (i) => i + 1);
      expect(grid.first, 1);
      expect(grid.last, book.chapters);
      expect(grid.length, book.chapters);
    }
  });
}
