# Roles e permissões granulares

O app EBD usa **perfis (roles)** com **presets de acesso** e **overrides opcionais por usuário**.

## Onde configurar

Menu **⋮ → Gerenciar perfis** (exige permissão `manageUsers`).

Em cada usuário é possível editar:

- matrícula (só na criação), nome, senha (reset), perfil, turma, ativo/inativo
- checkboxes de **acessos granulares** (preset do perfil + overrides)

## Roles (presets)

| Role | Resumo |
|------|--------|
| **Admin** | Acesso total (overrides ignorados) |
| **Pastor** | Quase tudo, exceto sync Betel por padrão |
| **Superintendente** | Gestão completa + sync Betel |
| **Professor** | Presença, revistas, alunos, sorteio, relatório, backup; sem Ofertas/Painel |
| **Aluno** | Presença + desafios (quiz/placar/sorteios como participante) |

Não é possível desativar/rebaixar o **último admin** ativo.

## Permissões (`AppPermission`)

Definidas em `lib/data/permissions.dart`:

| Flag | Controla |
|------|----------|
| `manageUsers` | Gerenciar perfis/usuários |
| `seeFinances` | Aba Ofertas |
| `editAttendance` | Aba Presença |
| `manageMagazines` | Aba Revistas |
| `seePanel` | Aba Painel |
| `seeStudents` | Aba Alunos |
| `manageLessons` | Lições / admin de lições |
| `syncBetel` | Atualizar catálogo Betel |
| `seeAllClasses` | Navegar todas as turmas |
| `manageGroups` | Criar/remover turmas extras |
| `runSorteio` | Executar sorteios (equipe) |
| `seeDesafios` | Menu Sorteios / Quiz / Placar |
| `seeReport` | Botão Relatório |
| `backup` | Backup e restauração |

## Persistência

- Overrides ficam no JSON do usuário (`permission_overrides`) no Hive (`ebd_users_v1`).
- Backup JSON (versão ≥ 7) inclui a lista `users` (sem senhas por padrão; senhas locais existentes são preservadas na restauração).

## Resolução efetiva

`userHasPermission(user, permission)`:

1. Sem usuário → `false`
2. Role admin → `true`
3. Se houver override para a flag → usa o override
4. Senão → preset do role
