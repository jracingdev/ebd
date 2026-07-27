# Bíblia EBD — textos e licenças

O módulo **Bíblia EBD** é secundário ao livro de registro (revistas, ofertas, presença, alunos, painel, lições). A interface usa o tema do app (`AppColors`: creme, verde, dourado) e nomes próprios (“Bíblia EBD”, “Minha leitura”, “Marcadores”).

## O que já vem embutido

- **Estrutura** de livros/capítulos e seletor de versões na UI:
  - 2ª edição ARA revista e corrigida
  - Revista e atualizada (RA)
  - SBB
  - Versão com linguagem de hoje (NTLH)
- **Amostras** de domínio público (Almeida 1819): **Salmos 23** e **João 1**.
- Persistência Hive (`ebd_bible_v1`): preferências, marcadores, destaques, progresso de planos, cache de capítulos.
- TTS (`flutter_tts`), busca nas amostras, planos “Semana da EBD” / “Olhar o Evangelho”.

## Direitos autorais (obrigatório)

Textos modernos **ARA**, **RA**, **NTLH** e edições **SBB** são protegidos. **Não** copie APKs ou dumps de apps de terceiros para embutir o cânon completo.

Opções legais:

1. **Licença comercial** com a SBB (ou detentor) e empacotar JSON/SQLite sob contrato.
2. **API pública documentada** com termos que permitam cache offline (respeitar ToS).
3. Manter **domínio público** (ex.: Almeida 1819) rotulado com clareza.

## Como plugar textos licenciados

1. Implementar um `BibleTextSource` (ex. em `lib/services/`) com `Future<BibleChapter?> fetch(versionId, bookId, chapter)`.
2. Em `BibleRepository.loadChapter`:
   - tentar amostra local;
   - tentar cache Hive (`BibleStore.cacheChapter`);
   - chamar a fonte/API;
   - em falha de rede, retornar `null` (a UI já mostra estado vazio gracioso).
3. Formato sugerido de capítulo em cache:

```json
{
  "verses": [{"number": 1, "text": "..."}],
  "sourceNote": "Licença X — uso na EBD"
}
```

4. Não misturar rótulos de versão (ARA/RA/…) com texto de outra tradução sem aviso.

## Offline

Sem rede e sem amostra/cache, o leitor informa que o capítulo não está disponível. Capítulos já lidos via API devem ser gravados com `cacheChapter`.
