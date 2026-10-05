import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/providers/auth_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  bool _isRegister = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final ok = _isRegister
        ? await auth.register(_email.text.trim(), _username.text.trim(), _password.text)
        : await auth.login(_email.text.trim(), _password.text);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Bir hata oluştu')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.checkroom, size: 72, color: AppColors.ink),
                const SizedBox(height: 12),
                const Text(
                  'Dijital Dolap',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isRegister) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı adı',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.ink,
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isRegister ? 'Kayıt ol' : 'Giriş yap',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister
                        ? 'Zaten hesabın var mı? Giriş yap'
                        : 'Hesabın yok mu? Kayıt ol',
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