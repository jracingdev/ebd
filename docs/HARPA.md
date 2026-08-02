# Harpa EBD — hinos e direitos

O módulo **Harpa EBD** é secundário ao livro de registro (como a Bíblia EBD). A interface usa o tema creme/verde/dourado do app e nomes próprios (“Harpa EBD”, “Favoritos”, “Buscar hinos”).

## App de referência no device (UX de features apenas)

| Campo | Valor |
|---|---|
| Package | `br.com.aleluiah_apps.hinario.harpa_crista` |
| Versão observada | `72` (versionCode 72) |
| Device | wireless ADB (`VKJ-AN90` / `adb-APEEUT6525000794-…`) |
| Activities vistas | `PrivacyPolicyActivity` (LAUNCHER), `OpenAdSplashActivity`, `DictionaryActivity` |
| Artefatos | `recovery/analysis/harpa_ref_*.png`, `harpa_ui_*.xml`, `harpa_ref_notes.md` |

**Inspiração de funcionalidades** (lista por número, busca, favoritos, leitor, voz): **não** copiar layout, cores, ícones nem fluxo pixel-a-pixel. **Não** extrair letras, APK ou assets desse app (obra CPAD).

## O que o app entrega hoje

| Recurso | Comportamento |
|---|---|
| Catálogo 1–640 | Asset `assets/harpa/catalog.json` — só `{number, title}` |
| Lista / grade | Hub + lista numerada no estilo EBD |
| Busca | Por número e título (catálogo local) |
| Leitor | Estrofes com anterior/próximo, ajuste de fonte |
| Favoritos | Hive (`ebd_harpa_v1`) |
| TTS | Mesmo padrão `BibleTtsService` (motor do SO) |
| Letras | Runtime via API pública + cache Hive; ou asset opcional licenciado |

## Letras e copyright (CPAD)

As letras da **Harpa Cristã** pertencem à **Casa Publicadora das Assembleias de Deus (CPAD)**.

- **Não** commitamos dump completo de letras scrapeadas no git.
- **Não** embutimos JSON pirateado de crawlers de terceiros.
- O APK embute **apenas índice** (número + título). Títulos são metadados de catálogo.
- Em runtime, se a API pública estiver disponível, o app pode baixar a letra para **cache local do usuário** (Hive). Isso **não** substitui licença CPAD para redistribuição; documentamos o risco: uso pessoal/dev, sem redistribuir o cache como pacote.
- Asset opcional `assets/harpa/hinos.json` só deve ser gerado com **fonte licenciada** pelo time.
- Sem letra (API fora / sem cache / sem asset): UI permanece estável, com mensagem clara e link para informações CPAD — **nunca crash**.

Informações comerciais CPAD: [https://www.cpad.com.br](https://www.cpad.com.br)

## API remota (runtime)

Endpoint usado hoje (terceiro, disponibilidade não garantida):

- Base: `https://harpa-api.onrender.com`
- Hino: `GET /hymns/{number}` → título + estrofes
- Lista paginada: `GET /hymns?page=N` (usada só para gerar o catálogo de títulos)

Se a API cair, o módulo continua com títulos + aviso no leitor.

## Arquitetura

1. `HarpaCatalog` — carrega `catalog.json`.
2. `HarpaRemoteSource` — busca letra na API.
3. `HarpaRepository.loadHymn` — asset opcional → cache Hive → API → mensagem acionável.
4. Persistência Hive `ebd_harpa_v1`: prefs (último hino, fonte, TTS), favoritos, cache de letras.

## Formato de letra em cache / asset opcional

```json
{
  "number": 1,
  "title": "Chuvas de Graça",
  "stanzas": [
    {"sequence": 1, "text": "...", "isChorus": false}
  ],
  "sourceNote": "…"
}
```
