// lib/data/models/exam_model.dart
import 'dart:convert';
import 'package:flutter/services.dart';

// --- VERİ MODELLERİ (Bunlar değişmedi, sadece temizlendi) ---

enum ExamType {
  yks,
  lgs,
  kpssLisans,
  kpssOnlisans,
  kpssOrtaogretim,
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

  ExamSection({
    required this.name,
    required this.subjects,
    this.penaltyCoefficient = 0.25,
  });

  factory ExamSection.fromJson(Map<String, dynamic> json) {
    var subjectMap = (json['subjects'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, SubjectDetails.fromJson(value)),
    );
    return ExamSection(
      name: json['name'],
      subjects: subjectMap,
      penaltyCoefficient: (json['penaltyCoefficient'] as num).toDouble(),
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
    var sectionList = (json['sections'] as List)
        .map((section) => ExamSection.fromJson(section))
        .toList();
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