// lib/features/home/logic/add_test_notifier.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/models/exam_model.dart';

// 1. Bu özelliğin tüm durumunu tutan "hafıza" modeli
class AddTestState extends Equatable {
  final int currentStep;
  final String testName;
  final List<ExamSection> availableSections;
  final ExamSection? selectedSection;
  final Map<String, Map<String, int>> scores;
  final bool isSaving;

  const AddTestState({
    this.currentStep = 0,
    this.testName = '',
    this.availableSections = const [],
    this.selectedSection,
    this.scores = const {},
    this.isSaving = false,
  });

  AddTestState copyWith({
    int? currentStep,
    String? testName,
    List<ExamSection>? availableSections,
    ExamSection? selectedSection,
    Map<String, Map<String, int>>? scores,
    bool? isSaving,
  }) {
    return AddTestState(
      currentStep: currentStep ?? this.currentStep,
      testName: testName ?? this.testName,
      availableSections: availableSections ?? this.availableSections,
      selectedSection: selectedSection ?? this.selectedSection,
      scores: scores ?? this.scores,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props => [currentStep, testName, availableSections, selectedSection, scores, isSaving];
}


// 2. Bu "hafızayı" yöneten "beyin" (Notifier)
class AddTestNotifier extends StateNotifier<AddTestState> {
  AddTestNotifier() : super(const AddTestState());

  // Komut: Sınav verisi yüklendi, durumu başlat.
  // DEĞİŞİKLİK: LGS için özel mantık eklendi.
  void initialize(List<ExamSection> sections, ExamType examType) {
    // Eğer sınav LGS ise ve birden fazla bölüm içeriyorsa (Sözel, Sayısal)...
    if (examType == ExamType.lgs && sections.length > 1) {
      // ...tüm dersleri tek bir haritada birleştir.
      final Map<String, SubjectDetails> combinedSubjects = {};
      for (var section in sections) {
        combinedSubjects.addAll(section.subjects);
      }
      // "LGS" adında yeni, birleşik bir sanal bölüm oluştur.
      final combinedSection = ExamSection(
        name: 'LGS', // Artık tek bir isim var.
        subjects: combinedSubjects,
        penaltyCoefficient: sections.first.penaltyCoefficient,
      );
      // Durumu, sadece bu birleşik bölümü içerecek şekilde güncelle.
      state = state.copyWith(
        availableSections: [combinedSection],
        selectedSection: combinedSection, // Ve otomatik olarak seç.
      );
    } else {
      // Diğer sınavlar için eski mantık devam ediyor.
      state = state.copyWith(availableSections: sections);
      if (sections.length == 1) {
        state = state.copyWith(selectedSection: sections.first);
      }
    }
  }

  // Komut: Test adını güncelle.
  void setTestName(String name) {
    state = state.copyWith(testName: name);
  }

  // Komut: Bölüm seç.
  void setSection(ExamSection? section) {
    state = state.copyWith(selectedSection: section);
  }

  // Komut: Bir sonraki adıma geç.
  void nextStep() {
    if (state.currentStep == 0) { // Adım 1'den 2'ye geçerken
      final section = state.selectedSection;
      if (section != null) {
        final initialScores = {
          for (var subject in section.subjects.keys)
            subject: {'dogru': 0, 'yanlis': 0}
        };
        state = state.copyWith(scores: initialScores, currentStep: 1);
      }
    } else if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  // Komut: Önceki adıma dön.
  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  // Komut: Puanları güncelle.
  void updateScores(String subject, {int? correct, int? wrong}) {
    final currentScores = Map<String, Map<String, int>>.from(state.scores);
    final subjectScores = Map<String, int>.from(currentScores[subject]!);

    if (correct != null) subjectScores['dogru'] = correct;
    if (wrong != null) subjectScores['yanlis'] = wrong;

    currentScores[subject] = subjectScores;
    state = state.copyWith(scores: currentScores);
  }

  // Komut: Kaydetme durumunu değiştir.
  void setSaving(bool isSaving) {
    state = state.copyWith(isSaving: isSaving);
  }
}

// 3. Bu beyni tüm birimlerin kullanmasını sağlayan "telsiz frekansı" (Provider)
final addTestProvider = StateNotifierProvider.autoDispose<AddTestNotifier, AddTestState>((ref) {
  return AddTestNotifier();
});