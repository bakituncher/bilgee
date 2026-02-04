// lib/data/repositories/weekly_planner_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/repositories/weekly_planner_service.dart';

/// Haftalık planlama servisi provider'ı
final weeklyPlannerServiceProvider = Provider<WeeklyPlannerService>((ref) {
  return WeeklyPlannerService();
});

