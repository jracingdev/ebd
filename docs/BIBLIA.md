# Bíblia EBD — textos e licenças

O módulo **Bíblia EBD** é secundário ao livro de registro. A interface usa o tema do app e nomes próprios (“Bíblia EBD”, “Minha leitura”, “Marcadores”).

## O que o app entrega hoje (honesto)

| Versão no app | O que o usuário lê | Como chega o texto | Offline |
|---|---|---|---|
| **ARA 2ª** (rótulo: 2ª ed. revista e corrigida) | Almeida **Revista e Corrigida** (`arc` na API Midvash) | API pública + cache Hive | Após abrir capítulos ou “Baixar Bíblia completa” |
| **RA** (Revista e atualizada) | **ARA** Midvash (`ara`) | idem | idem |
| **SBB** | **NAA** (Nova Almeida Atualizada, edição SBB) Midvash (`naa`) | idem | idem |
| **NTLH** | **NTLH** Midvash (`ntlh`) | idem | idem |
| **AL 1819** | Almeida 1819 / Bíblia Livre | Asset `assets/bible/almeida_1819.json` (domínio público) | Sempre |

- Catálogo: **66 livros**, 1189 capítulos.
- Reader, TTS, marcadores e destaques funcionam sobre o texto carregado.
- Busca: completa no asset Almeida; nas outras versões, sobre o **cache** (baixe a versão para busca total).
- Capítulos sem rede/cache: mensagem acionável (tentar de novo / abrir Almeida 1819) — **nunca tela vazia silenciosa**.

## Direitos autorais

- **Não** embutimos ARA/RA/NTLH/NAA no APK (são protegidas; exigem contrato com a SBB ou detentor).
- **Não** extraímos texto de APKs de terceiros (“Bíblia Sagrada” etc.).
- **Almeida 1819** embutida: domínio público (`midvash/bible-data` → `almeida-livre`).
- Versões modernas: consumo sob demanda via **API pública Midvash** (`https://api.midvash.com`) com **cache local** no aparelho. Isso permite ler a Bíblia completa em cada sigla listada sem redistribuir o cânon no instalador.
- Opcional **API.Bible** (licença formal): configure no `.env`:

```env
BIBLE_API_KEY=...
BIBLE_API_ID_ARA2=
BIBLE_API_ID_RA=
BIBLE_API_ID_SBB=
BIBLE_API_ID_NTLH=
```

Com chave + IDs, o app tenta API.Bible primeiro e cai para Midvash se falhar.

## O que falta para “pacote embutido” de cada sigla

| Sigla | Para embutir no APK |
|---|---|
| ARA 2ª / ARC | Contrato/licença com detentor + JSON/SQLite autorizado |
| RA / ARA | Contrato SBB (ou detentor da ARA) |
| SBB / NAA | Contrato SBB para a edição desejada |
| NTLH | Contrato SBB |

Até lá, a leitura completa continua disponível via API + cache (e Almeida 1819 sempre offline).

## Arquitetura

1. `BibleAssetSource` — Almeida 1819 completa.
2. `BibleRemoteSource` — Midvash e, se configurado, API.Bible.
3. `BibleRepository.loadChapter` — asset → cache Hive → API → erro acionável.
4. `downloadCurrentVersionOffline()` — prefetch de todos os capítulos da versão atual.
5. Persistência Hive `ebd_bible_v1`: prefs, marcadores, destaques, planos, cache.

## Formato de capítulo em cache

```json
{
  "verses": [{"number": 1, "text": "..."}],
  "sourceNote": "..."
}
```
