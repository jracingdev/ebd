# Configuração cloud — Supabase e Firebase

Este guia configura o EBD para usar Supabase (autenticação, dados, roles e
Storage) e Firebase (FCM no Android). Execute os passos na ordem indicada.
Não publique o `.env`, a `service_role` key nem o `google-services.json` em
repositórios públicos.

## Checklist e ordem recomendada

- [ ] Criar o projeto Supabase e aplicar o schema.
- [ ] Ajustar a autenticação por matrícula.
- [ ] Criar o bucket de fotos e o primeiro administrador.
- [ ] Preencher `.env` e testar login.
- [ ] Publicar e testar a sincronização Betel.
- [ ] Configurar Firebase/FCM no Android.
- [ ] Publicar a Web (opcional).

## 1. Criar o projeto Supabase

1. Acesse <https://supabase.com/dashboard>, crie uma organização/projeto e
   aguarde o provisionamento.
2. Em **Project Settings > API**, copie:
   - **Project URL**;
   - a chave pública **anon** (ou **publishable**). Não use a
     `service_role` no aplicativo Flutter.
3. Em uma máquina com o Supabase CLI, autentique e vincule o projeto:

   ```bash
   supabase login
   supabase link --project-ref SEU_PROJECT_REF
   ```

   O `project-ref` aparece na URL do Dashboard e em **Project Settings >
   General**.

## 2. Aplicar as migrations

Arquivos em `supabase/migrations/`:

1. `20260727000000_init_ebd.sql` — `profiles`, roles, tabelas EBD, RLS,
   `fcm_tokens`, gatilho de perfil.
2. `20260802200000_schema_sync.sql` — `trouxe_biblia`,
   `permission_overrides`, `custom_groups`, engagement mínimo, policy de
   self-check-in na presença.

Escolha uma opção:

**Pelo Dashboard**

1. Abra **SQL Editor > New query**.
2. Cole e execute o init; em seguida a migration de schema sync.
3. Confirme que não houve erros.

**Pelo CLI** (com as migrations presentes no repositório):

```bash
supabase db push
```

## 3. Configurar Auth: matrícula e senha

O app transforma a matrícula em e-mail sintético:

```text
Matrícula 12345  →  12345@ebd.local
```

Assim, crie cada conta no Supabase Auth com esse e-mail, salvo quando houver
um e-mail real para recuperação de senha. A matrícula original fica em
`profiles.matricula`.

1. Abra **Authentication > Providers > Email**.
2. Para o fluxo atual de cadastro funcionar sem e-mail, desative **Confirm
   email**. Alternativamente, ao criar contas pelo Dashboard/API administrativa,
   marque-as como confirmadas automaticamente.
3. Mantenha login por e-mail e senha habilitado — o app faz a conversão de
   matrícula para e-mail internamente.

### Recuperação de senha

O botão de recuperação consulta `profiles.email`. Se o perfil tiver um e-mail
real, é para ele que o Supabase envia o link. Sem e-mail real, será enviado
para `matricula@ebd.local`, que não recebe mensagens fora de um domínio
controlado. Para recuperação operacional, grave o e-mail real no perfil ou
altere a senha em **Authentication > Users**.

Em produção, configure em **Authentication > URL Configuration**:

- a URL do site Web em **Site URL**;
- URLs de redirecionamento permitidas para o app/site em **Redirect URLs**.

## 4. Criar o bucket `avatars`

O schema só documenta o bucket; ele deve ser criado no Dashboard:

1. Abra **Storage > New bucket**.
2. Informe o nome exato `avatars`.
3. Escolha uma política de leitura:
   - **Público**: use somente se as fotos puderem ser públicas; URLs podem ser
     exibidas sem sessão.
   - **Privado, leitura autenticada**: recomendado para fotos de membros.
     Crie políticas para `authenticated` ler e para cada usuário gravar apenas
     sua própria pasta, por exemplo `avatars/<auth.uid()>/...`.
