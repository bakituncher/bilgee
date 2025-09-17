// lib/features/onboarding/controllers/onboarding_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/onboarding/models/onboarding_step.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

class OnboardingController extends StateNotifier<OnboardingProgress> {
  OnboardingController() : super(const OnboardingProgress(
    currentStep: 0,
    totalSteps: 8, // Demo kısmı kaldırıldığı için azaltıldı
    isCompleted: false,
    completedSteps: {},
  ));

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      type: OnboardingStepType.welcome,
      title: 'Taktik\'e Hoş Geldin! 🎯',
      description: 'Sınav başarının için stratejik AI asistanın. Hedefe odaklan!',
      isInteractive: true,
      animationDuration: Duration(milliseconds: 1500),
    ),
    OnboardingStep(
      type: OnboardingStepType.appIntroduction,
      title: 'Taktik Nedir?',
      description: 'YKS, LGS ve KPSS sınavlarında başarı için stratejik çalışma platformun.',
      features: [
        OnboardingFeature(
          title: 'Stratejik AI Asistan',
          description: 'Hedefine özel çalışma stratejileri',
          icon: Icons.psychology,
        ),
        OnboardingFeature(
          title: 'Akıllı Soru Çözümü',
          description: 'Seviyene uygun sorular ve çözüm stratejileri',
          icon: Icons.quiz,
        ),
        OnboardingFeature(
          title: 'Hedef Takibi',
          description: 'İlerlemeini takip et, stratejini güncelle',
          icon: Icons.trending_up,
        ),
      ],
    ),
    OnboardingStep(
      type: OnboardingStepType.aiAssistant,
      title: 'AI Asistanın 🤖',
      description: 'Taktik AI ile soru çöz, konu öğren, strateji geliştir.',
      features: [
        OnboardingFeature(
          title: 'Soru Çözüm Stratejisi',
          description: 'Sorulara yaklaşım stratejileri',
          icon: Icons.lightbulb,
        ),
        OnboardingFeature(
          title: 'Konu Haritası',
          description: 'Konular arası bağlantıları göster',
          icon: Icons.school,
        ),
        OnboardingFeature(
          title: 'Hedefli Planlama',
          description: 'Hedefe giden en verimli yol',
          icon: Icons.flag,
        ),
      ],
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.personalization,
      title: 'Seni Tanıyalım 👤',
      description: 'Sana en uygun deneyimi sunmak için biraz bilgi alalım.',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.examSelection,
      title: 'Sınav Seç 📚',
      description: 'Hangi sınava hazırlanıyorsun? YKS, LGS veya KPSS?',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.goalSetting,
      title: 'Hedefini Belirle 🎯',
      description: 'Hangi üniversite, bölüm veya kurumu hedefliyorsun?',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.availability,
      title: 'Çalışma Saatlerin ⏰',
      description: 'Ne zaman çalışabiliyorsun? Programını ona göre ayarlayalım.',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.completion,
      title: 'Hazırsın! 🎉',
      description: 'Tebrikler! Artık Taktik ile başarıya giden yolculuğa başlayabilirsin.',
      isInteractive: true,
    ),
  ];

  List<OnboardingStep> get steps => _steps;
  OnboardingStep get currentStepData => _steps[state.currentStep];

  void nextStep() {
    if (state.currentStep < state.totalSteps - 1) {
      final newStep = state.currentStep + 1;
      final newCompletedSteps = Map<OnboardingStepType, bool>.from(state.completedSteps);
      newCompletedSteps[currentStepData.type] = true;

      state = OnboardingProgress(
        currentStep: newStep,
        totalSteps: state.totalSteps,
        isCompleted: newStep == state.totalSteps - 1,
        completedSteps: newCompletedSteps,
      );
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = OnboardingProgress(
        currentStep: state.currentStep - 1,
        totalSteps: state.totalSteps,
        isCompleted: false,
        completedSteps: state.completedSteps,
      );
    }
  }

  void jumpToStep(int stepIndex) {
    if (stepIndex >= 0 && stepIndex < state.totalSteps) {
      state = OnboardingProgress(
        currentStep: stepIndex,
        totalSteps: state.totalSteps,
        isCompleted: stepIndex == state.totalSteps - 1,
        completedSteps: state.completedSteps,
      );
    }
  }

  void markStepCompleted(OnboardingStepType stepType) {
    final newCompletedSteps = Map<OnboardingStepType, bool>.from(state.completedSteps);
    newCompletedSteps[stepType] = true;

    state = OnboardingProgress(
      currentStep: state.currentStep,
      totalSteps: state.totalSteps,
      isCompleted: state.isCompleted,
      completedSteps: newCompletedSteps,
    );
  }

  void completeOnboarding() {
    state = OnboardingProgress(
      currentStep: state.totalSteps - 1,
      totalSteps: state.totalSteps,
      isCompleted: true,
      completedSteps: state.completedSteps,
    );
  }

  void reset() {
    state = const OnboardingProgress(
      currentStep: 0,
      totalSteps: 8,
      isCompleted: false,
      completedSteps: {},
    );
  }
}

final onboardingControllerProvider = StateNotifierProvider<OnboardingController, OnboardingProgress>((ref) {
  return OnboardingController();
});
