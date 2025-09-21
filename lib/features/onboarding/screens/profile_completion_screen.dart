import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:intl/intl.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  String? _gender;
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  String? _usernameError;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final firestoreService = ref.read(firestoreServiceProvider);
      final userId = ref.read(authControllerProvider).value!.uid;

      // Check username availability
      final isAvailable = await firestoreService.checkUsernameAvailability(_usernameController.text.trim());
      if (!isAvailable) {
        setState(() {
          _usernameError = 'Bu kullanıcı adı zaten alınmış.';
          _isLoading = false;
        });
        _formKey.currentState!.validate();
        return;
      }

      try {
        await firestoreService.updateUserProfileDetails(
          userId: userId,
          username: _usernameController.text.trim(),
          gender: _gender!,
          dateOfBirth: _dateOfBirth!,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil güncellenemedi: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != _dateOfBirth) {
      setState(() {
        _dateOfBirth = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilini Tamamla'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  errorText: _usernameError,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen bir kullanıcı adı girin.';
                  }
                  if (_usernameError != null) {
                    return _usernameError;
                  }
                  return null;
                },
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Cinsiyet'),
                items: ['Erkek', 'Kadın', 'Diğer']
                    .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _gender = value;
                  });
                },
                validator: (value) => value == null ? 'Lütfen cinsiyetinizi seçin.' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_dateOfBirth == null
                    ? 'Doğum Tarihi Seç'
                    : 'Doğum Tarihi: ${DateFormat.yMd().format(_dateOfBirth!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