4. Se adotar o bucket privado, o app deve usar URL assinada para exibir fotos.

> O app atual possui o campo `foto_url`, mas ainda não envia arquivos ao
> Storage. A criação do bucket deixa a infraestrutura pronta; o upload e as
> políticas finais devem acompanhar a implementação dessa tela.

## 5. Preencher as variáveis do aplicativo

Copie o modelo e preencha valores reais:

```bash
copy .env.example .env
```

No `.env`:

```dotenv
SUPABASE_URL=https://SEU_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=SUA_CHAVE_ANON_OU_PUBLISHABLE
FIREBASE_ENABLED=false
```

Reinicie o app após alterar o arquivo. Enquanto a URL/chave estiver ausente
ou ainda contiver `YOUR_`, o aplicativo usa Hive local em vez do Supabase.

## 6. Criar o primeiro administrador

Use este procedimento antes de tentar cadastrar outros usuários pelo app:

1. Em **Authentication > Users > Add user**, crie:
   - e-mail: `admin@ebd.local` (ou outra matrícula: `MATRICULA@ebd.local`);
   - uma senha forte;
   - usuário confirmado/auto-confirmado.
2. O gatilho da migration criará uma linha em `public.profiles`. No **SQL
   Editor**, localize-a e promova-a:

   ```sql
   select id, matricula, nome, role, email
   from public.profiles
   where matricula = 'admin';

   update public.profiles
   set nome = 'Administrador', role = 'admin', ativo = true
   where matricula = 'admin';
   ```

3. Entre no app com matrícula `admin` e a senha definida no Dashboard.

Para outro administrador, troque `'admin'` pela matrícula correta. Não tente
inserir senhas diretamente em `auth.users` via SQL: use o Dashboard ou a API
Admin do Supabase.

## 7. Publicar as Edge Functions

Com o projeto vinculado, publique:

```bash
supabase functions deploy sync-betel
supabase functions deploy birthday-push
supabase functions deploy admin-users
```

As variáveis `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` normalmente são
fornecidas pelo runtime das Edge Functions. Caso o ambiente não as exponha,
defina-as apenas como secrets da função — nunca no `.env` do Flutter:

```bash
supabase secrets set SUPABASE_URL="https://SEU_PROJECT_REF.supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="SUA_SERVICE_ROLE_KEY"
supabase secrets list
```

Também é comum precisar da anon key no runtime da função `admin-users`
(para validar o JWT do chamador). Se faltar:

```bash
supabase secrets set SUPABASE_ANON_KEY="SUA_CHAVE_ANON"
```

### `admin-users`

CRUD de usuários Auth + `profiles` com **service role**, sem trocar a sessão
do admin no app. O Flutter chama `functions.invoke('admin-users')` com ações
`list`, `create`, `update`, `reset_password`. Exige que o chamador seja
`admin`, `pastor` ou `superintendente`.

### `sync-betel`

Consulta o catálogo público da Editora Betel e atualiza `betel_catalog`. O
app tenta invocá-la primeiro e lê a tabela; se falhar, faz scrape no device.
Após o deploy, teste pelo Dashboard (**Invoke**) e confira `upserted`.

### `birthday-push`: FCM HTTP v1 e agendamento

Publique e agende uma chamada diária (cron do Supabase). Com secrets Firebase,
a função envia push real via FCM HTTP v1. Sem secrets, responde
`mode: "dry_run"` e só registra no log (não falha o cron).

Secrets da service account Firebase (Project settings → Service accounts):

