// lib/data/models/exam_model.dart
import 'dart:convert';
import 'package:flutter/services.dart';

enum ExamType {
  yks,
  lgs,
  kpssLisans,
  kpssOnlisans,
  kpssOrtaogretim,
  ags,
}

extension ExamTypeExtension on ExamType {
  String get displayName {
    switch (this) {
      case ExamType.yks:
        return 'YKS';
      case ExamType.lgs:
        return 'LGS';
      case ExamType.kpssLisans:
        return 'KPSS Lisans';
      case ExamType.kpssOnlisans:
        return 'KPSS Önlisans';
      case ExamType.kpssOrtaogretim:
        return 'KPSS Ortaöğretim';
      case ExamType.ags:
        return 'AGS'; // "AGS - ÖABT" yerine sadeleştirildi
    }
  }
}

class SubjectTopic {
  final String name;
  SubjectTopic({required this.name});

  factory SubjectTopic.fromJson(String json) {
    return SubjectTopic(name: json);
  }
}

class SubjectDetails {
  final int questionCount;
  final List<SubjectTopic> topics;
  SubjectDetails({required this.questionCount, required this.topics});

  factory SubjectDetails.fromJson(Map<String, dynamic> json) {
    var topicList = (json['topics'] as List)
        .map((topicName) => SubjectTopic.fromJson(topicName))
        .toList();
    return SubjectDetails(
      questionCount: json['questionCount'],
      topics: topicList,
    );
  }
}

class ExamSection {
  final String name;
  final Map<String, SubjectDetails> subjects;
  final double penaltyCoefficient;
  final List<String>? availableLanguages; // YDT için dil seçenekleri

  ExamSection({
    required this.name,
    required this.subjects,
    this.penaltyCoefficient = 0.25,
    this.availableLanguages,
  });

  factory ExamSection.fromJson(Map<String, dynamic> json) {
    var subjectMap = (json['subjects'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, SubjectDetails.fromJson(value)),
    );

    List<String>? languages;
    if (json.containsKey('availableLanguages')) {
      languages = (json['availableLanguages'] as List).cast<String>();
    }

    return ExamSection(
      name: json['name'],
      subjects: subjectMap,
      penaltyCoefficient: (json['penaltyCoefficient'] as num).toDouble(),
      availableLanguages: languages,
    );
  }
}

class Exam {
  final ExamType type;
  final String name;
  final List<ExamSection> sections;

  Exam({
    required this.type,
    required this.name,
    required this.sections,
  });

  factory Exam.fromJson(Map<String, dynamic> json, ExamType type) {
    List<ExamSection> sectionList;

    // AGS İÇİN GÜNCELLENMİŞ MANTIK
    // Ortak ve Branş oturumlarını birleştirmek yerine AYRI section'lar olarak oluşturuyoruz.
    if (type == ExamType.ags && json.containsKey('common') && json.containsKey('branches')) {
      sectionList = [];

      // 1. ADIM: "AGS Ortak" Bölümünü Oluştur (GY + GK + Eğitim)
      // Common altındaki tüm alt bölümleri tek bir havuzda topluyoruz.
      final commonSections = (json['common'] as Map<String, dynamic>)['sections'];
      final commonSubjects = (commonSections as List)
          .map((section) => section['subjects'] as Map<String, dynamic>)
          .expand((subjects) => subjects.entries)
          .fold<Map<String, dynamic>>({}, (map, entry) {
        map[entry.key] = entry.value;
        return map;
      });

      sectionList.add(ExamSection(
        name: 'AGS',
        subjects: commonSubjects.map(
          (key, value) => MapEntry(key, SubjectDetails.fromJson(value)),
        ),
        penaltyCoefficient:
            (json['common']['penaltyCoefficient'] as num?)?.toDouble() ?? 0.25,
      ));

      // 2. ADIM: Branş (Alan) Bölümlerini Oluştur
      // Her branşı, sadece kendi konularını içeren ayrı bir section olarak ekliyoruz.
      final branches = json['branches'] as List;
      for (var branch in branches) {
        final branchName = branch['name'] as String;
        final branchSubjects = branch['subjects'] as Map<String, dynamic>;

        sectionList.add(ExamSection(
          name: branchName, // Örn: "Türkçe Öğretmenliği"
          subjects: branchSubjects.map(
            (key, value) => MapEntry(key, SubjectDetails.fromJson(value)),
          ),
          penaltyCoefficient:
              (json['common']['penaltyCoefficient'] as num?)?.toDouble() ?? 0.25,
        ));
      }
    } else {
      // Diğer sınavlar (YKS, LGS, KPSS) için standart parsing
      sectionList = (json['sections'] as List)
          .map((section) => ExamSection.fromJson(section))
          .toList();
    }

    return Exam(
      type: type,
      name: json['name'],
      sections: sectionList,
    );
  }
}


// --- YENİ MÜHİMMAT SUBAYI: ExamData ---

class ExamData {
  // Veriyi yükledikten sonra hafızada tutmak için (performans)
  static final Map<ExamType, Exam> _cache = {};

  // JSON dosyasından veriyi okuyup Exam objesine dönüştüren özel operasyon
  static Future<Exam> _loadExam(ExamType type, String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final jsonResponse = json.decode(jsonString);
    // KPSS'nin tüm türleri aynı JSON'u kullanır, bu yüzden tipi dışarıdan veriyoruz.
    if(type == ExamType.kpssLisans || type == ExamType.kpssOnlisans || type == ExamType.kpssOrtaogretim){
      return Exam.fromJson(jsonResponse, type);
    }
    return Exam.fromJson(jsonResponse, ExamType.values.byName(jsonResponse['type']));
  }

  // Uygulamanın herhangi bir yerinden bir sınava ulaşmak için kullanılacak ana komut
  static Future<Exam> getExamByType(ExamType type) async {
    // Eğer mühimmat zaten yüklenmişse, tekrar sığınağa inme, hafızadakini kullan.
    if (_cache.containsKey(type)) {
      return _cache[type]!;
    }

    // Mühimmat ilk defa isteniyorsa, sığınaktan (JSON) yükle.
    switch (type) {
      case ExamType.yks:
        final exam = await _loadExam(type, 'assets/data/yks.json');
        _cache[type] = exam;
        return exam;
      case ExamType.lgs:
        final exam = await _loadExam(type, 'assets/data/lgs.json');
        _cache[type] = exam;
        return exam;
      case ExamType.ags:
        final exam = await _loadExam(type, 'assets/data/ags.json');
        _cache[type] = exam;
        return exam;
      case ExamType.kpssLisans:
      case ExamType.kpssOnlisans:
      case ExamType.kpssOrtaogretim:
        final exam = await _loadExam(type, 'assets/data/kpss.json');
        // KPSS'nin tüm türleri aynı yapıya sahip olduğundan, hepsi için cache'e ekleyebiliriz.
        _cache[ExamType.kpssLisans] = exam;
        _cache[ExamType.kpssOnlisans] = exam;
        _cache[ExamType.kpssOrtaogretim] = exam;
        return exam;
      default:
        throw Exception('$type için sınav verisi bulunamadı.');
    }
  }
}