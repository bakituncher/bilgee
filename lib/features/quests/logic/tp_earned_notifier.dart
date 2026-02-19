// lib/features/quests/logic/tp_earned_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AI Hub özellik kullanımlarında direkt TP kazanıldığında UI bildirimi için.
class TpEarnedState {
  final int points;
  final String featureLabel;
  final bool isVisible;

  const TpEarnedState({
    this.points = 0,
    this.featureLabel = '',
    this.isVisible = false,
  });

  const TpEarnedState.empty() : this();

  TpEarnedState copyWith({int? points, String? featureLabel, bool? isVisible}) {
    return TpEarnedState(
      points: points ?? this.points,
      featureLabel: featureLabel ?? this.featureLabel,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

class TpEarnedNotifier extends StateNotifier<TpEarnedState> {
  TpEarnedNotifier() : super(const TpEarnedState.empty());

  void show(int points, String featureLabel) {
    state = TpEarnedState(
      points: points,
      featureLabel: featureLabel,
      isVisible: true,
    );
  }

  void clear() {
    state = const TpEarnedState.empty();
  }
}

final tpEarnedProvider =
    StateNotifierProvider<TpEarnedNotifier, TpEarnedState>((ref) {
  return TpEarnedNotifier();
});
