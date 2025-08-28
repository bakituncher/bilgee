// lib/features/onboarding/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Yönlendirme için eklendi
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _goalController = TextEditingController();

  double _weeklyStudyGoal = 10.0;
  final Map<String, bool> _challenges = {
    'Konu eksiği': false,
    'Zaman yönetimi': false,
    'Stres': false,
    'Soru pratiği': false,
  };

  bool _isLoading = false;

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final userId = ref.read(authControllerProvider).value!.uid;
      final selectedChallenges = _challenges.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      try {
        await ref.read(firestoreServiceProvider).updateOnboardingData(
          userId: userId,
          goal: _goalController.text.trim(),
          challenges: selectedChallenges,
          weeklyStudyGoal: _weeklyStudyGoal,
        );

        // **KALICI ÇÖZÜM BURADA:**
        // Veri kaydedildikten sonra, bir sonraki adıma manuel olarak git.
        if (mounted) {
          context.go('/exam-selection');
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bir hata oluştu: ${e.toString()}')),
          );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Seni Tanıyalım')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hedefin nedir?', style: Theme.of(context).textTheme.titleLarge),
              TextFormField(
                controller: _goalController,
                decoration: const InputDecoration(hintText: 'Örn: Tıp fakültesi kazanmak'),
                validator: (value) => value!.isEmpty ? 'Bu alan boş bırakılamaz.' : null,
              ),
              const SizedBox(height: 24),
              Text('Seni en çok ne zorluyor?', style: Theme.of(context).textTheme.titleLarge),
              ..._challenges.keys.map((String key) {
                return CheckboxListTile(
                  title: Text(key),
                  value: _challenges[key],
                  onChanged: (bool? value) {
                    setState(() {
                      _challenges[key] = value!;
                    });
                  },
                );
              }),
              const SizedBox(height: 24),
              Text('Haftada kaç saat çalışmayı hedefliyorsun? (${_weeklyStudyGoal.toStringAsFixed(1)} saat)', style: Theme.of(context).textTheme.titleLarge),
              Slider(
                value: _weeklyStudyGoal,
                min: 1,
                max: 40,
                divisions: 39,
                label: _weeklyStudyGoal.toStringAsFixed(1),
                onChanged: (double value) {
                  setState(() {
                    _weeklyStudyGoal = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Kaydet ve İlerle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}