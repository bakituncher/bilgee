// lib/features/onboarding/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customGoalController = TextEditingController();

  // Çok adımlı akış
  final _pageController = PageController();
  int _currentStep = 0;

  // Hedef presetleri
  final List<String> _goalPresets = const [
    'Tıp Fakültesi',
    'Mühendislik',
    'Hukuk',
    'Öğretmenlik',
    'İşletme',
    'Yabancı Dil',
    'Diğer',
  ];
  int? _selectedGoalIndex;

  // Zorluklar
  final Map<String, bool> _challenges = {
    'Konu eksiği': false,
    'Zaman yönetimi': false,
    'Stres': false,
    'Soru pratiği': false,
    'Motivasyon': false,
    'Planlama': false,
  };

  double _weeklyStudyGoal = 10.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _customGoalController.dispose();
    super.dispose();
  }

  // Geri tuşu yönetimi: Adım > 0 ise adım geriye dön, değilse sayfadan çık.
  Future<bool> _handleBackPressed() async {
    if (_currentStep > 0) {
      _prevStep();
      return false; // route pop yapma
    }
    return true; // route pop yap
  }

  String? _validateStep(int step) {
    if (step == 0) {
      if (_selectedGoalIndex == null) {
        return 'Lütfen bir hedef seç.';
      }
      if (_goalPresets[_selectedGoalIndex!] == 'Diğer' &&
          _customGoalController.text.trim().isEmpty) {
        return 'Lütfen hedefini yaz.';
      }
    }
    return null;
  }

  Future<void> _nextStep() async {
    final error = _validateStep(_currentStep);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      await _saveProfile();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final userId = ref.read(authControllerProvider).value!.uid;

        // Seçilen hedefi belirle
        String goal;
        if (_selectedGoalIndex != null) {
          final selected = _goalPresets[_selectedGoalIndex!];
          goal = selected == 'Diğer'
              ? _customGoalController.text.trim()
              : selected;
        } else {
          goal = _customGoalController.text.trim();
        }

        final selectedChallenges = _challenges.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList();

        await ref.read(firestoreServiceProvider).updateOnboardingData(
              userId: userId,
              goal: goal,
              challenges: selectedChallenges,
              weeklyStudyGoal: _weeklyStudyGoal,
            );

        if (mounted) {
          context.push('/exam-selection');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bir hata oluştu: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Bileşenler
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_currentStep + 1) / 3.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baykuş görseli kaldırıldı
        Text(
          'Seni Tanıyalım',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _stepGoals(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Hedefin nedir?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'İstersen birini seç ya da Diğer’i işaretleyip yaz.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_goalPresets.length, (i) {
              final selected = _selectedGoalIndex == i;
              return ChoiceChip(
                label: Text(_goalPresets[i]),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    _selectedGoalIndex = val ? i : null;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          if (_selectedGoalIndex != null && _goalPresets[_selectedGoalIndex!] == 'Diğer')
            TextFormField(
              controller: _customGoalController,
              decoration: const InputDecoration(
                labelText: 'Hedefini yaz',
                hintText: 'Örn: Tıp fakültesi kazanmak',
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepChallenges(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Seni en çok ne zorluyor?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Birkaç tanesini seçebilirsin (opsiyonel).',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _challenges.keys.map((key) {
              final selected = _challenges[key] ?? false;
              return FilterChip(
                label: Text(key),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    _challenges[key] = val;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _stepWeeklyGoal(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Haftalık çalışma hedefi', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Haftada kaç saat çalışmayı hedefliyorsun?',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_weeklyStudyGoal.toStringAsFixed(0)} saat/hafta', style: theme.textTheme.titleMedium),
              Text(_weeklyStudyGoal < 8
                  ? 'Hafif tempo'
                  : _weeklyStudyGoal < 15
                      ? 'Dengeli tempo'
                      : 'Yoğun tempo'),
            ],
          ),
          Slider(
            value: _weeklyStudyGoal,
            min: 1,
            max: 40,
            divisions: 39,
            label: _weeklyStudyGoal.toStringAsFixed(0),
            onChanged: (v) => setState(() => _weeklyStudyGoal = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [7, 10, 15, 20, 25].map((v) {
              return OutlinedButton(
                onPressed: () => setState(() => _weeklyStudyGoal = v.toDouble()),
                child: Text('$v'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  BottomAppBar _bottomBar() {
    return BottomAppBar(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              if (_currentStep > 0)
                OutlinedButton(
                  onPressed: _isLoading ? null : _prevStep,
                  child: const Text('Geri'),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_currentStep < 2 ? 'İleri' : 'Kaydet ve İlerle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return WillPopScope(
      onWillPop: _handleBackPressed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seni Tanıyalım'),
          automaticallyImplyLeading: true,
          leading: BackButton(
            onPressed: () async {
              final canPop = await _handleBackPressed();
              if (canPop) {
                if (context.canPop()) context.pop();
              }
            },
          ),
        ),
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: keyboardVisible ? null : _bottomBar(),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _header(context),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _stepGoals(context),
                        _stepChallenges(context),
                        _stepWeeklyGoal(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
