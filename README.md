# EBD — plataforma para Gestão de EBD

App Flutter da **Escola Bíblica Dominical** (pacote `br.com.ebd.livro_registro`) — Android + Web.

- Roles: aluno, professor, superintendente, pastor, admin
- Login por matrícula + senha, lembrete de senha, biometria (Android)
- Sync Editora Betel, 13 lições, aniversários, recibo PDF de ofertas
- Backend: Supabase + Firebase FCM

Detalhes da recuperação do APK: [`docs/AUDITORIA_RECUPERACAO.md`](docs/AUDITORIA_RECUPERACAO.md)  
Setup cloud: [`docs/SETUP_CLOUD.md`](docs/SETUP_CLOUD.md)

## Rodar

```bash
flutter pub get
flutter run
```

Demo local (sem Supabase): matrícula `admin` / senha `admin123`.

Web: `flutter run -d chrome`
