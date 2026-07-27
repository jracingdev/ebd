# EBD — plataforma para Gestão de EBD

App Flutter da **Escola Bíblica Dominical** (pacote `br.com.ebd.livro_registro`) — Android + Web.

Projeto recuperado a partir do APK + backups JSON + protótipo JSX. Detalhes em [`docs/AUDITORIA_RECUPERACAO.md`](docs/AUDITORIA_RECUPERACAO.md).

## Rodar

```bash
flutter pub get
flutter run
```

Para restaurar os dados do aparelho: no app, **Backup → Restaurar** e escolha `reference/ebd-backup26-07-2026A.json`.

## Stack

- Flutter (Android + Web)
- Supabase (Postgres, Auth, Storage)
- Firebase (FCM push)
