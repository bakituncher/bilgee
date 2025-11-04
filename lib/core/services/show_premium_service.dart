// lib/core/services/show_premium_service.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/services/local_storage_service.dart';

final showPremiumServiceProvider = Provider<ShowPremiumService>((ref) {
  return ShowPremiumService(ref);
});

class ShowPremiumService {
  final Ref _ref;

  ShowPremiumService(this._ref);

  Future<void> showPremiumScreenOnLaunch(BuildContext context) async {
    // Use a post-frame callback to ensure the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        GoRouter.of(context).push('/premium');
      }
    });
  }

  Future<void> showPremiumAfterTestAdded(BuildContext context) async {
    final localStorage = _ref.read(localStorageProvider);
    await localStorage.incrementTestCounter();
    final testCounter = await localStorage.getTestCounter();

    if (testCounter >= 2) {
      await localStorage.resetTestCounter();
      if (context.mounted) {
        await GoRouter.of(context).push('/premium');
      }
    }
  }

  Future<void> showPremiumAfterCourseNetUpdated(BuildContext context) async {
    final localStorage = _ref.read(localStorageProvider);
    await localStorage.incrementCourseNetCounter();
    final courseNetCounter = await localStorage.getCourseNetCounter();

    if (courseNetCounter >= 2) {
      await localStorage.resetCourseNetCounter();
      if (context.mounted) {
        await GoRouter.of(context).push('/premium');
      }
    }
  }
}
