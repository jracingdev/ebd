# Multiplataforma e gaps — EBD

Status em **2026-07-27**. App Flutter (`livro_registro`) focado em **Android**; web e iOS existem em graus diferentes.

## Prontidão por plataforma

| Plataforma | Status | Notas |
|---|---|---|
| **Android** | Pronto (principal) | Biometria, FCM, backup SAF/Drive, TTS, Hive local |
| **Web** | Parcial | `web/` presente; login + shell com largura máxima; FCM/biometria/SAF desligados ou degradados |
| **iOS** | Não pronto | Pasta `ios/` **ausente**; `flutter_launcher_icons` com `ios: false`; sem Info.plist / permissões |

### Web — o que funciona / falta

- **Funciona:** UI Flutter, auth local ou Supabase (se `.env`), Bíblia (asset + API), painel, presença, etc. com limites de plugins.
- **Degradado:** backup exporta via `share_plus` (sem restaurar SAF); fotos de aluno (`FileImage`) limitadas; FCM ignorado (`kIsWeb`); biometria retorna `false`.
- **Falta para lançar com paridade razoável:** hosting + `.env` de produção, PWA/ícones revisados, restauração de backup na web (`file_picker`), FCM web opcional, testes em Chrome/Safari mobile.

### iOS — o que falta para lançar

1. `flutter create --platforms=ios .` (gerar pasta `ios/`).
2. Bundle ID, signing Apple Developer, ícones (`ios: true` no launcher).
3. Info.plist: câmera/fotos, Face ID (`NSFaceIDUsageDescription`), rede.
4. Validar `local_auth`, `flutter_tts`, `path_provider`, Hive, Supabase.
5. FCM iOS (APNs + `GoogleService-Info.plist`) se notificações forem requisito.
6. Backup: SAF é Android-only; iOS precisa de share/Files (export já usa `share_plus` fora do Android).

## TTS (leitura da Bíblia)

- Motor: `flutter_tts` (voz do **SO** — não é áudio gravado).
- Melhorias no app: `pt-BR`, rate ~0,42, pitch 0,98, escolha automática de voz pt-BR feminina/neural se existir, pausas entre versículos, chunks por frase, UI de voz/velocidade.
- **Limite:** robótico se o aparelho só tiver voz básica. Usuário pode instalar vozes melhores:
  - **Android:** Configurações → Sistema → Idiomas → Saída de texto para voz → Google → baixar voz pt-BR de alta qualidade.
  - **iOS:** Acessibilidade → Conteúdo falado → Vozes → Português (Brasil).
- Pacotes cloud (ElevenLabs etc.) aumentam naturalidade, mas exigem API key, custo e complexidade — fora do escopo atual.

## Gaps vs visão EBD (P0 / P1 / P2)

### P0 — bloqueantes / risco alto

| Gap | Detalhe |
|---|---|
| Supabase em produção | Sem `.env` real + migration aplicada, auth/roles/sync ficam só no Hive demo |
| Copyright Bíblia moderna | ARA/RA/SBB/NTLH via API + cache; embutir no APK exige licença SBB (ver `docs/BIBLIA.md`). Só Almeida 1819 é DP embutido |
| iOS inexistente | Sem pasta `ios/`, não há build App Store |
| FCM produção | Precisa `google-services.json` + projeto Firebase configurado |

### P1 — importantes para paridade

| Gap | Detalhe |
|---|---|
| Sync multi-dispositivo | Dados EBD ainda centrados em Hive local; Supabase schema existe, sync completo incompleto |
| Backup web/iOS | Export ok via share; restore SAF só Android |
| Biometria iOS | Código já trata `Platform.isIOS`, mas sem projeto iOS |
| Responsividade | Shell home/login/bíblia com max-width; várias views internas ainda “mobile-first” densas |
| Betel sync | Serviço presente; depende de cloud/edge function publicada |
| Alunos/fotos na web | Caminhos de arquivo locais não mapeiam bem no browser |

### P2 — desejáveis

| Gap | Detalhe |
|---|---|
| Notificações web | FCM web / service worker |
| Offline completo de versões modernas | Download capítulo a capítulo; progresso parcial possível |
| Admin avançado | Convites, auditoria, reset de senha robusto com e-mail real |
| Testes automatizados | Cobertura mínima (`widget_test`) |
| Acessibilidade / Dark mode | Não priorizado |

## Correções rápidas feitas neste ciclo

- TTS naturalizado + UI voz/velocidade na Bíblia.
- `ResponsiveShell` no home e hub/reader da Bíblia.
- Backup: export via share fora do Android; UI não oferece restore SAF na web.
- Manifest Android: query `TTS_SERVICE` para listar vozes.
- `web/index.html` título/descrição EBD.

## Como rodar

```bash
flutter pub get
flutter run                 # Android
flutter run -d chrome       # Web
# iOS (após gerar plataforma):
flutter create --platforms=ios .
flutter run -d ios
```

Ver também: [`SETUP_CLOUD.md`](SETUP_CLOUD.md), [`BIBLIA.md`](BIBLIA.md), [`AUDITORIA_RECUPERACAO.md`](AUDITORIA_RECUPERACAO.md).
