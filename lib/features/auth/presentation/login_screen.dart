// lib/features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true; // parola görünürlüğü

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _formKey.currentState?.validate();
          });
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _signInWithApple() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signInWithApple();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showResetPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();
    bool sending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            setState(() => sending = true);
            try {
              await ref.read(authControllerProvider.notifier).resetPassword(emailController.text.trim());
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şifre sıfırlama e-postası gönderildi. Gelen kutunuzu kontrol edin.')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                );
              }
            } finally {
              if (mounted) setState(() => sending = false);
            }
          }

          return AlertDialog(
            title: const Text('Şifremi Unuttum'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta'),
                validator: (value) {
                  if (value == null || !value.contains('@')) return 'Geçerli bir e-posta girin.';
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: sending ? null : submit,
                child: sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Gönder'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primary.withOpacity(0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo ve başlık
                    Column(
                      children: [
                        Image.asset('assets/images/splash.png', height: 100),
                        const SizedBox(height: 12),
                        Text('Hoş Geldin!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('Hesabına giriş yap ve kaldığın yerden devam et.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_errorMessage != null && _errorMessage!.isNotEmpty)
                                Card(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!.replaceAll('Exception: ', ''),
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Kapat',
                                          onPressed: _isLoading ? null : () => setState(() => _errorMessage = null),
                                          icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.alternate_email_rounded)),
                                validator: (value) {
                                  if (value == null || value.isEmpty || !value.contains('@')) {
                                    return 'Lütfen geçerli bir e-posta girin.';
                                  }
                                  if (_errorMessage != null) {
                                    return _errorMessage;
                                  }
                                  return null;
                                },
                                onChanged: (_) => setState(() => _errorMessage = null),
                                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Şifre',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                    tooltip: _obscurePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                                    onPressed: _isLoading
                                        ? null
                                        : () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Lütfen şifrenizi girin.';
                                  }
                                  if (_errorMessage != null) {
                                    return _errorMessage;
                                  }
                                  return null;
                                },
                                onChanged: (_) => setState(() => _errorMessage = null),
                                onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading ? null : _showResetPasswordDialog,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Şifremi Unuttum',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.login_rounded),
                                  onPressed: _isLoading ? null : _submit,
                                  label: _isLoading
                                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2))
                                      : const Text('Giriş Yap'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.5))),
                                  const SizedBox(width: 12),
                                  Text('veya', style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(width: 12),
                                  Expanded(child: Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.5))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 48,
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  elevation: 1,
                                  child: InkWell(
                                    onTap: _isLoading ? null : _signInWithGoogle,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/images/google_logo.svg',
                                            height: 24,
                                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Google ile Giriş Yap',
                            style: TextStyle(
                              color: Color(0xFF1F1F1F),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.15,
                            ),
                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 48,
                                child: SignInWithAppleButton(
                                  onPressed: _isLoading ? () {} : _signInWithApple,
                                  text: 'Apple ile Giriş Yap',
                                  height: 48,
                                  style: Theme.of(context).brightness == Brightness.dark
                                      ? SignInWithAppleButtonStyle.white
                                      : SignInWithAppleButtonStyle.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading ? null : () { context.go(AppRoutes.register); },
                      child: const Text('Hesabın yok mu? Kayıt Ol'),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
