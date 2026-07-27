import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/permissions.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  List<UserProfile> _users = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await context.read<AuthService>().listLocalUsers();
    if (!mounted) return;
    setState(() => _users = list);
  }

  List<UserProfile> get _filtered {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users
        .where(
          (u) =>
              u.nome.toLowerCase().contains(q) ||
              u.matricula.toLowerCase().contains(q) ||
              u.role.label.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _openEditor({UserProfile? existing}) async {
    final groups = context.read<AppState>().groups;
    final isNew = existing == null;
    final matricula = TextEditingController(text: existing?.matricula ?? '');
    final nome = TextEditingController(text: existing?.nome ?? '');
    final senha = TextEditingController();
    final telefone = TextEditingController(text: existing?.telefone ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    var role = existing?.role ?? UserRole.aluno;
    String? grupo = existing?.grupo ?? (groups.isEmpty ? null : groups.first);
    DateTime? aniversario = existing?.aniversario;
    var ativo = existing?.ativo ?? true;
    var effective = Map<String, bool>.from(
      existing?.effectivePermissionMap() ??
          {
            for (final p in AppPermission.values)
              p.name: rolePermissionPreset(UserRole.aluno).contains(p),
          },
    );

    void applyPreset(UserRole r, void Function(void Function()) setLocal) {
      setLocal(() {
        role = r;
        effective = {
          for (final p in AppPermission.values)
            p.name: rolePermissionPreset(r).contains(p),
        };
      });
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isNew ? 'Novo usuário' : 'Editar perfil'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: matricula,
                    enabled: isNew,
                    decoration: const InputDecoration(labelText: 'Matrícula'),
                  ),
                  TextField(
                    controller: nome,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  TextField(
                    controller: senha,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isNew ? 'Senha inicial' : 'Nova senha (opcional)',
                      helperText: isNew
                          ? null
                          : 'Deixe em branco para manter a senha atual.',
                    ),
                  ),
                  TextField(
                    controller: telefone,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                  ),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  DropdownButtonFormField<UserRole>(
                    key: ValueKey('role-$role'),
                    initialValue: role,
                    items: [
                      for (final r in UserRole.values)
                        DropdownMenuItem(value: r, child: Text(r.label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      applyPreset(v, setLocal);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Perfil (preset)',
                      helperText:
                          'Ao mudar o perfil, as permissões voltam ao preset.',
                    ),
                  ),
                  if (role == UserRole.professor ||
                      role == UserRole.aluno ||
                      grupo != null)
                    DropdownButtonFormField<String?>(
                      key: ValueKey('grupo-$grupo'),
                      initialValue: grupo,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sem turma'),
                        ),
                        for (final g in groups)
                          DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: (v) => setLocal(() => grupo = v),
                      decoration: const InputDecoration(labelText: 'Turma'),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usuário ativo'),
                    value: ativo,
                    onChanged: (v) => setLocal(() => ativo = v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      aniversario == null
                          ? 'Data de aniversário'
                          : '${aniversario!.day}/${aniversario!.month}/${aniversario!.year}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (aniversario != null)
                          IconButton(
                            tooltip: 'Limpar',
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setLocal(() => aniversario = null),
                          ),
                        const Icon(Icons.cake_outlined),
                      ],
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: aniversario ?? DateTime(2000, 1, 1),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setLocal(() => aniversario = d);
                    },
                  ),
                  const Divider(),
                  Text(
                    'Acessos granulares',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role == UserRole.admin
                        ? 'Admin tem acesso total (overrides ignorados).'
                        : 'Preset do perfil + overrides. Desmarque/marque para ajustar.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final p in AppPermission.values)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.label, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        p.description,
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: role == UserRole.admin
                          ? true
                          : (effective[p.name] ?? false),
                      onChanged: role == UserRole.admin
                          ? null
                          : (v) => setLocal(
                                () => effective[p.name] = v ?? false,
                              ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isNew ? 'Criar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final overrides = UserProfilePermissions.overridesFromEffective(
      role: role,
      effective: effective,
    );
    final auth = context.read<AuthService>();
    try {
      if (isNew) {
        if (matricula.text.trim().isEmpty ||
            nome.text.trim().isEmpty ||
            senha.text.isEmpty) {
          throw AuthException('Informe matrícula, nome e senha.');
        }
        await auth.createUser(
          matricula: matricula.text,
          nome: nome.text,
          senha: senha.text,
          role: role,
          grupo: grupo,
          telefone: telefone.text.trim().isEmpty ? null : telefone.text.trim(),
          email: email.text.trim().isEmpty ? null : email.text.trim(),
          aniversario: aniversario,
          ativo: ativo,
          permissionOverrides: overrides,
        );
      } else {
        await auth.updateUser(
          matricula: existing.matricula,
          nome: nome.text.trim(),
          role: role,
          grupo: grupo,
          clearGrupo: grupo == null,
          telefone: telefone.text.trim(),
          email: email.text.trim(),
          aniversario: aniversario,
          clearAniversario: aniversario == null,
          ativo: ativo,
          permissionOverrides: overrides,
          clearPermissionOverrides: overrides == null,
          novaSenha: senha.text.trim().isEmpty ? null : senha.text.trim(),
        );
      }
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNew ? 'Usuário criado.' : 'Perfil atualizado.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _resetPassword(UserProfile u) async {
    final senha = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nova senha — ${u.matricula}'),
        content: TextField(
          controller: senha,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nova senha'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthService>().resetUserPassword(u.matricula, senha.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha atualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;
    return Scaffold(
      appBar: const SecondaryAppBar(title: 'Gerenciar perfis'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nome, matrícula ou perfil',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${visible.length} usuário(s) · toque para editar acessos',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final u = visible[i];
                final overrideCount = u.permissionOverrides?.length ?? 0;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (u.ativo ? AppColors.green : AppColors.muted)
                        .withValues(alpha: 0.15),
                    child: Text(
                      u.nome.isEmpty ? '?' : u.nome[0].toUpperCase(),
                      style: TextStyle(
                        color: u.ativo ? AppColors.green : AppColors.muted,
                      ),
                    ),
                  ),
                  title: Text(u.nome),
                  subtitle: Text(
                    [
                      u.matricula,
                      u.role.label,
                      if (u.grupo != null) u.grupo!,
                      if (!u.ativo) 'inativo',
                      if (overrideCount > 0) '$overrideCount override(s)',
                    ].join(' · '),
                  ),
                  onTap: () => _openEditor(existing: u),
                  trailing: IconButton(
                    tooltip: 'Redefinir senha',
                    icon: const Icon(Icons.lock_reset),
                    onPressed: () => _resetPassword(u),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
