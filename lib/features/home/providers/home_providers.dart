// lib/features/home/providers/home_providers.dart
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:bilge_ai/features/quests/logic/optimized_quests_provider.dart';

final avgNetProvider = Provider<double>((ref) {
  final tests = ref.watch(testsProvider).valueOrNull ?? <TestModel>[];
  if (tests.isEmpty) return 0;
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return 0;
  return (user.totalNetSum / tests.length).toDouble();
});

final bestNetProvider = Provider<double>((ref) {
  final tests = ref.watch(testsProvider).valueOrNull ?? <TestModel>[];
  if (tests.isEmpty) return 0;
  return tests.map((e) => e.totalNet).reduce(max);
});

final lastThreeTrendProvider = Provider<int>((ref) {
  final tests = [...(ref.watch(testsProvider).valueOrNull ?? <TestModel>[])];
  if (tests.length < 3) return 0; // 0 = nötr
  tests.sort((a,b)=> b.date.compareTo(a.date));
  final last3 = tests.take(3).toList().reversed.toList();
  // basit lineer trend (y2 - y0)
  final diff = last3.last.totalNet - last3.first.totalNet;
  if (diff > 0.1) return 1; // yukarı
  if (diff < -0.1) return -1; // aşağı
  return 0;
});

final dailyQuestsProgressProvider = Provider<({int completed,int total,double progress,Duration remaining})>((ref){
  final quests = ref.watch(optimizedDailyQuestsProvider);
  if (quests.isEmpty){
    return (completed:0,total:0,progress:0.0,remaining:Duration.zero);
  }
  final total = quests.where((q)=> q.type==QuestType.daily).length;
  final completed = quests.where((q)=> q.type==QuestType.daily && q.isCompleted).length;
  final double progress = total==0?0.0: completed/total.toDouble();
  final now = DateTime.now();
  final endOfDay = DateTime(now.year,now.month,now.day,23,59,59,999);
  final remaining = endOfDay.difference(now);
  return (completed:completed,total:total,progress:progress,remaining:remaining);
});

final planProgressProvider = Provider<({int done,int total,double ratio})>((ref){
  final planDoc = ref.watch(planProvider).valueOrNull;
  final planMap = planDoc?.weeklyPlan;

  if (planMap == null){
    return (done:0,total:0,ratio:0.0);
  }
  final today = DateTime.now();
  final todayKey = DateFormat('yyyy-MM-dd').format(today);
  final completedList = ref.watch(completedTasksForDateProvider(today)).maybeWhen(data: (list)=> list, orElse: ()=> const <String>[]);
  int totalToday = 0;
  if (planMap['plan'] is List){
    final list = planMap['plan'] as List;
    final idx = today.weekday -1;
    if (idx>=0 && idx < list.length){
      final day = list[idx];
      if (day is Map && day['schedule'] is List){
        totalToday = (day['schedule'] as List).length;
      }
    }
  }
  final double ratio = totalToday==0?0.0: (completedList.length/ totalToday).clamp(0,1).toDouble();
  return (done:completedList.length,total:totalToday,ratio:ratio);
});

final lastActivityProvider = Provider<({String label,String route,IconData icon, Color color})>((ref){
  final user = ref.watch(userProfileProvider).value;
  final tests = ref.watch(testsProvider).valueOrNull ?? [];
  if (user == null){
    return (label:'Planı Aç', route:'/home', icon: Icons.view_week_rounded, color: Colors.amberAccent);
  }
  if (tests.isEmpty){
    return (label:'İlk Denemeni Ekle', route:'/home/add-test', icon: Icons.add_chart_outlined, color: Colors.amberAccent);
  }
  if (user.workshopStreak>0){
    return (label:'AI Koç Sohbeti', route:'/ai-hub/motivation-chat', icon: Icons.chat_bubble_outline_rounded, color: Colors.tealAccent);
  }
  return (label:'Odak Seansına Başla', route:'/home/pomodoro', icon: Icons.timer_outlined, color: Colors.lightBlueAccent);
});