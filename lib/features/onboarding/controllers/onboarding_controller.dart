// lib/features/onboarding/controllers/onboarding_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/onboarding/models/onboarding_step.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

class OnboardingController extends StateNotifier<OnboardingProgress> {
  OnboardingController() : super(const OnboardingProgress(
    currentStep: 0,
    totalSteps: 13,
    isCompleted: false,
    completedSteps: {},
  ));

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      type: OnboardingStepType.welcome,
      title: 'Bilge AI\'ya Hoş Geldin! 🎉',
      description: 'Sınav başarın için kişisel AI asistanın hazır. Hemen başlayalım!',
      isInteractive: true,
      animationDuration: Duration(milliseconds: 1500),
    ),
    OnboardingStep(
      type: OnboardingStepType.appIntroduction,
      title: 'Bilge AI Nedir?',
      description: 'Yapay zeka destekli kişisel eğitim asistanın. YKS, LGS ve KPSS sınavlarında başarıya giden yolda yanında.',
      features: [
        OnboardingFeature(
          title: 'Kişisel AI Asistan',
          description: 'Senin için özel hazırlanmış çalışma planları',
          icon: Icons.psychology,
        ),
        OnboardingFeature(
          title: 'Akıllı Soru Bankası',
          description: 'Seviyene uygun sorular ve detaylı çözümler',
          icon: Icons.quiz,
        ),
        OnboardingFeature(
          title: 'İlerleme Takibi',
          description: 'Gelişimini görsel grafiklerle takip et',
          icon: Icons.trending_up,
        ),
      ],
    ),
    OnboardingStep(
      type: OnboardingStepType.featureTour,
      title: 'Özellikler Turu 🚀',
      description: 'Uygulamanın güçlü özelliklerini keşfedelim',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.aiAssistant,
      title: 'AI Asistanın ile Tanış 🤖',
      description: 'Bilge, senin kişisel eğitim asistanın. Ona her türlü soruyu sorabilirsin.',
      features: [
        OnboardingFeature(
          title: 'Soru Çözümü',
          description: 'Anlamadığın soruları çözmende yardım eder',
          icon: Icons.help_outline,
          demoAction: 'show_question_solving',
        ),
        OnboardingFeature(
          title: 'Konu Açıklaması',
          description: 'Karmaşık konuları basit şekilde açıklar',
          icon: Icons.school,
          demoAction: 'show_topic_explanation',
        ),
        OnboardingFeature(
          title: 'Çalışma Planı',
          description: 'Sana özel çalışma programı hazırlar',
          icon: Icons.calendar_today,
          demoAction: 'show_study_plan',
        ),
      ],
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.studyPlanning,
      title: 'Akıllı Çalışma Planı 📅',
      description: 'AI asistanın, hedefin ve müsaitlik durumuna göre kişisel çalışma programı oluşturur.',
      features: [
        OnboardingFeature(
          title: 'Günlük Program',
          description: 'Her gün ne çalışacağını gösterir',
          icon: Icons.today,
        ),
        OnboardingFeature(
          title: 'Hatırlatmalar',
          description: 'Çalışma saatlerini unutturmuyor',
          icon: Icons.notifications,
        ),
        OnboardingFeature(
          title: 'Esneklik',
          description: 'Programını ihtiyaçlarına göre ayarlar',
          icon: Icons.tune,
        ),
      ],
    ),
    OnboardingStep(
      type: OnboardingStepType.questionPractice,
      title: 'Soru Pratiği 📝',
      description: 'Binlerce soru ile pratik yap, zayıf yönlerini güçlendir.',
      features: [
        OnboardingFeature(
          title: 'Adaptif Sorular',
          description: 'Seviyene göre zorlaşan sorular',
          icon: Icons.trending_up,
        ),
        OnboardingFeature(
          title: 'Detaylı Çözümler',
          description: 'Her soruya video ve metin çözüm',
          icon: Icons.play_circle,
        ),
        OnboardingFeature(
          title: 'Hata Analizi',
          description: 'Yanlış yaptığın konuları analiz eder',
          icon: Icons.analytics,
        ),
      ],
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.progressTracking,
      title: 'İlerleme Takibi 📊',
      description: 'Gelişimini grafiklerle görüp motivasyonunu artır.',
      features: [
        OnboardingFeature(
          title: 'Performans Grafikleri',
          description: 'Başarı oranını görsel takip',
          icon: Icons.show_chart,
        ),
        OnboardingFeature(
          title: 'Güçlü & Zayıf Yönler',
          description: 'Hangi konularda iyi olduğunu görürsün',
          icon: Icons.assessment,
        ),
        OnboardingFeature(
          title: 'Hedef Takibi',
          description: 'Hedefe ne kadar yakın olduğunu gösterir',
          icon: Icons.flag,
        ),
      ],
    ),
    OnboardingStep(
      type: OnboardingStepType.personalization,
      title: 'Seni Tanıyalım 👤',
      description: 'Sana en uygun deneyimi sunmak için biraz bilgi alalım.',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.goalSetting,
      title: 'Hedefini Belirle 🎯',
      description: 'Hangi üniversite, bölüm veya kurumu hedefliyorsun?',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.examSelection,
      title: 'Sınav Seç 📚',
      description: 'Hangi sınava hazırlanıyorsun? YKS, LGS veya KPSS?',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.availability,
      title: 'Çalışma Saatlerin ⏰',
      description: 'Ne zaman çalışabiliyorsun? Programını ona göre ayarlayalım.',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.practiceDemo,
      title: 'Hadi Deneyelim! 🚀',
      description: 'Birkaç örnek soru ile uygulamayı keşfedelim.',
      isInteractive: true,
    ),
    OnboardingStep(
      type: OnboardingStepType.completion,
      title: 'Hazırsın! 🎉',
      description: 'Tebrikler! Artık Bilge AI ile başarıya giden yolculuğa başlayabilirsin.',
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
      totalSteps: 13,
      isCompleted: false,
      completedSteps: {},
    );
  }
}

final onboardingControllerProvider = StateNotifierProvider<OnboardingController, OnboardingProgress>((ref) {
  return OnboardingController();
});
