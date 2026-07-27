# Gamificação EBD

Regras de pontuação e badges do **Placar EBD** (menu ⋮ → Conquistas / Placar).

Constantes editáveis: `lib/data/engagement/gamification_rules.dart`.

## Pontos

| Critério | Pontos | Constante |
|----------|--------|-----------|
| Presença na chamada | +10 | `kPtsPresenca` |
| Trouxe Bíblia na aula | +5 | `kPtsBibliaNaAula` |
| Revista paga (trimestre) | +15 | `kPtsRevistaPaga` |
| Revista paga no mês corrente | +5 | `kPtsRevistaEmDia` |
| Capítulo lido (Bíblia EBD)* | +2 (teto diário 20) | `kPtsCapituloLido` |
| Streak de leitura (por dia)* | +3 | `kPtsStreakLeituraDia` |
| Dia de plano de leitura* | +8 | `kPtsPlanoLeituraDia` |
| Quiz concluído* | +5 + 2×acertos | `kPtsQuizBase` / `kPtsQuizPorAcerto` |
| Recorde Expert ≥70%* | +25 | `kPtsQuizExpertRecorde` |
| Cadastro completo (foto+tel+aniversário) | +20 | `kPtsCadastroCompleto` |
| 100% presença no mês | +40 | `kPtsPresenca100Mes` |

\* Créditos de leitura/quiz do aparelho vão para o aluno cujo nome/matrícula coincide com o usuário logado.

## Badges

Definidos em `EbdBadges` (mesmo arquivo). Exemplos: Primeiro passo, Fiel na EBD, Bíblia na mão, Leitor dedicado, 7 dias de leitura, Revista em dia, Quiz iniciante/expert, Cadastro completo, Mês perfeito.

## Ranking de classes

Soma das entradas financeiras do tipo **oferta** no mês corrente.

## Backup

Histórico de sorteios, melhores scores de quiz e bônus manuais entram no backup JSON (versão ≥ 6), chave `engagement`.
