// lib/features/home/logic/add_test_notifier.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/exam_model.dart';

// STATE
class AddTestState extends Equatable {
  final int currentStep;
  final String testName;
  final List<ExamSection> availableSections;
  final ExamSection? selectedSection; // Genel seçim (TYT)
  final ExamSection? activeSection;   // Net girilecek asıl nesne (Sadece Mat olabilir)
  final Map<String, Map<String, int>> scores;
  final bool isSaving;

  // Branş Modu değişkenleri
  final bool isBranchMode;
  final String? selectedBranchSubject;

  const AddTestState({
    this.currentStep = 0,
    this.testName = '',
    this.availableSections = const [],
    this.selectedSection,
    this.activeSection,
    this.scores = const {},
    this.isSaving = false,
    this.isBranchMode = false,
    this.selectedBranchSubject,
  });

  AddTestState copyWith({
    int? currentStep,
    String? testName,
    List<ExamSection>? availableSections,
    ExamSection? selectedSection,
    ExamSection? activeSection,
    Map<String, Map<String, int>>? scores,
    bool? isSaving,
    bool? isBranchMode,
    String? selectedBranchSubject,
  }) {
    return AddTestState(
      currentStep: currentStep ?? this.currentStep,
      testName: testName ?? this.testName,
      availableSections: availableSections ?? this.availableSections,
      selectedSection: selectedSection ?? this.selectedSection,
      activeSection: activeSection ?? this.activeSection,
      scores: scores ?? this.scores,
      isSaving: isSaving ?? this.isSaving,
      isBranchMode: isBranchMode ?? this.isBranchMode,
      selectedBranchSubject: selectedBranchSubject ?? this.selectedBranchSubject,
    );
  }

  @override
  List<Object?> get props => [
    currentStep, testName, availableSections, selectedSection,
    activeSection, scores, isSaving, isBranchMode, selectedBranchSubject
  ];
}


// NOTIFIER
class AddTestNotifier extends StateNotifier<AddTestState> {
  AddTestNotifier() : super(const AddTestState());

  void initialize(List<ExamSection> sections, ExamType examType) {
    // LGS mantığı (Tek bölüm gibi davran)
    if (examType == ExamType.lgs && sections.length > 1) {
      final Map<String, SubjectDetails> combinedSubjects = {};
      for (var section in sections) {
        combinedSubjects.addAll(section.subjects);
      }
      final combinedSection = ExamSection(
        name: 'LGS',
        subjects: combinedSubjects,
        penaltyCoefficient: sections.first.penaltyCoefficient,
      );
      state = state.copyWith(
        availableSections: [combinedSection],
        selectedSection: combinedSection,
      );
    } else {
      state = state.copyWith(availableSections: sections);
      if (sections.length == 1) {
        state = state.copyWith(selectedSection: sections.first);
      }
    }
  }

  void setTestName(String name) {
    state = state.copyWith(testName: name);
  }

  void setSection(ExamSection? section) {
    state = state.copyWith(
      selectedSection: section,
      selectedBranchSubject: null, // Bölüm değişince ders seçimi sıfırlanır
    );
  }

  // Branş modunu aç/kapa
  void setBranchMode(bool isBranch) {
    state = state.copyWith(
      isBranchMode: isBranch,
      selectedBranchSubject: null, // Mod değişince seçim sıfırlanır
    );
  }

  // Branş için ders seçimi
  void setBranchSubject(String subject) {
    state = state.copyWith(selectedBranchSubject: subject);
  }

  void nextStep() {
    if (state.currentStep == 0) {
      // Adım 1'den 2'ye geçerken Active Section'ı oluştur
      final baseSection = state.selectedSection;

      if (baseSection != null) {
        ExamSection targetSection;

        // DÜZELTME: Seçilen bölüm tek dersten oluşuyorsa (YDT, AGS vb.),
        // kullanıcı "Branş" seçse bile bu aslında bir "Ana Sınav"dır.
        bool forceToGeneral = baseSection.subjects.length == 1;

        // Branş moduysa ve ders seçildiyse VE zorla genel yapılmayacaksa -> TEK DERSLİK BÖLÜM OLUŞTUR
        if (state.isBranchMode && state.selectedBranchSubject != null && !forceToGeneral) {
          final subjectName = state.selectedBranchSubject!;
          final subjectDetails = baseSection.subjects[subjectName]!;

          targetSection = ExamSection(
              name: subjectName, // Branş ismi (örn: Matematik)
              subjects: {subjectName: subjectDetails}, // Sadece seçilen ders
              penaltyCoefficient: baseSection.penaltyCoefficient,
              availableLanguages: baseSection.availableLanguages
          );
        } else {
          // Normal mod veya Tek dersli sınav (YDT/AGS) -> TÜM BÖLÜM (ANA SINAV)
          targetSection = baseSection;
        }

        // Puan haritasını sıfırla
        final initialScores = {
          for (var subject in targetSection.subjects.keys)
            subject: {'dogru': 0, 'yanlis': 0}
        };

        state = state.copyWith(
          scores: initialScores,
          currentStep: 1,
          activeSection: targetSection, // Step 2'de bunu kullanacağız
          // Eğer forceToGeneral devreye girdiyse, branch modunu kapatıyoruz ki ana sınav olarak kaydedilsin.
          isBranchMode: forceToGeneral ? false : state.isBranchMode,
        );
      }
    } else if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void updateScores(String subject, {int? correct, int? wrong}) {
    final currentScores = Map<String, Map<String, int>>.from(state.scores);
    final subjectScores = Map<String, int>.from(currentScores[subject]!);

    if (correct != null) subjectScores['dogru'] = correct;
    if (wrong != null) subjectScores['yanlis'] = wrong;

    currentScores[subject] = subjectScores;
    state = state.copyWith(scores: currentScores);
  }

  void setSaving(bool isSaving) {
    state = state.copyWith(isSaving: isSaving);
  }
}

final addTestProvider = StateNotifierProvider.autoDispose<AddTestNotifier, AddTestState>((ref) {
  return AddTestNotifier();
});