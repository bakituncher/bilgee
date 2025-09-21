// lib/core/navigation/onboarding_routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/onboarding/screens/onboarding_screen.dart';
import 'package:taktik/features/onboarding/screens/exam_selection_screen.dart';
import 'package:taktik/features/onboarding/screens/availability_screen.dart';
import 'app_routes.dart';
import 'transition_utils.dart';

List<RouteBase> onboardingRoutes(GlobalKey<NavigatorState> rootNavigatorKey) {
  return [
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.examSelection,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: const ExamSelectionScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.availability,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: const AvailabilityScreen(),
      ),
    ),
  ];
}