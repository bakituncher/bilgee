// lib/features/auth/presentation/register_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:taktik/shared/widgets/custom_date_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dateOfBirthController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDate;

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePass1 = true;
  bool _obscurePass2 = true;
  bool _acceptPolicy = true;

  // İki aşamalı kayıt için
  bool _showEmailForm = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dateOfBirthController.dispose();
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

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final thirteenYearsAgo = DateTime(now.year - 13, now.month, now.day);
    final DateTime? picked = await CustomDatePicker.show(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1920),
      lastDate: thirteenYearsAgo,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateOfBirthController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _submit() async {
    FocusScope.of(context).unfocus();

    if (!_acceptPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen şartları kabul edin.')));
      return;
    }

    if (_formKey.currentState!.validate()) {
      // iOS kullanıcıları için doğum tarihi zorunlu değil
      final isIOS = Platform.isIOS;
      if (!isIOS || _selectedDate != null) {
        final now = DateTime.now();
        final thirteenYearsAgo = DateTime(now.year - 13, now.month, now.day);
        if (_selectedDate != null && _selectedDate!.isAfter(thirteenYearsAgo)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kayıt olmak için 13 yaşından büyük olmalısınız.')),
          );
          return;
        }
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await ref.read(authControllerProvider.notifier).signUp(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          username: _usernameController.text.trim(),
          gender: _selectedGender,
          dateOfBirth: _selectedDate,
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          context.go(AppRoutes.verifyEmail);
        }
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

  @override
  Widget build(BuildContext context) {
    final passValue = _passwordController.text;
    final strength = _passwordStrength(passValue);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Cihazın alt güvenli alan boşluğunu alıyoruz
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showEmailForm ? 'Kayıt Ol' : 'Hesap Oluştur'),
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: _showEmailForm ? 'Geri dön' : 'Girişe dön',
          onPressed: () {
            if (_showEmailForm) {
              setState(() {
                _showEmailForm = false;
                _errorMessage = null;
              });
            } else {
              if (context.canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go(AppRoutes.login);
              }
            }
          },
        ),
      ),
      body: _showEmailForm
          ? _buildEmailForm(context, passValue, strength, isDarkMode, bottomPadding)
          : _buildMethodSelection(context, isDarkMode, bottomPadding),
    );
  }

  Widget _buildMethodSelection(BuildContext context, bool isDarkMode, double bottomPadding) {
    return SingleChildScrollView(
      // Alt kısma güvenli alan boşluğu ekliyoruz
      padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Logo veya İkon
          Container(
            height: 100,
            width: 100,
            alignment: Alignment.center,
            child: Icon(
              Icons.account_circle_rounded,
              size: 100,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Taktik\'e Hoş Geldin!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Hesabını oluşturmak için bir yöntem seç',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Hata mesajı
          if (_errorMessage != null && _errorMessage!.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
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

          // E-posta ile Devam Et Butonu
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.email_outlined, size: 24),
              onPressed: _isLoading ? null : () {
                setState(() {
                  _showEmailForm = true;
                  _errorMessage = null;
                });
              },
              label: const Text(
                'E-posta ile Devam Et',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'veya',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(height: 16),

          // Google ile Devam Et
          SizedBox(
            height: 56,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 1,
              child: InkWell(
                onTap: _isLoading ? null : _signInWithGoogle,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 56,
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
                        'Google ile Devam Et',
                        style: TextStyle(
                          color: Color(0xFF1F1F1F),
                          fontSize: 20,
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

          // Apple ile Devam Et
          SizedBox(
            height: 56,
            child: Opacity(
              opacity: _isLoading ? 0.6 : 1.0,
              child: AbsorbPointer(
                absorbing: _isLoading,
                child: SignInWithAppleButton(
                  onPressed: _signInWithApple,
                  text: 'Apple ile Devam Et',
                  height: 56,
                  style: isDarkMode
                      ? SignInWithAppleButtonStyle.white
                      : SignInWithAppleButtonStyle.black,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Zaten hesabın var mı?
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Zaten bir hesabın var mı?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: _isLoading ? null : () {
                  context.go(AppRoutes.login);
                },
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Politika metni
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                children: [
                  const TextSpan(text: 'Devam ederek '),
                  TextSpan(
                    text: 'Kullanım Sözleşmesi',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        const url = 'https://www.codenzi.com/taktik-kullanim-sozlesmesi.html';
                        final uri = Uri.parse(url);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link açılamadı')),
                            );
                          }
                        }
                      },
                  ),
                  const TextSpan(text: ' ve '),
                  TextSpan(
                    text: 'Gizlilik Politikası',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        const url = 'https://www.codenzi.com/taktik-gizlilik-politikasi.html';
                        final uri = Uri.parse(url);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link açılamadı')),
                            );
                          }
                        }
                      },
                  ),
                  const TextSpan(text: "'nı kabul etmiş olursunuz."),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(BuildContext context, String passValue, double strength, bool isDarkMode, double bottomPadding) {
    return SingleChildScrollView(
      // Alt kısma güvenli alan boşluğu ekliyoruz
      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bilgilerini Tamamla',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Hesabını oluşturmak için aşağıdaki bilgileri doldur',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'Ad', prefixIcon: Icon(Icons.person_outline)),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen adınızı girin.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Soyad', prefixIcon: Icon(Icons.person_outline)),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen soyadınızı girin.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Kullanıcı Adı', prefixIcon: Icon(Icons.alternate_email)),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen bir kullanıcı adı girin.';
                }
                if (value.length < 3) {
                  return 'Kullanıcı adı en az 3 karakter olmalıdır.';
                }
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cinsiyet',
                      prefixIcon: Icon(Icons.wc_outlined),
                    ),
                    items: ['Erkek', 'Kadın', 'Belirtmek istemiyorum']
                        .map((label) => DropdownMenuItem(
                      value: label,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Lütfen cinsiyetinizi seçin.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dateOfBirthController,
                    decoration: InputDecoration(
                      labelText: Platform.isIOS ? 'Doğum Tarihi (Opsiyonel)' : 'Doğum Tarihi',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    validator: (value) {
                      // iOS kullanıcıları için doğum tarihi zorunlu değil
                      if (Platform.isIOS) {
                        return null;
                      }
                      if (value == null || value.isEmpty) {
                        return 'Lütfen doğum tarihinizi seçin.';
                      }
                      return null;
                    },
                  ),
                ),
              ],
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
            // Şifre gücü göstergesi
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: strength <= 0.05 ? 0.05 : strength,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: 'Kullanım Sözleşmesi',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              const url = 'https://www.codenzi.com/taktik-kullanim-sozlesmesi.html';
                              final uri = Uri.parse(url);
                              try {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Link açılamadı')),
                                  );
                                }
                              }
                            },
                        ),
                        const TextSpan(text: ' ve '),
                        TextSpan(
                          text: 'Gizlilik Politikası',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              const url = 'https://www.codenzi.com/taktik-gizlilik-politikasi.html';
                              final uri = Uri.parse(url);
                              try {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Link açılamadı')),
                                  );
                                }
                              }
                            },
                        ),
                        const TextSpan(text: "'nı kabul ediyorum."),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.onPrimary,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Kayıt Ol',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Zaten bir hesabın var mı?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: _isLoading ? null : () {
                    context.go(AppRoutes.login);
                  },
                  child: const Text(
                    'Giriş Yap',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}