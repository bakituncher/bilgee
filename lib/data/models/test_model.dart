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
  // GÜVENLİ VE KAPSAMLI KONTROL (Final Sürüm)
  bool get isBranchTest {
    // 1. ÇOKLU DERS KONTROLÜ
    // Eğer denemede 1'den fazla ders (subject) varsa, bu kesinlikle bir ANA SINAVDIR.
    // Örnek: Sınıf Öğretmenliği (Temel Alan + Alan Eğitimi) veya TYT.
    if (scores.length > 1) {
      return false;
    }

    // Hata toleransı
    if (scores.isEmpty) return true;

    // String karşılaştırmalarını güvenli hale getirmek için hepsini büyük harfe çeviriyoruz.
    // Trim ile boşlukları temizliyoruz.
    final subjectName = scores.keys.first.toUpperCase().trim();
    final sectionUpper = sectionName.toUpperCase().trim();
    final examTypeUpper = examType.name.toUpperCase();

    // 2. ÖZEL BÖLÜM ADI KONTROLLERİ
    // YDT sınavı tek ders (Yabancı Dil) olsa bile ana sınavdır.
    if (sectionUpper == 'YDT' || sectionUpper.contains('YABANCI DİL TESTİ')) {
      return false;
    }

    // 3. AGS "ALAN BİLGİSİ" KONTROLÜ
    // Burası Türkçe Öğretmenliği, PDR vb. gibi tek dersli branşları kurtaran kısımdır.
    // Türkçe karakter sorununu (İ/I) aşmak için her iki varyasyonu da kontrol ediyoruz.
    if (subjectName == 'ALAN BİLGİSİ' || subjectName == 'ALAN BILGISI') {

      // Bu listedeki bölümler çok parçalıdır (Alan Bilgisi + Alan Eğitimi).
      // Bunlarda tek başına Alan Bilgisi çözülürse BRANŞ denemesi sayılmalıdır.
      final multiPartSections = [
        'OKUL ÖNCESİ', 'OKUL ONCESI', 'OKUL ÖNCESI',
        'ÖZEL EĞİTİM', 'OZEL EGITIM', 'ÖZEL EĞITIM', 'OZEL EĞİTİM'
      ];

      // Eğer kullanıcının bölümü bu istisna listesinde YOKSA (Örn: Türkçe, Matematik, Tarih),
      // o zaman "Alan Bilgisi" sınavın tamamıdır. Yani Ana Sınavdır.
      bool isMultiPart = multiPartSections.any((s) => sectionUpper.contains(s));

      if (!isMultiPart) {
        return false; // Çok parçalı değilse, Alan Bilgisi ana sınavdır.
      }
      // Çok parçalıysa (Özel Eğitim ise), burayı geçer ve aşağıda true döner (Branş olur).
    }

    // 4. KAPSAYICI DERS İSİMLERİ
    // YDT (Yabancı Dil) gibi tek derslik sınavları yakalamak için.
    final comprehensiveSubjectNames = [
      'YABANCI DİL',
      'YABANCI DİL TESTİ',
      'YABANCI DİL SINAVI',
      'YDT',
      'YDS',
      'YDT (YABANCI DİL TESTİ)', // YKS Yabancı Dil
      'YDS (YABANCI DİL SINAVI)', // AGS Yabancı Dil Öğretmenliği
    ];

    // Tam eşleşme veya contains kontrolü (parantezli isimler için)
    if (comprehensiveSubjectNames.contains(subjectName) ||
        subjectName.startsWith('YDT') ||
        subjectName.startsWith('YDS') ||
        subjectName.contains('YABANCI DİL')) {
      return false; // Ana Sınavdır
    }

    // 5. SINAV TÜRÜ EŞLEŞMESİ
    // Eğer bölüm adı sınav türüyle aynıysa ana sınavdır.
    if (sectionUpper == examTypeUpper) {
      return false;
    }

    // 6. GENEL ANAHTAR KELİMELER
    // "Genel" veya "Tümü" kelimeleri bölüm adının BAŞINDA geçiyorsa ana sınavdır.
    if (sectionUpper.startsWith('GENEL') || sectionUpper == 'TÜMÜ') {
      return false;
    }

    // Yukarıdaki şartların hiçbiri sağlanmadıysa, bu bir branş denemesidir.
    // Örnek: Sınıf Öğrt. "Temel Alan Bilgisi" (subjectName farklı olduğu için buraya düşer -> Branş)
    return true;
  }

  // Grafiklerde ve başlıklarda görünecek akıllı isim
  String get smartDisplayName {
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