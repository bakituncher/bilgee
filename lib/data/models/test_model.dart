// lib/data/models/test_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/data/models/exam_model.dart';

class TestModel {
  final String id;
  final String userId;
  final String testName;
  final ExamType examType;
  final String sectionName;
  final DateTime date;
  final Map<String, Map<String, int>> scores;
  final double totalNet;
  final int totalQuestions;
  final int totalCorrect;
  final int totalWrong;
  final int totalBlank;
  final double penaltyCoefficient;

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

  factory TestModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final scoresData = (data['scores'] as Map<String, dynamic>).map(
          (key, value) =>
          MapEntry(key, (value as Map<String, dynamic>).cast<String, int>()),
    );

    return TestModel(
      id: doc.id,
      userId: data['userId'],
      testName: data['testName'] ?? '',
      examType: ExamType.values.byName(data['examType']),
      sectionName: data['sectionName'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      scores: scoresData,
      totalNet: (data['totalNet'] as num).toDouble(),
      totalQuestions: data['totalQuestions'] ?? 0,
      totalCorrect: data['totalCorrect'] ?? 0,
      totalWrong: data['totalWrong'] ?? 0,
      totalBlank: data['totalBlank'] ?? 0,
      penaltyCoefficient:
      (data['penaltyCoefficient'] as num?)?.toDouble() ?? 0.25,
    );
  }

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
  // GÜNCELLENMİŞ MANTIK: İsim listesine bağımlılığı ortadan kaldıran evrensel çözüm
  bool get isBranchTest {
    // 1. ÇOKLU DERS KONTROLÜ (En güçlü ve genel kural)
    // Uygulamanızın mantığında bir "Branş Denemesi" oluştururken sadece tek bir ders seçilebiliyor.
    // Dolayısıyla, bir denemede 1'den fazla ders (subject) varsa, bu kesinlikle bir ANA SINAVDIR.
    // Bu kural TYT, LGS ve çok dersli ÖABT branşlarını (Örn: Sınıf Öğretmenliği -> Temel Alan + Alan Eğitimi) otomatik kapsar.
    if (scores.length > 1) {
      return false;
    }

    // Eğer buraya geldiysek deneme TEK DERSTEN oluşuyor demektir.
    if (scores.isEmpty) return true; // Hata toleransı

    final subjectName = scores.keys.first.toUpperCase().trim();
    final sectionUpper = sectionName.toUpperCase().trim();
    final examTypeUpper = examType.name.toUpperCase();

    // 2. KAPSAYICI DERS İSİMLERİ (Tek ders olsa bile tüm sınavı temsil edenler)
    // YDT (Yabancı Dil) veya ÖABT (Alan Bilgisi) gibi tek derslik sınavları yakalamak için
    // sadece dersin adına bakarız. Bölüm adını ("Fizik", "Tarih") bilmemize gerek kalmaz.
    final comprehensiveSubjectNames = [
      'ALAN BİLGİSİ',
      'ALAN BILGISI',
      'YABANCI DİL',
      'YABANCI DIL',
    ];

    if (comprehensiveSubjectNames.contains(subjectName)) {
      return false; // Ana Sınavdır
    }

    // 3. SINAV TÜRÜ EŞLEŞMESİ
    // Eğer bölüm adı sınav türüyle aynıysa (Örn: Section: YDT, Exam: YDT) ana sınavdır.
    if (sectionUpper == examTypeUpper) {
      return false;
    }

    // 4. GENEL ANAHTAR KELİMELER (DÜZELTİLDİ)
    // "Genel" veya "Tümü" kelimeleri bölüm adının BAŞINDA geçiyorsa ana sınavdır.
    // contains yerine startsWith kullanıldı. Böylece "Tarih (Genel Kültür)" gibi
    // parantez içi kullanımlar yanlışlıkla ana sınav sayılmayacak.
    if (sectionUpper.startsWith('GENEL') || sectionUpper == 'TÜMÜ') {
      return false;
    }

    // Yukarıdaki şartların hiçbiri sağlanmadıysa, bu bir branş denemesidir.
    // (Örn: TYT sınavında sadece "Matematik" çözüldüyse veya KPSS'de sadece "Tarih" çözüldüyse)
    return true;
  }

  // Grafiklerde ve başlıklarda görünecek akıllı isim
  String get smartDisplayName {
    // Branş denemesi ise dersin adını (Örn: İngilizce), değilse bölüm adını (Örn: YDT) döndürür.
    if (isBranchTest && scores.isNotEmpty) {
      return scores.keys.first;
    }
    return sectionName;
  }

  double get wisdomScore {
    if (totalQuestions == 0) return 0;
    final double netContribution = (totalNet / totalQuestions) * 60;
    final int attemptedQuestions = totalCorrect + totalWrong;
    final double accuracyContribution = attemptedQuestions > 0
        ? (totalCorrect / attemptedQuestions) * 25
        : 0;
    final double effortContribution =
        (attemptedQuestions / totalQuestions) * 15;
    final double totalScore =
        netContribution + accuracyContribution + effortContribution;
    return totalScore.clamp(0, 100);
  }

  Map<String, String> get expertVerdict => getExpertVerdict(wisdomScore);

  Map<String, String> getExpertVerdict(double score) {
    if (score > 85) {
      return {
        "title": "Efsanevi Savaşçı",
        "verdict":
        "Zirvedeki yerin sarsılmaz. Bilgin bir kılıç gibi keskin, iraden ise bir zırh kadar sağlam. Bu yolda devam et, zafer seni bekliyor."
      };
    } else if (score > 70) {
      return {
        "title": "Usta Stratejist",
        "verdict":
        "Savaş meydanını okuyorsun. Güçlü ve zayıf yönlerini biliyorsun. Küçük gedikleri kapatarak yenilmez olacaksın. Potansiyelin parlıyor."
      };
    } else if (score > 50) {
      return {
        "title": "Yetenekli Savaşçı",
        "verdict":
        "Gücün ve cesaretin takdire şayan. Temellerin sağlam, ancak bazı hamlelerinde tereddüt var. Pratik ve odaklanma ile bu savaşı kazanacaksın."
      };
    } else if (score > 30) {
      return {
        "title": "Azimli Acemi",
        "verdict":
        "Her büyük savaşçı bu yoldan geçti. Kaybettiğin her mevzi, öğrendiğin yeni bir derstir. Azmin en büyük silahın, pes etme."
      };
    } else {
      return {
        "title": "Yolun Başındaki Kâşif",
        "verdict":
        "Unutma, en uzun yolculuklar tek bir adımla başlar. Bu ilk adımı attın. Şimdi hatalarından öğrenme ve güçlenme zamanı. Yanındayım."
      };
    }
  }

  Map<String, MapEntry<String, double>> findKeySubjects() {
    if (scores.isEmpty) return {};

    MapEntry<String, double>? strongest;
    MapEntry<String, double>? weakest;

    for (final entry in scores.entries) {
      final subject = entry.key;
      final scoresMap = entry.value;
      final d = scoresMap['dogru'] ?? 0;
      final y = scoresMap['yanlis'] ?? 0;
      final b = scoresMap['bos'] ?? 0;
      final totalQuestions = d + y + b;

      if (totalQuestions == 0) continue;
      final accuracy = (d / totalQuestions) * 100.0;

      if (strongest == null || accuracy > strongest.value) {
        strongest = MapEntry(subject, accuracy);
      }
      if (weakest == null || accuracy < weakest.value) {
        weakest = MapEntry(subject, accuracy);
      }
    }

    if (strongest == null || weakest == null) return {};
    return {'strongest': strongest, 'weakest': weakest};
  }
}