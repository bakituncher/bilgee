import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taktik/features/coach/models/saved_content_model.dart';
import 'package:uuid/uuid.dart';

/// Kaydetme işlemi sonucu
class SaveResult {
  final bool success;
  final String message;
  final SavedContentModel? savedContent;

  SaveResult({required this.success, required this.message, this.savedContent});
}

/// Rate limiting state
class SaveProtectionState {
  final List<DateTime> recentSaves;
  final Map<String, DateTime> lastSaveByType;
  final Set<String> recentHashes;

  const SaveProtectionState({
    this.recentSaves = const [],
    this.lastSaveByType = const {},
    this.recentHashes = const {},
  });

  SaveProtectionState copyWith({
    List<DateTime>? recentSaves,
    Map<String, DateTime>? lastSaveByType,
    Set<String>? recentHashes,
  }) {
    return SaveProtectionState(
      recentSaves: recentSaves ?? this.recentSaves,
      lastSaveByType: lastSaveByType ?? this.lastSaveByType,
      recentHashes: recentHashes ?? this.recentHashes,
    );
  }
}

final savedContentProvider =
    StateNotifierProvider<SavedContentNotifier, List<SavedContentModel>>((ref) {
  return SavedContentNotifier();
});

class SavedContentNotifier extends StateNotifier<List<SavedContentModel>> {
  SavedContentNotifier() : super([]) {
    _loadFromHive();
  }

  SaveProtectionState _protection = const SaveProtectionState();

  static const int maxSavesPerMinute = 5;
  static const int cooldownSeconds = 30;
  static const int maxTotalContents = 100;

  Box<SavedContentModel> get _box => Hive.box<SavedContentModel>('saved_content_box');

  void _loadFromHive() {
    final list = _box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = list;
  }

  String _generateContentHash(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  SaveResult _validateSave(SavedContentType type, String contentHash) {
    final now = DateTime.now();

    final recentSaves = _protection.recentSaves
        .where((t) => now.difference(t).inSeconds < 60)
        .toList();

    if (recentSaves.length >= maxSavesPerMinute) {
      final waitTime = 60 - now.difference(recentSaves.first).inSeconds;
      return SaveResult(success: false, message: 'Çok hızlı kayıt! $waitTime sn bekle.');
    }

    final typeKey = type.toString();
    final lastSaveForType = _protection.lastSaveByType[typeKey];
    if (lastSaveForType != null) {
      final secondsSince = now.difference(lastSaveForType).inSeconds;
      if (secondsSince < cooldownSeconds) {
        return SaveResult(success: false, message: 'Aynı tür için ${cooldownSeconds - secondsSince} sn bekle.');
      }
    }

    if (_protection.recentHashes.contains(contentHash) ||
        state.any((c) => c.contentHash == contentHash)) {
      return SaveResult(success: false, message: 'Bu içerik zaten kaydedilmiş!');
    }

    if (state.length >= maxTotalContents) {
      return SaveResult(success: false, message: 'Limit doldu ($maxTotalContents). Eski içerikleri sil.');
    }

    return SaveResult(success: true, message: 'OK');
  }

  void _updateProtection(SavedContentType type, String contentHash) {
    final now = DateTime.now();
    final recentSaves = _protection.recentSaves
        .where((t) => now.difference(t).inMinutes < 5)
        .toList()..add(now);

    final lastSaveByType = Map<String, DateTime>.from(_protection.lastSaveByType);
    lastSaveByType[type.toString()] = now;

    final recentHashes = Set<String>.from(_protection.recentHashes)..add(contentHash);

    _protection = _protection.copyWith(
      recentSaves: recentSaves,
      lastSaveByType: lastSaveByType,
      recentHashes: recentHashes,
    );
  }

  Future<SaveResult> saveContent({
    required SavedContentType type,
    required String title,
    required String content,
    String? subject,
    String? examType,
  }) async {
    try {
      final contentHash = _generateContentHash(content);
      final validation = _validateSave(type, contentHash);
      if (!validation.success) return validation;

      final newContent = SavedContentModel(
        id: const Uuid().v4(),
        type: type,
        title: title,
        content: content,
        createdAt: DateTime.now(),
        contentHash: contentHash,
        subject: subject,
        examType: examType,
      );

      await _box.add(newContent);
      _updateProtection(type, contentHash);
      _loadFromHive();

      return SaveResult(success: true, message: 'Kaydedildi!', savedContent: newContent);
    } catch (e) {
      return SaveResult(success: false, message: 'Hata: $e');
    }
  }

  Future<void> deleteContent(SavedContentModel item) async {
    await item.delete();
    _loadFromHive();
  }

  List<SavedContentModel> getByType(SavedContentType type) =>
      state.where((c) => c.type == type).toList();

  Future<void> clearAll() async {
    await _box.clear();
    state = [];
  }

  Map<String, dynamic> getStorageStats() => {
    'total': state.length,
    'flashcards': state.where((c) => c.type == SavedContentType.flashcard).length,
    'quizzes': state.where((c) => c.type == SavedContentType.quiz).length,
    'summaries': state.where((c) => c.type == SavedContentType.summary).length,
    'limit': maxTotalContents,
    'remaining': maxTotalContents - state.length,
  };
}
