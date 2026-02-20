// lib/shared/streak/streak_milestone_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreakMilestoneState {
  final int? streak;
  final bool show;

  const StreakMilestoneState({this.streak, this.show = false});

  const StreakMilestoneState.empty()
      : streak = null,
        show = false;

  StreakMilestoneState copyWith({int? streak, bool? show}) {
    return StreakMilestoneState(
      streak: streak ?? this.streak,
      show: show ?? this.show,
    );
  }
}

class StreakMilestoneNotifier extends StateNotifier<StreakMilestoneState> {
  StreakMilestoneNotifier() : super(const StreakMilestoneState.empty());

  void showMilestone(int streak) {
    state = StreakMilestoneState(streak: streak, show: true);
  }

  void dismiss() {
    state = const StreakMilestoneState.empty();
  }
}

final streakMilestoneProvider =
    StateNotifierProvider<StreakMilestoneNotifier, StreakMilestoneState>(
  (ref) => StreakMilestoneNotifier(),
);
