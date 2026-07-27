# Setup Supabase + Firebase

## Supabase

1. Crie um projeto em https://supabase.com
2. Rode a migration em `supabase/migrations/20260727000000_init_ebd.sql` no SQL Editor
3. Copie `.env.example` → `.env` e preencha:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
4. Deploy functions (opcional):
   ```bash
   supabase functions deploy sync-betel
   supabase functions deploy birthday-push
   ```

## Firebase (FCM)

1. Crie projeto no Firebase Console
2. Adicione app Android `br.com.ebd.livro_registro`
3. Baixe `google-services.json` → `android/app/`
4. `dart pub global activate flutterfire_cli && flutterfire configure`
5. No `.env`: `FIREBASE_ENABLED=true`

## Login local (sem cloud)

Sem `.env` válido o app usa Hive local:

- Matrícula: `admin`
- Senha: `admin123`

## Web

```bash
flutter run -d chrome
# ou
flutter build web
```
