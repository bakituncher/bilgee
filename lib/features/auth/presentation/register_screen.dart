// lib/features/auth/presentation/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePass1 = true;
  bool _obscurePass2 = true;
  bool _acceptPolicy = true; // opsiyonel: varsayılan kabul

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  double _passwordStrength(String v) {
    int score = 0;
    if (v.length >= 6) score++;
    if (v.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_+-]').hasMatch(v)) score++;
    return (score / 5).clamp(0, 1).toDouble();
  }

  void _submit() async {
    FocusScope.of(context).unfocus();

    if (!_acceptPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen şartları kabul edin.')));
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await ref.read(authControllerProvider.notifier).signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passValue = _passwordController.text;
    final strength = _passwordStrength(passValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Girişe dön',
          onPressed: () {
            if (context.canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.login);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'BilgeAi\'ye Hoş Geldin!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null && _errorMessage!.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer))),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: _isLoading ? null : () => setState(() => _errorMessage = null),
                        icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                      )
                    ]),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Adın', prefixIcon: Icon(Icons.badge_outlined)),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen adınızı girin.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.alternate_email_rounded)),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Lütfen geçerli bir e-posta girin.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePass1,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    tooltip: _obscurePass1 ? 'Şifreyi göster' : 'Şifreyi gizle',
                    onPressed: _isLoading ? null : () => setState(() => _obscurePass1 = !_obscurePass1),
                  ),
                ),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Şifre en az 6 karakter olmalıdır.';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 8),
              // Şifre gücü g��stergesi
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: strength <= 0.05 ? 0.05 : strength,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(
                    strength < .34 ? Colors.redAccent : (strength < .67 ? Colors.amber : Colors.green),
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strength < .34 ? 'Zayıf şifre' : (strength < .67 ? 'Orta şifre' : 'Güçlü şifre'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscurePass2,
                decoration: InputDecoration(
                  labelText: 'Şifre Tekrar',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    tooltip: _obscurePass2 ? 'Şifreyi göster' : 'Şifreyi gizle',
                    onPressed: _isLoading ? null : () => setState(() => _obscurePass2 = !_obscurePass2),
                  ),
                ),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Şifreler eşleşmiyor.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _isLoading ? null : _submit(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _acceptPolicy,
                    onChanged: _isLoading ? null : (v) => setState(() => _acceptPolicy = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Kullanım şartlarını ve gizlilik politikasını kabul ediyorum.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kayıt Ol'),
              ),
              TextButton(
                onPressed: _isLoading ? null : () { context.go(AppRoutes.login); },
                child: const Text('Zaten bir hesabın var mı? Giriş Yap'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
