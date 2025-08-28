// lib/data/models/test_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/data/models/exam_model.dart';

class TestModel {
  final String id;
  final String userId;
  final String testName;
  final ExamType examType;
  final String sectionName;
  final DateTime date;
  final Map<String, Map<String, int>> scores; // { 'Türkçe': { 'dogru': 35, 'yanlis': 5, 'bos': 0 } }
  final double totalNet;
  final int totalQuestions;
  final int totalCorrect;
  final int totalWrong;
  final int totalBlank;
  final double penaltyCoefficient; // Net hesaplaması için katsayı

  TestModel({
    required this.id,
    required this.userId,
    required this.testName,
    required this.examType,
    required this.sectionName,
    required this.date,
    required this.scores,
    required this.totalNet,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalBlank,
    required this.penaltyCoefficient,
  });

  // Firestore'dan gelen veriyi modele çevirir
  factory TestModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final scoresData = (data['scores'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as Map<String, dynamic>).cast<String, int>()),
    );

    return TestModel(
      id: doc.id,
      userId: data['userId'],
      testName: data['testName'],
      examType: ExamType.values.byName(data['examType']),
      sectionName: data['sectionName'],
      date: (data['date'] as Timestamp).toDate(),
      scores: scoresData,
      totalNet: (data['totalNet'] as num).toDouble(),
      totalQuestions: data['totalQuestions'],
      totalCorrect: data['totalCorrect'],
      totalWrong: data['totalWrong'],
      totalBlank: data['totalBlank'],
      penaltyCoefficient: (data['penaltyCoefficient'] as num?)?.toDouble() ?? 0.25,
    );
  }

  // Modeli Firestore'a yazılacak JSON formatına çevirir
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'testName': testName,
      'examType': examType.name,
      'sectionName': sectionName,
      'date': Timestamp.fromDate(date),
      'scores': scores,
      'totalNet': totalNet,
      'totalQuestions': totalQuestions,
      'totalCorrect': totalCorrect,
      'totalWrong': totalWrong,
      'totalBlank': totalBlank,
      'penaltyCoefficient': penaltyCoefficient,
    };
  }
}

extension TestModelSummaryX on TestModel {
  // Kullanıcının performansına göre bir "Bilgelik Puanı" hesaplar.
  double get wisdomScore {
    if (totalQuestions == 0) return 0;

    // Netin katkısı (%60)
    final double netContribution = (totalNet / totalQuestions) * 60;

    // Doğruluk oranının katkısı (%25)
    final int attemptedQuestions = totalCorrect + totalWrong;
    final double accuracyContribution = attemptedQuestions > 0
        ? (totalCorrect / attemptedQuestions) * 25
        : 0;

    // Çaba/Katılım oranının katkısı (%15)
    final double effortContribution = (attemptedQuestions / totalQuestions) * 15;

    final double totalScore = netContribution + accuracyContribution + effortContribution;
    return totalScore.clamp(0, 100);
  }

  // Puan aralığına göre uzman yorumu ve unvanı döndürür.
  Map<String, String> get expertVerdict => getExpertVerdict(wisdomScore);

  Map<String, String> getExpertVerdict(double score) {
    if (score > 85) {
      return {
        "title": "Efsanevi Savaşçı",
        "verdict": "Zirvedeki yerin sarsılmaz. Bilgin bir kılıç gibi keskin, iraden ise bir zırh kadar sağlam. Bu yolda devam et, zafer seni bekliyor."
      };
    } else if (score > 70) {
      return {
        "title": "Usta Stratejist",
        "verdict": "Savaş meydanını okuyorsun. Güçlü ve zayıf yönlerini biliyorsun. Küçük gedikleri kapatarak yenilmez olacaksın. Potansiyelin parlıyor."
      };
    } else if (score > 50) {
      return {
        "title": "Yetenekli Savaşçı",
        "verdict": "Gücün ve cesaretin takdire şayan. Temellerin sağlam, ancak bazı hamlelerinde tereddüt var. Pratik ve odaklanma ile bu savaşı kazanacaksın."
      };
    } else if (score > 30) {
      return {
        "title": "Azimli Acemi",
        "verdict": "Her büyük savaşçı bu yoldan geçti. Kaybettiğin her mevzi, öğrendiğin yeni bir derstir. Azmin en büyük silahın, pes etme."
      };
    } else {
      return {
        "title": "Yolun Başındaki Kâşif",
        "verdict": "Unutma, en uzun yolculuklar tek bir adımla başlar. Bu ilk adımı attın. Şimdi hatalarından öğrenme ve güçlenme zamanı. Yanındayım."
      };
    }
  }

  // En güçlü ve en zayıf dersleri bulan fonksiyon
  Map<String, MapEntry<String, double>> findKeySubjects() {
    if (scores.isEmpty) {
      return {};
    }

    MapEntry<String, double>? strongest;
    MapEntry<String, double>? weakest;

    scores.forEach((subject, scoresMap) {
      final net = (scoresMap['dogru'] ?? 0) - ((scoresMap['yanlis'] ?? 0) * penaltyCoefficient);
      if (strongest == null || net > strongest!.value) {
        strongest = MapEntry(subject, net.toDouble());
      }
      if (weakest == null || net < weakest!.value) {
        weakest = MapEntry(subject, net.toDouble());
      }
    });

    if (strongest == null || weakest == null) return {};

    return {
      'strongest': strongest!,
      'weakest': weakest!,
    };
  }
}
