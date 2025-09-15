import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/profile/application/profile_controller.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _usernameController = TextEditingController();
    _dateOfBirthController = TextEditingController();
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
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateOfBirthController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
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
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isLoading ? null : _submit,
          ),
        ],
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
                          value: _selectedGender,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Cinsiyet',
                            prefixIcon: Icon(Icons.wc_outlined),
                          ),
                          items: ['Erkek', 'Kadın', 'Belirtmek istemiyorum']
                              .map((label) => DropdownMenuItem(
                            child: Text(label, overflow: TextOverflow.ellipsis),
                            value: label,
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
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Değişiklikleri Kaydet'),
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
