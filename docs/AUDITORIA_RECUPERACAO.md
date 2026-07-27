# Auditoria e recuperação — EBD (livro_registro)

**Data:** 27/07/2026  
**Origem:** APK instalado no celular `VKJ-AN90` + arquivos em `/sdcard/Download/`  
**Pacote Android:** `br.com.ebd.livro_registro`  
**App label:** EBD  
**Versão:** 1.0.0 (versionCode 1)  
**Path original de build:** `D:/EBD/` (confirmado em strings do `libapp.so`)

## Veredito

O projeto Flutter **foi recuperável** a partir do APK + backups JSON + protótipo JSX encontrados no aparelho. O código Dart AOT **não** é decompilável linha a linha, mas:

1. A árvore de arquivos Dart estava preservada em strings do `libapp.so`
2. O schema completo está no `ebd-backup*.json`
3. O protótipo React original (`controle-revistas-ebd.jsx`) contém regras de negócio, turmas, catálogo Betel e UI

Este repositório reconstrói o app com base nessas fontes.

## Fontes recuperadas no celular

| Arquivo | Onde | Uso |
|---------|------|-----|
| `base.apk` (~57 MB) | app instalado | binário Flutter release |
| `ebd-backup.json` | Download | backup vazio/inicial (20/07) |
| `ebd-backup26-07-2026.json` | Download | backup completo (~345 KB) |
| `ebd-backup26-07-2026A.json` | Download | backup mais recente (26/07 10:33) |
| `controle-revistas-ebd.jsx.txt` | Download | protótipo web original |

Cópias em `reference/` e artefatos brutos em `recovery/`.

## Arquitetura do APK

- **Stack:** Flutter (embedding v2) + Kotlin `MainActivity`
- **Estado:** `provider` + `ChangeNotifier` (`AppState`)
- **Persistência local:** Hive box `ebd_v1`
- **Backend:** nenhum (offline-first)
- **Backup nuvem:** Storage Access Framework via MethodChannel `br.com.ebd.livro_registro/backup` (`saveBackup` / `pickBackup`) — usuário escolhe pasta do Google Drive
- **PDF/impressão:** `pdf` + `printing`
- **Gráficos:** `fl_chart`
- **Imagens:** `image_picker` (capa da revista)
- **Fontes:** `google_fonts` (Libre Caslon Text no protótipo/tema)
- **Permissões:** INTERNET, CAMERA (+ query GET_CONTENT)

### Árvore Dart recuperada do binário

```
package:livro_registro/main.dart
package:livro_registro/data/app_state.dart
package:livro_registro/data/betel_catalog.dart
package:livro_registro/data/models.dart
package:livro_registro/data/storage.dart
package:livro_registro/features/attendance/attendance_view.dart
package:livro_registro/features/backup/backup_screen.dart
package:livro_registro/features/backup/drive_backup_service.dart
package:livro_registro/features/dashboard/dashboard_view.dart
package:livro_registro/features/finances/finances_view.dart
package:livro_registro/features/home/home_screen.dart
package:livro_registro/features/magazines/magazines_view.dart
package:livro_registro/features/report/report_pdf.dart
package:livro_registro/features/students/students_view.dart
package:livro_registro/theme/app_theme.dart
package:livro_registro/utils/format.dart
package:livro_registro/widgets/common.dart
```

## Schema do backup (`version: 3`)

```json
{
  "version": 3,
  "exportedAt": "ISO-8601",
  "editions": [{ "id", "grupo", "trimestre", "capa", "criadoEm" }],
  "records": [{ "id", "nome", "grupo", "edicaoId", "valor", "status", "data" }],
  "finances": [{ "id", "grupo", "data", "tipo", "valor", "descricao", "criadoEm" }],
  "attendance": [{ "id", "grupo", "data", "pessoas": [{ "id", "nome", "presente", "alunoId?" }], "criadoEm" }],
  "students": [{ "id", "nome", "grupo", "criadoEm" }]
}
```

- `status`: `pago` | `pendente`
- `tipo`: `oferta` | `doacao`

## Turmas

1. Maternal (2-3 anos) — CRESCER+ Maternal  
2. Pré-escolar (4-5 anos) — CONHECER+ Pré-escolar  
3. Primários (6-8 anos) — APRENDER+ Primários  
4. Juniores (9-11 anos) — SABER+ Juniores  
5. Adolescentes 12-14 — ADOLESCER+  
6. Adolescentes 15-17 — VIVER+  
7. Jovens  
8. CIBE — Betel Dominical Adulto  
9. Varões — Betel Dominical Adulto  

## Dados reais no backup mais recente (26/07/2026A)

- 66 alunos
- 5 edições de revista
- 32 entregas/pagamentos de revista
- 5 sessões de presença
- 1 lançamento de oferta (CIBE, R$ 19,80)

## Limitações da recuperação

- Código Dart AOT **não** foi descompilado (release, ofuscado)
- Telas/UX foram reescritas a partir de strings + screenshots + JSX (podem diferir em detalhes do APK)
- `adb backup` do app data falhou/cancelou (arquivo 47 bytes) — dados vieram dos JSON em Download
- Hive interno do app **não** foi lido (app não debuggable / sem root)

## Como retomar

1. Instalar Flutter SDK
2. Em `D:\EBD`: `flutter create . --project-name livro_registro --org br.com.ebd` (preserva `lib/`)
3. Ajustar `applicationId` para `br.com.ebd.livro_registro` se necessário
4. `flutter pub get && flutter run`
5. No app: Backup → Restaurar → escolher `reference/ebd-backup26-07-2026A.json`

## Artefatos de análise

- `recovery/ebd.apk` — APK puxado do aparelho
- `recovery/analysis/` — strings, screenshots, manifests
- `recovery/jadx_out/` — decompilação Java (MainActivity + canal de backup)
- `reference/` — JSX + backups JSON
