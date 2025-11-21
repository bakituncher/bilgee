import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/profile/application/profile_controller.dart';
import 'package:intl/intl.dart';
import 'package:taktik/shared/widgets/custom_date_picker.dart';

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

  // ÇÖZÜM: Original değerleri sakla (form dirty check için)
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

    // Listener'lar ekle - form değişikliklerini izle
    _firstNameController.addListener(_checkFormDirty);
    _lastNameController.addListener(_checkFormDirty);
    _usernameController.addListener(_checkFormDirty);
  }

  /// ÇÖZÜM: Form'un değişip değişmediğini kontrol et
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

  void _loadUserData(UserModel user) {
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _usernameController.text = user.username;
    _selectedGender = user.gender;
    _selectedDate = user.dateOfBirth;
    if (user.dateOfBirth != null) {
      _dateOfBirthController.text = DateFormat('dd/MM/yyyy').format(user.dateOfBirth!);
    }

    // ÇÖZÜM: Original değerleri kaydet
    _originalFirstName = user.firstName;
    _originalLastName = user.lastName;
    _originalUsername = user.username;
    _originalGender = user.gender;
    _originalDateOfBirth = user.dateOfBirth;
    _formIsDirty = false;
  }

  Future<void> _selectDate(BuildContext context) async {
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
      _checkFormDirty(); // ÇÖZÜM: Tarih değiştiğinde dirty check yap
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(profileControllerProvider.notifier).updateUserProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _selectedGender,
        dateOfBirth: _selectedDate,
        username: _usernameController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Profil ekranına geri dön
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
      ),
      body: userProfileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text("Kullanıcı bulunamadı."));
          }
          // This ensures that the text fields are not re-initialized on every build
          if (_firstNameController.text.isEmpty && _lastNameController.text.isEmpty) {
            _loadUserData(user);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen bir kullanıcı adı girin.';
                      }
                      if (value.length < 3) {
                        return 'Kullanıcı adı en az 3 karakter olmalıdır.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: 'Ad', prefixIcon: Icon(Icons.person_outline)),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen adınızı girin.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: 'Soyad', prefixIcon: Icon(Icons.person_outline)),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen soyadınızı girin.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                            _checkFormDirty(); // ÇÖZÜM: Cinsiyet değiştiğinde dirty check
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
                          decoration: const InputDecoration(
                            labelText: 'Doğum Tarihi',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen doğum tarihinizi seçin.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    // ÇÖZÜM: Sadece form dirty ve loading değilse aktif
                    onPressed: (isLoading || !_formIsDirty) ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_formIsDirty ? 'Değişiklikleri Kaydet' : 'Değişiklik Yapılmadı'),
                  ),
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
