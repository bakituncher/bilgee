import 'package:flutter/material.dart';

enum OnboardingStepType {
  welcome,
  appIntroduction,
  featureTour,
  aiAssistant,
  studyPlanning,
  questionPractice,
  progressTracking,
  personalization,
  goalSetting,
  examSelection,
  availability,
  practiceDemo,
  completion
}

class OnboardingStep {
  final OnboardingStepType type;
  final String title;
  final String description;
  final String? animation;
  final String? imagePath;
  final List<OnboardingFeature>? features;
  final bool isInteractive;
  final Duration? animationDuration;

  const OnboardingStep({
    required this.type,
    required this.title,
    required this.description,
    this.animation,
    this.imagePath,
    this.features,
    this.isInteractive = false,
    this.animationDuration,
  });
}

class OnboardingFeature {
  final String title;
  final String description;
  final IconData icon;
  final String? demoAction;

  const OnboardingFeature({
    required this.title,
    required this.description,
    required this.icon,
    this.demoAction,
  });
}

class OnboardingProgress {
  final int currentStep;
  final int totalSteps;
  final bool isCompleted;
  final Map<OnboardingStepType, bool> completedSteps;

  const OnboardingProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.isCompleted,
    required this.completedSteps,
  });

  double get progressPercentage => currentStep / totalSteps;
}
