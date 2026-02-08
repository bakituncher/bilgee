import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/coach/services/content_generator_service.dart';

/// Üretilen içerik cache'i - dosya hash'i ve içerik türüne göre
class ContentCache {
  final String fileHash;
  final ContentType contentType;
  final GeneratedContent content;
  final DateTime createdAt;

  ContentCache({
    required this.fileHash,
    required this.contentType,
    required this.content,
    required this.createdAt,
  });

  /// Cache süresi doldu mu? (30 dakika)
  bool get isExpired => DateTime.now().difference(createdAt).inMinutes > 30;
}

/// Content Generator ekranı için state modeli
class ContentGeneratorState {
  final File? selectedFile;
  final String? fileName;
  final String? mimeType;
  final List<File> capturedImages;
  final ContentType selectedContentType;
  final bool isLoading;
  final String? error;
  final GeneratedContent? result;
  final Map<int, bool> revealedAnswers;
  final Map<int, int> selectedAnswers;
  final Map<String, ContentCache> contentCache; // Üretilen içerik cache'i

  const ContentGeneratorState({
    this.selectedFile,
    this.fileName,
    this.mimeType,
    this.capturedImages = const [],
    this.selectedContentType = ContentType.flashcard,
    this.isLoading = false,
    this.error,
    this.result,
    this.revealedAnswers = const {},
    this.selectedAnswers = const {},
    this.contentCache = const {},
  });

  /// Initial state factory
  factory ContentGeneratorState.initial() => const ContentGeneratorState();

  /// Has content check - dosya veya görsel var mı?
  bool get hasContent => selectedFile != null || capturedImages.isNotEmpty;

  /// File count
  int get fileCount => capturedImages.isNotEmpty
      ? capturedImages.length
      : (selectedFile != null ? 1 : 0);

  /// CopyWith method for immutable updates
  ContentGeneratorState copyWith({
    File? selectedFile,
    String? fileName,
    String? mimeType,
    List<File>? capturedImages,
    ContentType? selectedContentType,
    bool? isLoading,
    String? error,
    GeneratedContent? result,
    Map<int, bool>? revealedAnswers,
    Map<int, int>? selectedAnswers,
    Map<String, ContentCache>? contentCache,
    bool clearSelectedFile = false,
    bool clearFileName = false,
    bool clearMimeType = false,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return ContentGeneratorState(
      selectedFile: clearSelectedFile ? null : (selectedFile ?? this.selectedFile),
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      mimeType: clearMimeType ? null : (mimeType ?? this.mimeType),
      capturedImages: capturedImages ?? this.capturedImages,
      selectedContentType: selectedContentType ?? this.selectedContentType,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      result: clearResult ? null : (result ?? this.result),
      revealedAnswers: revealedAnswers ?? this.revealedAnswers,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      contentCache: contentCache ?? this.contentCache,
    );
  }
}

/// Content Generator State Notifier
class ContentGeneratorNotifier extends StateNotifier<ContentGeneratorState> {
  ContentGeneratorNotifier() : super(ContentGeneratorState.initial());

  /// Cache key oluştur (dosya yolu + içerik türü)
  String _getCacheKey(String filePath, ContentType type) {
    return '${filePath}_${type.name}';
  }

  /// Cache'den içerik al
  GeneratedContent? getCachedContent(String filePath, ContentType type) {
    final key = _getCacheKey(filePath, type);
    final cached = state.contentCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.content;
    }
    // Süresi dolmuşsa cache'den kaldır
    if (cached != null) {
      _removeCacheEntry(key);
    }
    return null;
  }

