import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/features/about/about_screen.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/services/biometric_service.dart';
import 'package:livro_registro/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoggedIn});

  final VoidCallback? onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _matricula = TextEditingController();
  final _senha = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _rememberMe = false;
  String? _error;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRememberMe();
      await _prepBiometric();
    });
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  Future<void> _loadRememberMe() async {
    final auth = context.read<AuthService>();
    final remember = await auth.isRememberMeEnabled();
    final mat = await auth.rememberedMatricula();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember && mat != null && mat.isNotEmpty) {
        _matricula.text = mat;
      }
    });
  }

  Future<void> _prepBiometric() async {
    final auth = context.read<AuthService>();
    final bio = BiometricService(auth);
    final supported = await bio.isSupported;
    final enabled = await auth.isBiometricEnabled();
    if (!mounted) return;
    setState(() => _biometricAvailable = supported && enabled);
    if (!(supported && enabled)) return;
    try {
      await bio.tryBiometricLogin();
      if (auth.isLoggedIn && mounted) widget.onLoggedIn?.call();
    } on BiometricException catch (e) {
      if (e.canceled) {
        _snack('Login biométrico cancelado.');
      } else {
        _snack(e.message, error: true);
        if (mounted) setState(() => _error = e.message);
      }
    } catch (e) {
      _snack('Falha na biometria: $e', error: true);
    }
  }

  Future<void> _loginWithBiometric() async {
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await BiometricService(auth).tryBiometricLogin();
      if (auth.isLoggedIn && mounted) {
        _snack('Login biométrico realizado.');
        widget.onLoggedIn?.call();
      }
    } on BiometricException catch (e) {
      if (e.canceled) {
        _snack('Login biométrico cancelado.');
      } else {
        _snack(e.message, error: true);
        if (mounted) setState(() => _error = e.message);
      }
      // Credenciais ausentes: esconde o botão até novo login+ativação.
      final still = await auth.isBiometricEnabled();
      if (mounted) setState(() => _biometricAvailable = still);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      _snack('Falha na biometria: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      await auth.login(matricula: _matricula.text, senha: _senha.text);
      await auth.persistRememberMe(
        remember: _rememberMe,
        matricula: _matricula.text,
      );
      if (!mounted) return;
      final bio = BiometricService(auth);
      if (await bio.isSupported && !await auth.isBiometricEnabled()) {
        if (!mounted) return;
        final enable = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Usar biometria?'),
            content: const Text(
              'Deseja desbloquear o EBD com digital ou reconhecimento facial neste aparelho?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Agora não')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Ativar')),
            ],
          ),
        );
        if (enable == true) {
          try {
            await bio.enableAfterLogin();
            if (mounted) {
              setState(() => _biometricAvailable = true);
              _snack('Biometria ativada neste aparelho.');
            }
          } on BiometricException catch (e) {
            _snack(e.message, error: true);
          } catch (e) {
            _snack('Não foi possível ativar a biometria: $e', error: true);
          }
        }
      }
      widget.onLoggedIn?.call();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final mat = TextEditingController(text: _matricula.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esqueci a senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe sua matrícula. Enviaremos o lembrete/recuperação '
              'para o e-mail ou telefone cadastrado.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mat,
              decoration: const InputDecoration(labelText: 'Matrícula'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthService>().requestPasswordReset(mat.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se a matrícula existir, enviamos as instruções de recuperação. '
            '(Modo local: senha temporária gerada.)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _matricula.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                const SizedBox(height: 24),
                Text(
                  'ESCOLA BÍBLICA DOMINICAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.gold,
                    letterSpacing: 1.6,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'EBD',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Entre com sua matrícula',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _matricula,
                  decoration: const InputDecoration(
                    labelText: 'Matrícula',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senha,
                  obscureText: _obscure,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: _rememberMe,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _rememberMe = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Lembrar-me neste dispositivo'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgot,
                    child: const Text('Esqueci a senha'),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
                if (_biometricAvailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _loginWithBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Entrar com biometria'),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                    child: const Text('Sobre'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
