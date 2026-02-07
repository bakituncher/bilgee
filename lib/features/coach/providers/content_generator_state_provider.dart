import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/coach/services/content_generator_service.dart';

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

  const ContentGeneratorState({
    this.selectedFile,
    this.fileName,
    this.mimeType,
    this.capturedImages = const [],
    this.selectedContentType = ContentType.infoCards,
    this.isLoading = false,
    this.error,
    this.result,
    this.revealedAnswers = const {},
    this.selectedAnswers = const {},
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
    );
  }
}

/// Content Generator State Notifier
class ContentGeneratorNotifier extends StateNotifier<ContentGeneratorState> {
  ContentGeneratorNotifier() : super(ContentGeneratorState.initial());

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
    if (state.capturedImages.length >= 5) return;
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