```bash
supabase secrets set FIREBASE_PROJECT_ID="seu-project-id"
supabase secrets set FIREBASE_CLIENT_EMAIL="firebase-adminsdk-...@....iam.gserviceaccount.com"
supabase secrets set FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

Não considere o push pronto em produção até testar em um device com token em
`fcm_tokens` e secrets válidos.

### Sync EBD no app

Com login Supabase, o menu **Sincronizar nuvem** / tela Backup envia e baixa
`students`, `attendance` (+ `trouxe_biblia`), `finances` e `editions`. Lições,
entregas de revista e engagement ainda não entram nesse sync mínimo.

## 8. Criar o projeto Firebase e habilitar FCM

1. Acesse <https://console.firebase.google.com>, crie ou selecione o projeto.
2. Adicione um app **Android** com o package exato:

   ```text
   br.com.ebd.livro_registro
   ```

3. Baixe `google-services.json` e salve em `android/app/google-services.json`.
4. Instale e execute o FlutterFire CLI na raiz do projeto:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=SEU_PROJETO_FIREBASE
   ```

   Se o CLI gerar `lib/firebase_options.dart`, mantenha-o versionado conforme
   a política do projeto. O serviço atual inicializa Firebase sem opções, por
   isso o `google-services.json` é indispensável para Android.
5. Altere o `.env`:

   ```dotenv
   FIREBASE_ENABLED=true
   ```

6. Reconstrua e instale o APK. Não basta hot reload para validar a configuração
   nativa do Firebase.

## 9. Tokens e permissões FCM no Android

- No Android 13+ o app pede a permissão de notificações durante a
  inicialização; aceite-a no dispositivo.
- Após login, o app obtém o token e tenta gravá-lo em
  `public.fcm_tokens`, associado ao `profile_id`. Verifique no Table Editor se
  a linha foi criada.
- A policy da migration permite ao usuário autenticado gravar somente tokens
  do seu próprio perfil. Se não houver linha, confira nesta ordem:
  `FIREBASE_ENABLED=true`, arquivo `google-services.json`, permissão de
  notificações, login Supabase e logs do Flutter (`FCM register failed`).
- O FCM está desativado para Web no código atual (`kIsWeb`), portanto o fluxo
  acima se aplica ao Android.

## 10. Web e Firebase Hosting (opcional)

Para executar localmente:

```bash
flutter run -d chrome
```

Para publicar no Firebase Hosting:

```bash
flutter build web --release
firebase login
firebase init hosting
firebase deploy --only hosting
```

Durante `firebase init hosting`, selecione o projeto Firebase correto e use
`build/web` como diretório público. Registre a URL gerada também em
**Authentication > URL Configuration** do Supabase, principalmente se for
usar recuperação de senha no navegador.

## 11. Modo local sem cloud

Sem `.env` válido para Supabase, o app funciona com dados locais em Hive e
semeia o primeiro usuário:

- matrícula: `admin`
- senha: `admin123`

Esse usuário é apenas para desenvolvimento. Ele não existe no Supabase, não
sincroniza dados e não deve ser tratado como acesso de produção.

## Troubleshooting rápido

| Sintoma | Verificação |
| --- | --- |
| Login usa dados locais | Confira `SUPABASE_URL`, `SUPABASE_ANON_KEY`, remova valores `YOUR_` e reinicie o app. |
| “Perfil não encontrado ou inativo” | Confirme a migration, o trigger `on_auth_user_created` e a linha correspondente em `profiles`. |
| Login falha após criar usuário | Confirme que o e-mail usado é `matricula@ebd.local` e que a conta está confirmada. |
| Reset não chega | Preencha `profiles.email` com e-mail real e configure URLs do Auth; `@ebd.local` é sintético. |
| Não cria token FCM | Verifique `google-services.json`, `FIREBASE_ENABLED=true`, permissão Android e a tabela `fcm_tokens`. |
| Função Betel falha | Veja logs em **Edge Functions**, teste a URL da Editora e confirme secrets de runtime. |
| Push de aniversário não chega | Confira secrets `FIREBASE_*`, token em `fcm_tokens` e resposta da função (`mode` / `errors`). Sem secrets a função fica em dry-run. |
| Admin não cria usuário no app | Deploy `admin-users` + migration schema sync; role do chamador deve ser staff gestor. |
