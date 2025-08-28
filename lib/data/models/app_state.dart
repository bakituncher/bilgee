// lib/data/models/app_state.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppState {
  final bool onboardingCompleted;
  final bool tutorialCompleted;
  final Timestamp? lastQuestRefreshDate;

  const AppState({
    this.onboardingCompleted = false,
    this.tutorialCompleted = false,
    this.lastQuestRefreshDate,
  });

  factory AppState.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppState(
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      tutorialCompleted: data['tutorialCompleted'] ?? false,
      lastQuestRefreshDate: data['lastQuestRefreshDate'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'onboardingCompleted': onboardingCompleted,
    'tutorialCompleted': tutorialCompleted,
    'lastQuestRefreshDate': lastQuestRefreshDate,
  };
}

