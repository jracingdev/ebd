/// Regras de pontuação e badges da gamificação EBD.
/// Edite estes valores para calibrar o placar sem alterar a UI.
/// Documentação: docs/GAMIFICACAO.md
library;

/// Pontos por presença em uma sessão de chamada.
const kPtsPresenca = 10;

/// Pontos por trazer a Bíblia na aula (além da presença).
const kPtsBibliaNaAula = 5;

/// Pontos por revista marcada como paga no trimestre atual.
const kPtsRevistaPaga = 15;

/// Pontos por entregar revista em dia (status pago no mesmo mês da criação).
const kPtsRevistaEmDia = 5;

/// Pontos por capítulo lido na Bíblia EBD (máx. diário abaixo).
const kPtsCapituloLido = 2;

/// Limite diário de pontos por leitura de capítulos.
const kPtsCapituloLidoMaxDia = 20;

/// Bônus por streak de leitura (dias consecutivos).
const kPtsStreakLeituraDia = 3;

/// Pontos por completar um dia de plano de leitura.
const kPtsPlanoLeituraDia = 8;

/// Pontos por quiz concluído (base + acertos).
const kPtsQuizBase = 5;
const kPtsQuizPorAcerto = 2;

/// Bônus ao bater recorde no nível Expert.
const kPtsQuizExpertRecorde = 25;

/// Pontos por cadastro completo (foto + telefone + aniversário).
const kPtsCadastroCompleto = 20;

/// Bônus por 100% de presença no mês corrente (domingos).
const kPtsPresenca100Mes = 40;

/// Identificadores de badges.
class EbdBadges {
  static const primeiroPasso = 'primeiro_passo';
  static const fielPresenca = 'fiel_presenca';
  static const bibliaNaMao = 'biblia_na_mao';
  static const leitorDedicado = 'leitor_dedicado';
  static const streak7 = 'streak_7';
  static const revistaEmDia = 'revista_em_dia';
  static const quizFacil = 'quiz_facil';
  static const quizExpert = 'quiz_expert';
  static const cadastroCompleto = 'cadastro_completo';
  static const ofertaClasse = 'oferta_classe';
  static const mesPerfeito = 'mes_perfeito';

  static const labels = <String, String>{
    primeiroPasso: 'Primeiro passo',
    fielPresenca: 'Fiel na EBD',
    bibliaNaMao: 'Bíblia na mão',
    leitorDedicado: 'Leitor dedicado',
    streak7: '7 dias de leitura',
    revistaEmDia: 'Revista em dia',
    quizFacil: 'Quiz iniciante',
    quizExpert: 'Quiz expert',
    cadastroCompleto: 'Cadastro completo',
    ofertaClasse: 'Classe generosa',
    mesPerfeito: 'Mês perfeito',
  };

  static const descriptions = <String, String>{
    primeiroPasso: 'Marcou a primeira presença.',
    fielPresenca: 'Acumulou 8 ou mais presenças.',
    bibliaNaMao: 'Trouxe a Bíblia em 4 aulas.',
    leitorDedicado: 'Leu 30 capítulos na Bíblia EBD.',
    streak7: 'Manteve streak de leitura por 7 dias.',
    revistaEmDia: 'Pagou a revista do trimestre.',
    quizFacil: 'Completou um quiz no nível fácil.',
    quizExpert: 'Acertou ≥70% no nível expert.',
    cadastroCompleto: 'Preencheu foto, telefone e aniversário.',
    ofertaClasse: 'Sua classe liderou ofertas no período.',
    mesPerfeito: '100% de presença no mês.',
  };
}
