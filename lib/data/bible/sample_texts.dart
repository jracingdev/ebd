import 'package:livro_registro/data/bible/bible_models.dart';

/// Catálogo canônico (estrutura). Capítulos com texto embutido = amostra DP.
const kBibleBooks = <BibleBook>[
  BibleBook(id: 'gen', name: 'Gênesis', testament: 'AT', chapters: 50),
  BibleBook(id: 'exo', name: 'Êxodo', testament: 'AT', chapters: 40),
  BibleBook(id: 'sal', name: 'Salmos', testament: 'AT', chapters: 150),
  BibleBook(id: 'pro', name: 'Provérbios', testament: 'AT', chapters: 31),
  BibleBook(id: 'isa', name: 'Isaías', testament: 'AT', chapters: 66),
  BibleBook(id: 'mat', name: 'Mateus', testament: 'NT', chapters: 28),
  BibleBook(id: 'mar', name: 'Marcos', testament: 'NT', chapters: 16),
  BibleBook(id: 'luc', name: 'Lucas', testament: 'NT', chapters: 24),
  BibleBook(id: 'joao', name: 'João', testament: 'NT', chapters: 21),
  BibleBook(id: 'ato', name: 'Atos', testament: 'NT', chapters: 28),
  BibleBook(id: 'rom', name: 'Romanos', testament: 'NT', chapters: 16),
  BibleBook(id: '1co', name: '1 Coríntios', testament: 'NT', chapters: 16),
];

const kSampleSourceNote =
    'Amostra em domínio público (Almeida 1819), para estudo na EBD. '
    'Textos ARA / RA / SBB / NTLH são protegidos e devem ser licenciados — '
    'veja docs/BIBLIA.md.';

/// Planos próprios da EBD (não copiados de apps de terceiros).
const kEbdReadingPlans = <ReadingPlan>[
  ReadingPlan(
    id: 'ebd_semana',
    title: 'Semana da EBD',
    description:
        'Sete dias com trechos curtos para preparar a lição e a meditação.',
    days: [
      ReadingPlanDay(day: 1, bookId: 'sal', chapter: 23, title: 'O Senhor é o meu pastor'),
      ReadingPlanDay(day: 2, bookId: 'joao', chapter: 1, title: 'O Verbo'),
      ReadingPlanDay(day: 3, bookId: 'sal', chapter: 23, title: 'Revisitar o Salmo'),
      ReadingPlanDay(day: 4, bookId: 'joao', chapter: 1, title: 'Testemunho de João'),
      ReadingPlanDay(day: 5, bookId: 'sal', chapter: 23, title: 'Consolo'),
      ReadingPlanDay(day: 6, bookId: 'joao', chapter: 1, title: 'Luz verdadeira'),
      ReadingPlanDay(day: 7, bookId: 'sal', chapter: 23, title: 'Encerrar a semana'),
    ],
  ),
  ReadingPlan(
    id: 'ebd_evangelho',
    title: 'Olhar o Evangelho',
    description: 'Dois capítulos-amostra do Evangelho de João.',
    days: [
      ReadingPlanDay(day: 1, bookId: 'joao', chapter: 1, title: 'Prólogo'),
      ReadingPlanDay(day: 2, bookId: 'joao', chapter: 1, title: 'Reler com atenção'),
    ],
  ),
];

BibleBook? bookById(String id) {
  for (final b in kBibleBooks) {
    if (b.id == id) return b;
  }
  return null;
}

/// Capítulos-amostra (Almeida 1819 / domínio público).
BibleChapter? sampleChapter(String bookId, int chapter) {
  if (bookId == 'sal' && chapter == 23) return _psalm23;
  if (bookId == 'joao' && chapter == 1) return _john1;
  return null;
}

List<BibleVerse> searchSamples(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final out = <BibleVerse>[];
  for (final ch in [_psalm23, _john1]) {
    for (final v in ch.verses) {
      if (v.text.toLowerCase().contains(q) ||
          '${ch.bookId} ${ch.chapter}:${v.number}'.contains(q) ||
          (bookById(ch.bookId)?.name.toLowerCase().contains(q) ?? false)) {
        out.add(v);
      }
    }
  }
  return out;
}

const _psalm23 = BibleChapter(
  bookId: 'sal',
  chapter: 23,
  sourceNote: kSampleSourceNote,
  verses: [
    BibleVerse(
      bookId: 'sal',
      chapter: 23,
      number: 1,
      text: 'O Senhor é o meu pastor; nada me faltará.',
    ),
    BibleVerse(
      bookId: 'sal',
      chapter: 23,
      number: 2,
      text:
          'Deitar-me faz em verdes pastos, guia-me mansamente a águas tranquilas.',
    ),
    BibleVerse(
      bookId: 'sal',
      chapter: 23,
      number: 3,
      text:
          'Refrigera a minha alma; guia-me pelas veredas da justiça, por amor do seu nome.',
    ),
    BibleVerse(
      bookId: 'sal',
      chapter: 23,
      number: 4,
      text:
          'Ainda que eu andasse pelo vale da sombra da morte, não temeria mal algum, porque tu estás comigo; a tua vara e o teu cajado me consolam.',
    ),
    BibleVerse(
      bookId: 'sal',
      chapter: 23,
      number: 5,
      text:
          'Preparas uma mesa perante mim na presença dos meus inimigos, unges a minha cabeça com óleo, o meu cálice transborda.',
    ),
    BibleVerse(
      bookId: 'sal',
      chapter: 23,
      number: 6,
      text:
          'Certamente que a bondade e a misericórdia me seguirão todos os dias da minha vida; e habitarei na casa do Senhor por longos dias.',
    ),
  ],
);

const _john1 = BibleChapter(
  bookId: 'joao',
  chapter: 1,
  sourceNote: kSampleSourceNote,
  verses: [
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 1,
      text:
          'No princípio era o Verbo, e o Verbo estava com Deus, e o Verbo era Deus.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 2,
      text: 'Ele estava no princípio com Deus.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 3,
      text:
          'Todas as coisas foram feitas por ele, e sem ele nada do que foi feito se fez.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 4,
      text: 'Nele estava a vida, e a vida era a luz dos homens.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 5,
      text:
          'E a luz resplandece nas trevas, e as trevas não a compreenderam.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 6,
      text: 'Houve um homem enviado de Deus, cujo nome era João.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 7,
      text:
          'Este veio para testemunho, para que testificasse da luz, para que todos cressem por ele.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 8,
      text: 'Não era ele a luz, mas para que testificasse da luz.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 9,
      text:
          'Ali estava a luz verdadeira, que alumia a todo homem que vem ao mundo.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 10,
      text:
          'Estava no mundo, e o mundo foi feito por ele, e o mundo não o conheceu.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 11,
      text: 'Veio para o que era seu, e os seus não o receberam.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 12,
      text:
          'Mas, a todos quantos o receberam, deu-lhes o poder de serem feitos filhos de Deus, aos que crêem no seu nome;',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 13,
      text:
          'Os quais não nasceram do sangue, nem da vontade da carne, nem da vontade do varão, mas de Deus.',
    ),
    BibleVerse(
      bookId: 'joao',
      chapter: 1,
      number: 14,
      text:
          'E o Verbo se fez carne, e habitou entre nós, e vimos a sua glória, como a glória do unigênito do Pai, cheio de graça e de verdade.',
    ),
  ],
);
