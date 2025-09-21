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
  final _dateController = TextEditingController();
  String? _gender;
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  String? _usernameError;

  @override
  void dispose() {
    _usernameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    // Reset previous error
    setState(() => _usernameError = null);

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final firestoreService = ref.read(firestoreServiceProvider);
      final userId = ref.read(authControllerProvider).value!.uid;

      final isAvailable = await firestoreService.checkUsernameAvailability(_usernameController.text.trim());
      if (!isAvailable) {
        if (mounted) {
          setState(() {
            _usernameError = 'Bu kullanıcı adı zaten alınmış.';
            _isLoading = false;
          });
          _formKey.currentState!.validate();
        }
        return;
      }

      try {
        await firestoreService.updateUserProfileDetails(
          userId: userId,
          username: _usernameController.text.trim(),
          gender: _gender!,
          dateOfBirth: _dateOfBirth!,
        );
        // On success, the router will automatically redirect
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil güncellenemedi: ${e.toString()}')),
          );
          setState(() => _isLoading = false);
        }
      }
      // No need for a finally block to set isLoading to false if navigation happens on success
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)), // Min 10 years old
      helpText: 'Doğum Tarihini Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
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
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
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
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Kullanıcı Adı',
                                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                                  errorText: _usernameError,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Lütfen bir kullanıcı adı girin.';
                                  if (value.length < 3) return 'Kullanıcı adı en az 3 karakter olmalı.';
                                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                                    return 'Sadece harf, rakam ve alt çizgi kullanın.';
                                  }
                                  if (_usernameError != null) return _usernameError;
                                  return null;
                                },
                                onChanged: (_) {
                                  if (_usernameError != null) setState(() => _usernameError = null);
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _gender,
                                decoration: const InputDecoration(
                                  labelText: 'Cinsiyet',
                                  prefixIcon: Icon(Icons.wc_rounded),
                                ),
                                items: ['Erkek', 'Kadın', 'Diğer']
                                    .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                                    .toList(),
                                onChanged: (value) => setState(() => _gender = value),
                                validator: (value) => value == null ? 'Lütfen cinsiyetinizi seçin.' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Doğum Tarihi',
                                  prefixIcon: Icon(Icons.calendar_today_rounded),
                                ),
                                onTap: () => _selectDate(context),
                                validator: (value) => _dateOfBirth == null ? 'Lütfen doğum tarihinizi seçin.' : null,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  child: _isLoading
                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
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
