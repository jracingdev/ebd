# Pendências EBD

Atualizado em **2026-07-27**.

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

## Restantes (dependem de você / cloud / licença)

| Item | Por quê não fecha só no código |
|---|---|
| Embutir ARA/RA/NTLH/NAA no APK | Copyright — precisa contrato SBB/detentor; até lá: API + cache (ver `docs/BIBLIA.md`) |
| Supabase / Firebase produção | `.env` real, migration, `google-services.json` / APNs |
| Sync multi-dispositivo completo | Schema existe; sync EBD ↔ cloud incompleto |
| iOS App Store | Signing Apple Developer, ícones finais, teste em Mac/Xcode, FCM/APNs |
| Backup restore na web | Precisa `file_picker` + fluxo; export via share já funciona |
| Voz TTS “studio” | Exige pacote cloud (ElevenLabs etc.) + API key |

## Como validar rápido

```bash
flutter pub get
flutter run                 # Android
flutter run -d chrome       # Web
# iOS (macOS + Xcode):
flutter run -d ios
```

Ver também: [`MULTIPLATAFORMA.md`](MULTIPLATAFORMA.md), [`BIBLIA.md`](BIBLIA.md), [`SETUP_CLOUD.md`](SETUP_CLOUD.md).
