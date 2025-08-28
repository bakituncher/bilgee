// lib/features/settings/logic/settings_notifier.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

// Veri sıfırlama işleminin durumunu takip etmek için
enum ResetStatus { initial, success, failure }

// Ayarlar ekranının durumunu tutan model
class SettingsState extends Equatable {
  final bool isLoading;
  final ResetStatus resetStatus;

  const SettingsState({
    this.isLoading = false,
    this.resetStatus = ResetStatus.initial,
  });

  SettingsState copyWith({bool? isLoading, ResetStatus? resetStatus}) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      resetStatus: resetStatus ?? this.resetStatus,
    );
  }

  @override
  List<Object> get props => [isLoading, resetStatus];
}

// Ayarlar ekranının mantığını yöneten Notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  SettingsNotifier(this._ref) : super(const SettingsState());

  Future<bool> updateUserName(String newName) async {
    state = state.copyWith(isLoading: true);
    final userId = _ref.read(authControllerProvider).value?.uid;

    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    try {
      await _ref
          .read(firestoreServiceProvider)
          .updateUserName(userId: userId, newName: newName);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  // Veri sıfırlama işlemini yöneten fonksiyon
  Future<void> resetAccountForNewExam() async {
    state = state.copyWith(isLoading: true, resetStatus: ResetStatus.initial);
    final userId = _ref.read(authControllerProvider).value?.uid;

    if (userId == null) {
      state = state.copyWith(isLoading: false, resetStatus: ResetStatus.failure);
      return;
    }

    try {
      await _ref.read(firestoreServiceProvider).resetUserDataForNewExam(userId);
      // İşlem başarılıysa durumu "success" olarak güncelle
      state = state.copyWith(isLoading: false, resetStatus: ResetStatus.success);
    } catch (e) {
      // Hata olursa durumu "failure" olarak güncelle
      state = state.copyWith(isLoading: false, resetStatus: ResetStatus.failure);
    }
  }

  // Navigasyon sonrası durumu sıfırlamak için
  void resetOperationStatus() {
    state = state.copyWith(resetStatus: ResetStatus.initial);
  }
}

// Bu Notifier'ı tüm uygulamada kullanılabilir hale getiren Provider
final settingsNotifierProvider =
StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});