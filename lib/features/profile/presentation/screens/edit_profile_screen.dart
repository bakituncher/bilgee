import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/profile/application/profile_controller.dart';
import 'package:intl/intl.dart';
import 'package:taktik/shared/widgets/custom_date_picker.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';
import 'package:flutter/services.dart'; // InputFormatter için gerekli

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;
  late TextEditingController _dateOfBirthController;

  String? _selectedGender;
  DateTime? _selectedDate;
  String? _usernameError;
  bool _isCheckingUsername = false;

  // Form değişikliği kontrolü için orijinal değerler
  String? _originalFirstName;
  String? _originalLastName;
  String? _originalUsername;
  String? _originalGender;
  DateTime? _originalDateOfBirth;
  bool _formIsDirty = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _usernameController = TextEditingController();
    _dateOfBirthController = TextEditingController();

    // Değişiklikleri dinle
    _firstNameController.addListener(_checkFormDirty);
    _lastNameController.addListener(_checkFormDirty);
    _usernameController.addListener(_checkFormDirty);
  }

  /// Form'un orijinal halinden farklı olup olmadığını kontrol eder
  void _checkFormDirty() {
    final isDirty = _firstNameController.text.trim() != (_originalFirstName ?? '') ||
        _lastNameController.text.trim() != (_originalLastName ?? '') ||
        _usernameController.text.trim() != (_originalUsername ?? '') ||
        _selectedGender != _originalGender ||
        _selectedDate != _originalDateOfBirth;

    if (isDirty != _formIsDirty) {
      setState(() {
        _formIsDirty = isDirty;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  /// Karakter sayacı
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

  void _loadUserData(UserModel user) {
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _usernameController.text = user.username;
    _selectedGender = user.gender;
    _selectedDate = user.dateOfBirth;
    if (user.dateOfBirth != null) {
      _dateOfBirthController.text = DateFormat('dd/MM/yyyy').format(user.dateOfBirth!);
    }

    // Orijinal değerleri kaydet
    _originalFirstName = user.firstName;
    _originalLastName = user.lastName;
    _originalUsername = user.username;
    _originalGender = user.gender;
    _originalDateOfBirth = user.dateOfBirth;
    _formIsDirty = false;
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusScope.of(context).unfocus(); // Klavyeyi kapat
    final now = DateTime.now();

    final DateTime? picked = await CustomDatePicker.show(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1920),
      lastDate: now,
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateOfBirthController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _checkFormDirty(); // Tarih değiştiğinde dirty check tetikle
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newUsername = _usernameController.text.trim();

    // Sadece kullanıcı adı değişmişse müsaitlik kontrolü yap
    if (newUsername != _originalUsername) {
      setState(() {
        _isCheckingUsername = true;
        _usernameError = null;
      });

      final isAvailable = await ref.read(profileControllerProvider.notifier).checkUsernameAvailability(newUsername);

      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
        });
      }

      if (!isAvailable) {
        setState(() {
          _usernameError = 'Bu kullanıcı adı zaten alınmış.';
        });
        _formKey.currentState!.validate(); // Hatayı ekranda göstermek için
        return;
      }
    }

    // Güncelleme işlemini başlat
    await ref.read(profileControllerProvider.notifier).updateUserProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      gender: _selectedGender,
      dateOfBirth: _selectedDate,
      username: newUsername,
    );
  }

  @override
  Widget build(BuildContext context) {
    // İşlem sonucunu dinle (Success/Error)
    ref.listen<AsyncValue<void>>(profileControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${error.toString()}')),
          );
        },
        data: (_) {
          if (previous is AsyncLoading) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profil başarıyla güncellendi!')),
            );
            Navigator.pop(context);
          }
        },
      );
    });

    final userProfileAsync = ref.watch(userProfileProvider);
    final profileUpdateState = ref.watch(profileControllerProvider);
    final isLoading = profileUpdateState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilimi Düzenle'),
        leading: const CustomBackButton(),
      ),
      body: userProfileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text("Kullanıcı bulunamadı."));
          }
          // Controller'ları sadece ilk açılışta doldur
          if (_firstNameController.text.isEmpty && _lastNameController.text.isEmpty && !_formIsDirty) {
            _loadUserData(user);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- KULLANICI ADI ALANI ---
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      prefixIcon: const Icon(Icons.alternate_email),
                      // Yükleniyor ikonu (kontrol sırasında)
                      suffixIcon: _isCheckingUsername
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : null,
                      // Karakter sayacı (kontrol yoksa göster)
                      suffixText: _isCheckingUsername ? null : _getCharacterCountText(_usernameController, 30),
                      suffixStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getCharacterCountColor(context, _usernameController, 30),
                      ),
                      errorText: _usernameError,
                    ),
                    // BOŞLUK ENGELLEME ÖZELLİĞİ
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    maxLength: 30,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    onChanged: (value) {
                      // Hata varsa kullanıcı yazarken temizle
                      if (_usernameError != null) {
                        setState(() {
                          _usernameError = null;
                        });
                      }
                      // Dirty check zaten listener ile yapılıyor
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen bir kullanıcı adı girin.';
                      }
                      if (value.contains(' ')) {
                        return 'Kullanıcı adı boşluk içeremez.';
                      }
                      if (value.length < 3) {
                        return 'Kullanıcı adı en az 3 karakter olmalıdır.';
                      }
                      if (value.length > 30) {
                        return 'Kullanıcı adı en fazla 30 karakter olabilir.';
                      }
                      // Sadece harf, rakam ve alt çizgi kontrolü
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'Sadece harf, rakam ve alt çizgi kullanın.';
                      }
                      if (_usernameError != null) {
                        return _usernameError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- AD & SOYAD ---
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            labelText: 'Ad',
                            prefixIcon: const Icon(Icons.person_outline),
                            suffixText: _getCharacterCountText(_firstNameController, 50),
                            suffixStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getCharacterCountColor(context, _firstNameController, 50),
                            ),
                          ),
                          maxLength: 50,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Lütfen adınızı girin.';
                            if (value.length > 50) return 'Ad çok uzun.';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Soyad',
                            prefixIcon: const Icon(Icons.person_outline),
                            suffixText: _getCharacterCountText(_lastNameController, 50),
                            suffixStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getCharacterCountColor(context, _lastNameController, 50),
                            ),
                          ),
                          maxLength: 50,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Lütfen soyadınızı girin.';
                            if (value.length > 50) return 'Soyad çok uzun.';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- CİNSİYET & DOĞUM TARİHİ ---
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
                            _checkFormDirty();
                          },
                          validator: (value) => value == null ? 'Lütfen cinsiyet seçin.' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _dateOfBirthController,
                          decoration: const InputDecoration(
                            labelText: 'Doğum Tarihi',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context),
                          validator: (value) => (value == null || value.isEmpty) ? 'Tarih seçin.' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- KAYDET BUTONU ---
                  ElevatedButton(
                    // Loading ise veya formda değişiklik yoksa disable et
                    onPressed: (isLoading || !_formIsDirty) ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(_formIsDirty ? 'Değişiklikleri Kaydet' : 'Değişiklik Yapılmadı'),
                  ),

                  // Kullanıcıya bilgi mesajı
                  if (!_formIsDirty && !isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Değişiklik yapmadan kaydedemezsiniz',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Bir hata oluştu: $error')),
      ),
    );
  }
}