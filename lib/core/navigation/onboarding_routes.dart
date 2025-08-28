// lib/core/navigation/onboarding_routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/features/onboarding/screens/onboarding_screen.dart';
import 'package:bilge_ai/features/onboarding/screens/exam_selection_screen.dart';
import 'package:bilge_ai/features/onboarding/screens/availability_screen.dart';
import 'app_routes.dart';

List<RouteBase> onboardingRoutes(GlobalKey<NavigatorState> rootNavigatorKey) {
  return [
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.examSelection,
      // Bu satır, ekranın her zaman en üst katmanda açılmasını garanti eder.
      // Bu, hem hatayı çözer hem de diğer akışların etkilenmemesini sağlar.
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ExamSelectionScreen(),
    ),
    GoRoute(
      path: AppRoutes.availability,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AvailabilityScreen(),
    ),
  ];
}