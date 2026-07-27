import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/theme/app_theme.dart';

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  List<UserProfile> _users = [];

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

  Future<void> _create() async {
    final matricula = TextEditingController();
    final nome = TextEditingController();
    final senha = TextEditingController();
    final telefone = TextEditingController();
    final email = TextEditingController();
    var role = UserRole.aluno;
    String? grupo = kGroups.first;
    DateTime? aniversario;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Novo usuário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: matricula,
                    decoration: const InputDecoration(labelText: 'Matrícula')),
                TextField(
                    controller: nome,
                    decoration: const InputDecoration(labelText: 'Nome')),
                TextField(
                    controller: senha,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha inicial')),
                TextField(
                    controller: telefone,
                    decoration: const InputDecoration(labelText: 'Telefone')),
                TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'E-mail')),
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  items: [
                    for (final r in UserRole.values)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                  ],
                  onChanged: (v) => setLocal(() => role = v ?? UserRole.aluno),
                  decoration: const InputDecoration(labelText: 'Perfil'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: grupo,
                  items: [
                    for (final g in kGroups)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setLocal(() => grupo = v),
                  decoration: const InputDecoration(labelText: 'Turma'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    aniversario == null
                        ? 'Data de aniversário'
                        : '${aniversario!.day}/${aniversario!.month}/${aniversario!.year}',
                  ),
                  trailing: const Icon(Icons.cake_outlined),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime(2000, 1, 1),
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setLocal(() => aniversario = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Criar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthService>().createUser(
            matricula: matricula.text,
            nome: nome.text,
            senha: senha.text,
            role: role,
            grupo: grupo,
            telefone: telefone.text,
            email: email.text,
            aniversario: aniversario,
          );
      await _reload();
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
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context
          .read<AuthService>()
          .resetUserPassword(u.matricula, senha.text);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.person_add),
      ),
      body: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, i) {
          final u = _users[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.green.withValues(alpha: 0.15),
              child: Text(u.nome.isEmpty ? '?' : u.nome[0].toUpperCase()),
            ),
            title: Text(u.nome),
            subtitle: Text('${u.matricula} · ${u.role.label}${u.grupo == null ? '' : ' · ${u.grupo}'}'),
            trailing: IconButton(
              icon: const Icon(Icons.lock_reset),
              onPressed: () => _resetPassword(u),
            ),
          );
        },
      ),
    );
  }
}
