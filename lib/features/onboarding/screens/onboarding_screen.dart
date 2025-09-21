// lib/features/onboarding/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/onboarding/controllers/onboarding_controller.dart';
import 'package:taktik/features/onboarding/models/onboarding_step.dart';
import 'package:taktik/features/onboarding/widgets/welcome_step_widget.dart';
import 'package:taktik/features/onboarding/widgets/feature_introduction_widget.dart';
import 'package:taktik/features/onboarding/widgets/personalization_widget.dart';
import 'package:taktik/features/onboarding/widgets/completion_widget.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _progressController;
  bool _isLoading = false;
  Map<String, dynamic>? _personalizationData;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<bool> _handleBackPressed() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final progress = ref.read(onboardingControllerProvider);

    if (progress.currentStep > 0) {
      controller.previousStep();
      _pageController.animateToPage(
        progress.currentStep - 1,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return false;
    }
    return true;
  }

  void _nextStep() {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final progress = ref.read(onboardingControllerProvider);

    if (progress.currentStep < controller.steps.length - 1) {
      controller.nextStep();
      _pageController.animateToPage(
        progress.currentStep + 1,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _progressController.forward();
    }
  }

  void _skipToStep(OnboardingStepType stepType) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final stepIndex = controller.steps.indexWhere((step) => step.type == stepType);
    if (stepIndex != -1) {
      controller.jumpToStep(stepIndex);
      _pageController.animateToPage(
        stepIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _savePersonalizationData(Map<String, dynamic> data) async {
    setState(() {
      _personalizationData = data;
    });
    _nextStep();
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authControllerProvider).value;
      if (user != null && _personalizationData != null) {
        // "Hedef" adımı kaldırıldığı için burada güvenli bir varsayılan boş string gönderiyoruz.
        final String safeGoal = (_personalizationData!['goal'] ?? '') as String;
        await ref.read(firestoreServiceProvider).updateOnboardingData(
          userId: user.uid,
          goal: safeGoal,
          challenges: List<String>.from(_personalizationData!['challenges'] ?? []),
          weeklyStudyGoal: (_personalizationData!['weeklyStudyHours'] ?? 0.0) as double,
          additionalData: {
            'studyStyle': _personalizationData!['studyStyle'],
            'onboardingCompleted': true,
            'onboardingCompletedAt': DateTime.now().toIso8601String(),
          },
        );

        final controller = ref.read(onboardingControllerProvider.notifier);
        controller.completeOnboarding();

        if (mounted) {
          context.go('/exam-selection');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final currentStep = controller.currentStepData;
    final user = ref.watch(authControllerProvider).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _handleBackPressed();
          if (shouldPop && context.canPop()) {
            Navigator.of(context).pop();
          }
        }
        // no return value required
      },
      child: Scaffold(
        appBar: _shouldShowAppBar(currentStep.type) ? _buildAppBar(context, progress) : null,
        body: SafeArea(
          child: Stack(
            children: [
              // Ana içerik
              PageView.builder(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                itemCount: controller.steps.length,
                itemBuilder: (context, index) {
                  final step = controller.steps[index];
                  return _buildStepContent(step, user?.displayName ?? 'Öğrenci');
                },
              ),

              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Profilin hazırlanıyor...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
    );
  }

  bool _shouldShowAppBar(OnboardingStepType stepType) {
    return stepType != OnboardingStepType.welcome &&
           stepType != OnboardingStepType.completion;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, OnboardingProgress progress) {
    final theme = Theme.of(context);

    return AppBar(
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: progress.currentStep > 0
          ? IconButton(
              onPressed: () async {
                final canPop = await _handleBackPressed();
                if (canPop && context.canPop()) {
                  context.pop();
                }
              },
              icon: Icon(Icons.arrow_back),
            )
          : null,
      title: Column(
        children: [
          Text(
            'Kurulum',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress.progressPercentage,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ],
      ),
      centerTitle: true,
      actions: [],
    );
  }

  Widget _buildStepContent(OnboardingStep step, String userName) {
    switch (step.type) {
      case OnboardingStepType.welcome:
        return WelcomeStepWidget(
          onContinue: _nextStep,
        );

      case OnboardingStepType.appIntroduction:
      case OnboardingStepType.aiAssistant:
        return FeatureIntroductionWidget(
          step: step,
          onContinue: _nextStep,
          onSkip: null,
        );

      case OnboardingStepType.personalization:
        return PersonalizationWidget(
          onDataCollected: _savePersonalizationData,
        );

      case OnboardingStepType.completion:
        return CompletionWidget(
          onContinue: _completeOnboarding,
          userName: userName,
        );

      default:
        return _buildDefaultContent(step);
    }
  }

  Widget _buildDefaultContent(OnboardingStep step) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            step.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            step.description,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: _nextStep,
            child: Text('Devam Et'),
          ),
        ],
      ),
    );
  }
}