  /// Cache'e içerik ekle
  void addToCache(String filePath, ContentType type, GeneratedContent content) {
    final key = _getCacheKey(filePath, type);
    final newCache = Map<String, ContentCache>.from(state.contentCache);

    // Eski cache'leri temizle (max 10 entry)
    if (newCache.length >= 10) {
      final expiredKeys = newCache.entries
          .where((e) => e.value.isExpired)
          .map((e) => e.key)
          .toList();
      for (final k in expiredKeys) {
        newCache.remove(k);
      }
      // Hala çoksa en eskiyi sil
      if (newCache.length >= 10) {
        final oldest = newCache.entries
            .reduce((a, b) => a.value.createdAt.isBefore(b.value.createdAt) ? a : b);
        newCache.remove(oldest.key);
      }
    }

    newCache[key] = ContentCache(
      fileHash: filePath,
      contentType: type,
      content: content,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(contentCache: newCache);
  }

  void _removeCacheEntry(String key) {
    final newCache = Map<String, ContentCache>.from(state.contentCache);
    newCache.remove(key);
    state = state.copyWith(contentCache: newCache);
  }

  /// Dosya seçimi (tek dosya)
  void setSelectedFile(File file, String name, String mimeType) {
    state = state.copyWith(
      selectedFile: file,
      fileName: name,
      mimeType: mimeType,
      capturedImages: [],
      clearError: true,
    );
  }

  /// Çoklu görsel ekleme
  void addCapturedImage(File image) {
    if (state.capturedImages.length >= 10) return;
    state = state.copyWith(
      capturedImages: [...state.capturedImages, image],
      clearSelectedFile: true,
      clearFileName: true,
      clearMimeType: true,
      clearError: true,
    );
  }

  /// Çoklu görselleri güncelle
  void setCapturedImages(List<File> images) {
    state = state.copyWith(
      capturedImages: images,
      clearSelectedFile: true,
      clearFileName: true,
      clearMimeType: true,
      clearError: true,
    );
  }

  /// İçerik türü değiştir
  void setContentType(ContentType type) {
    state = state.copyWith(selectedContentType: type);
  }

  /// Loading durumu
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Hata durumu
  void setError(String? error) {
    state = state.copyWith(error: error, clearError: error == null);
  }

  /// Sonuç set et
  void setResult(GeneratedContent? result) {
    state = state.copyWith(
      result: result,
      isLoading: false,
      revealedAnswers: {},
      selectedAnswers: {},
    );
  }

  /// Yeniden üretim için sonucu temizle (isLoading'i değiştirmez)
  void clearResultForRegenerate() {
    state = state.copyWith(
      clearResult: true,
      revealedAnswers: {},
      selectedAnswers: {},
      isLoading: true,
    );
  }

  /// Cevap göster/gizle
  void toggleRevealedAnswer(int index, bool revealed) {
    final newMap = Map<int, bool>.from(state.revealedAnswers);
    newMap[index] = revealed;
    state = state.copyWith(revealedAnswers: newMap);
  }

  /// Seçili cevap set et
  void setSelectedAnswer(int questionIndex, int answerIndex) {
    final newMap = Map<int, int>.from(state.selectedAnswers);
    newMap[questionIndex] = answerIndex;
    state = state.copyWith(selectedAnswers: newMap);
  }

  /// Dosya seçimini temizle (sadece dosya, sonuç korunur)
  void clearSelection() {
    state = state.copyWith(
      clearSelectedFile: true,
      clearFileName: true,
      clearMimeType: true,
      capturedImages: [],
      clearError: true,
    );
  }

  /// Sonucu temizle (yeni içerik oluştur - dosya korunur)
  void clearResult() {
    state = state.copyWith(
      clearResult: true,
      clearError: true,
      revealedAnswers: {},
      selectedAnswers: {},
    );
  }

  /// Tam sıfırlama
  void reset() {
    state = ContentGeneratorState.initial();
  }
}

/// Content Generator State Provider - keepAlive ile kalıcı
final contentGeneratorStateProvider =
    StateNotifierProvider<ContentGeneratorNotifier, ContentGeneratorState>((ref) {
  return ContentGeneratorNotifier();
});
