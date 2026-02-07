import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:taktik/shared/widgets/custom_date_picker.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _dateController = TextEditingController();

  String? _gender;
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  String? _usernameError;
  bool _acceptPolicy = false;

  @override
  void initState() {
    super.initState();
    // Ekran açıldığında mevcut verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _loadUserData() {
    final user = ref.read(authControllerProvider).value;
    if (user != null) {
      final userProfile = ref.read(userProfileProvider).value;
      if (userProfile != null) {
        // Eğer kullanıcı adı varsa (otomatik oluşturulan) kutuya doldur
        if (userProfile.username.isNotEmpty && _usernameController.text.isEmpty) {
          _usernameController.text = userProfile.username;
        }
        if (userProfile.gender != null && _gender == null) {
          setState(() {
            _gender = userProfile.gender;
          });
        }
        if (userProfile.dateOfBirth != null && _dateOfBirth == null) {
          setState(() {
            _dateOfBirth = userProfile.dateOfBirth;
            _dateController.text = DateFormat.yMMMMd('tr_TR').format(userProfile.dateOfBirth!);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// Karakter sayacı - kalan karakter sayısını döndürür
  String? _getCharacterCountText(TextEditingController controller, int maxLength) {
    final currentLength = controller.text.length;
    final threshold = (maxLength * 0.7).toInt();
    if (currentLength < threshold) return null;
    return '${maxLength - currentLength}';
  }

  Color _getCharacterCountColor(BuildContext context, TextEditingController controller, int maxLength) {
    final remaining = maxLength - controller.text.length;
    if (remaining <= 0) return Theme.of(context).colorScheme.error;
    if (remaining <= 5) return Colors.orange;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    // Önceki hataları temizle
    setState(() => _usernameError = null);

    // 1. Sözleşme Kontrolü
    if (!_acceptPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen kullanım şartlarını ve gizlilik politikasını kabul edin.')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // 2. Yaş Kontrolü (iOS hariç)
      final isIOS = Platform.isIOS;
      if (!isIOS || _dateOfBirth != null) {
        final now = DateTime.now();
        final thirteenYearsAgo = DateTime(now.year - 13, now.month, now.day);
        if (_dateOfBirth != null && _dateOfBirth!.isAfter(thirteenYearsAgo)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kayıt olmak için 13 yaşından büyük olmalısınız.')),
          );
          return;
        }
      }

      setState(() => _isLoading = true);

      final firestoreService = ref.read(firestoreServiceProvider);
      final userId = ref.read(authControllerProvider).value!.uid;
      final newUsername = _usernameController.text.trim();

      // 3. Kullanıcı Adı Müsaitlik Kontrolü
      // excludeUserId parametresi sayesinde, kullanıcı kendi ismini değiştirmeden
      // kaydetmeye çalışırsa hata almaz.
      final isAvailable = await firestoreService.checkUsernameAvailability(
        newUsername,
        excludeUserId: userId,
      );

      if (!isAvailable) {
        if (mounted) {
          setState(() {
            _usernameError = 'Bu kullanıcı adı zaten alınmış.';
            _isLoading = false;
          });
          // Formu tekrar validate ederek hatayı input altında göster
          _formKey.currentState!.validate();
        }
        return;
      }

      // 4. Profil Güncelleme İşlemi
      try {
        await firestoreService.updateUserProfileDetails(
          userId: userId,
          username: newUsername,
          gender: _gender!,
          dateOfBirth: _dateOfBirth,
        );
        // Başarılı olduğunda yönlendirme (Router) otomatik devreye girecektir.
        // Ancak yine de loading'i kapatmıyoruz ki geçiş sırasında buton tekrar tıklanmasın.
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil güncellenemedi: ${e.toString()}')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    // Kullanıcı en az 13 yaşında olmalı kuralı için üst sınır
    final thirteenYearsAgo = DateTime(now.year - 13, now.month, now.day);

    final pickedDate = await CustomDatePicker.show(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(1950),
      lastDate: thirteenYearsAgo,
    );

    if (pickedDate != null && pickedDate != _dateOfBirth) {
      setState(() {
        _dateOfBirth = pickedDate;
        _dateController.text = DateFormat.yMMMMd('tr_TR').format(pickedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.primary.withOpacity(0.08),
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
                    Text(
                      'Son Bir Adım!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hesabını kişiselleştirmek ve sana özel bir deneyim sunabilmemiz için bu bilgilere ihtiyacımız var.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // KULLANICI ADI GİRİŞİ
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Kullanıcı Adı',
                                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                                  suffixText: _getCharacterCountText(_usernameController, 30),
                                  suffixStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getCharacterCountColor(context, _usernameController, 30),
                                  ),
                                  errorText: _usernameError,
                                  helperText: 'Benzersiz bir isim seçin',
                                ),
                                maxLength: 30,
                                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Lütfen bir kullanıcı adı girin.';
                                  if (value.length < 3) return 'Kullanıcı adı en az 3 karakter olmalı.';
                                  if (value.length > 30) return 'Kullanıcı adı en fazla 30 karakter olabilir.';
                                  // Sadece harf, rakam ve alt çizgiye izin ver
                                  if (!RegExp(r'^[a-z0-9_]+$', caseSensitive: false).hasMatch(value)) {
                                    return 'Sadece harf, rakam ve alt çizgi kullanın.';
                                  }
                                  if (_usernameError != null) return _usernameError;
                                  return null;
                                },
                                onChanged: (_) {
                                  setState(() {});
                                  // Kullanıcı yazmaya başladığında hata mesajını temizle
                                  if (_usernameError != null) setState(() => _usernameError = null);
                                },
                              ),
                              const SizedBox(height: 16),

                              // CİNSİYET SEÇİMİ
                              DropdownButtonFormField<String>(
                                initialValue: _gender,
                                decoration: const InputDecoration(
                                  labelText: 'Cinsiyet',
                                  prefixIcon: Icon(Icons.wc_rounded),
                                ),
                                items: ['Erkek', 'Kadın', 'Belirtmek istemiyorum']
                                    .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                                    .toList(),
                                onChanged: (value) => setState(() => _gender = value),
                                validator: (value) => value == null ? 'Lütfen cinsiyetinizi seçin.' : null,
                              ),
                              const SizedBox(height: 16),

                              // DOĞUM TARİHİ SEÇİMİ
                              TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: Platform.isIOS ? 'Doğum Tarihi (Opsiyonel)' : 'Doğum Tarihi',
                                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                                ),
                                onTap: () => _selectDate(context),
                                validator: (value) {
                                  // iOS kullanıcıları için opsiyonel
                                  if (Platform.isIOS) {
                                    return null;
                                  }
                                  return _dateOfBirth == null ? 'Lütfen doğum tarihinizi seçin.' : null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // SÖZLEŞME ONAYI
                              Row(
                                children: [
                                  Checkbox(
                                    value: _acceptPolicy,
                                    onChanged: _isLoading ? null : (value) => setState(() => _acceptPolicy = value ?? false),
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: theme.textTheme.bodySmall,
                                        children: [
                                          TextSpan(
                                            text: 'Kullanım Sözleşmesi',
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
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
                                              color: theme.colorScheme.primary,
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

                              // KAYDET BUTONU
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  child: _isLoading
                                      ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        color: theme.colorScheme.onPrimary,
                                        strokeWidth: 2.5
                                    ),
                                  )
                                      : const Text('Profili Tamamla'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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