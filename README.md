# EBD — plataforma para Gestão de EBD

App Flutter da **Escola Bíblica Dominical** (pacote `br.com.ebd.livro_registro`) — Android + Web (parcial); iOS ainda não gerado.

- Roles: aluno, professor, superintendente, pastor, admin
- Login por matrícula + senha, lembrete de senha, biometria (Android; iOS quando a pasta `ios/` existir)
- Sync Editora Betel, 13 lições, aniversários, recibo PDF de ofertas
- Backend: Supabase + Firebase FCM
- Bíblia EBD com TTS (voz do sistema) e preferências de velocidade/voz

Detalhes da recuperação do APK: [`docs/AUDITORIA_RECUPERACAO.md`](docs/AUDITORIA_RECUPERACAO.md)  
Setup cloud: [`docs/SETUP_CLOUD.md`](docs/SETUP_CLOUD.md)  
Web / iOS / gaps: [`docs/MULTIPLATAFORMA.md`](docs/MULTIPLATAFORMA.md)

## Rodar

```bash
flutter pub get
flutter run
```

Demo local (sem Supabase): matrícula `admin` / senha `admin123`.

Web: `flutter run -d chrome`
