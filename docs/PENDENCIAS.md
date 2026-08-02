# Pendências EBD

Atualizado em **2026-08-02**.

## Fechadas neste ciclo (e ciclos recentes)

| Item | Status |
|---|---|
| Bíblia completa (66 livros) | **OK** — Almeida 1819 embutida (DP); ARA/RA/SBB/NTLH via API Midvash + cache Hive; sem tela vazia silenciosa |
| Hub Bíblia sem disclaimer longo | **OK** |
| TTS naturalizado (pt-BR, voz/velocidade) | **OK** (qualidade depende da voz do SO) |
| Editar alunos pós-restore de backup | **OK** — campos opcionais + normalização de id/grupo; form edita matrícula/telefone/aniversário/foto/turma |
| Classes custom | **OK** |
| Painel KPIs / gráficos / predições | **OK** |
| Preview PDF ofertas + relatório | **OK** |
| Pasta `ios/` + Info.plist básico | **OK** — gerada; bundle `br.com.ebd.livro_registro`; Face ID / câmera / fotos / fala |
| Backup inclui engagement (quando houver dados) | **OK** — modelo v6 + `EngagementStore` no backup |
| Sorteios / Quiz / Gamificação (base) | **OK** — hub Desafios EBD no menu; pode evoluir calibragem/UX |
| Aluno não edita chamada da turma (G05) | **OK** — preset sem `editAttendance`; UI self/read-only |
| Admin cloud via Edge `admin-users` (G02) | **OK** — create/update/list/reset com service role (deploy necessário) |
| Schema sync `trouxe_biblia` + overrides (G07) | **OK** — migration `20260802200000_schema_sync.sql` |
| Sync mínimo EBD ↔ Supabase (G01) | **OK** — `CloudSyncService` (students/attendance/finances/editions) + UI |
| FCM birthday-push além do placeholder (G03) | **OK** — HTTP v1 com secrets; dry-run explícito sem secrets |
| Restore backup web/iOS (G06) | **OK** — `file_picker` |
| Senhas Hive com hash (G04 parcial) | **OK** — sha256+salt + migração automática |
| Betel dual-path unificado (G08) | **OK** — Edge primeiro, fallback scrape, UX com fonte |

## Restantes (dependem de você / cloud / licença)

| Item | Por quê não fecha só no código |
|---|---|
| Embutir ARA/RA/NTLH/NAA no APK | Copyright — precisa contrato SBB/detentor; até lá: API + cache (ver `docs/BIBLIA.md`) |
| Supabase / Firebase produção | `.env` real, `supabase db push`, deploy das Edge Functions, `google-services.json` / APNs |
| Sync completo (lessons, delivery_records, engagement, conflitos avançados) | Camada mínima pronta; expandir entidades + política de conflito |
| iOS App Store | Signing Apple Developer, ícones finais, teste em Mac/Xcode, FCM/APNs |
| Biometria sem senha em claro no Secure Storage | Ainda guarda `last_senha` para re-login biométrico |
| Voz TTS “studio” | Exige pacote cloud (ElevenLabs etc.) + API key |

## Como validar rápido

```bash
flutter pub get
flutter run                 # Android
flutter run -d chrome       # Web
# iOS (macOS + Xcode):
flutter run -d ios
```

Ver também: [`AUDITORIA_FLUXO.md`](AUDITORIA_FLUXO.md), [`MULTIPLATAFORMA.md`](MULTIPLATAFORMA.md), [`BIBLIA.md`](BIBLIA.md), [`SETUP_CLOUD.md`](SETUP_CLOUD.md).
