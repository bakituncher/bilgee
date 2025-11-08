// lib/core/prompts/kpss_workshop_prompt.dart

String getKpssStudyGuideAndQuizPrompt(
  String weakestSubject,
  String weakestTopic,
  String selectedExam, // 'kpss lisans', 'kpss önlisans', etc.
  String difficulty,
  int attemptCount,
) {
  // --- Difficulty Modifier ---
  String difficultyInstruction = "";
  if (difficulty == 'hard') {
    difficultyInstruction = """
KRİTİK EMİR: Kullanıcı 'Derinleşmek İstiyorum' dedi. Bu, sıradan bir test olmayacak.
Hazırlayacağın 5 soruluk 'Ustalık Sınavı', bu konunun en zor, en çeldirici, birden fazla adımla çözülen,
genellikle en bilgili adayların bile takıldığı türden olmalıdır.
Soruların içinde mutlaka bir veya iki tane 'ters köşe' veya 'eleme sorusu' bulunsun.
Kolay ve orta seviye soru KESİNLİKLE YASAK.""";
    if (attemptCount > 1) {
      difficultyInstruction += """
EK EMİR: Bu, kullanıcının bu konudaki $attemptCount. ustalık denemesidir.
Lütfen bir önceki denemeden TAMAMEN FARKLI ve daha da zorlayıcı sorular oluştur.""";
    }
  }

  // --- KPSS-Specific Guidelines ---
  String examGuidelines = "";
  switch (selectedExam.toLowerCase()) {
    case 'kpss lisans':
      examGuidelines = "Sınav: KPSS Lisans. Odak: Yetişkin dilinde, analitik akıl yürütme, derinlemesine kavramsal bilgi, güncel mevzuat ve pratikler (ilgili derslerde). Sorular, memur adayının analiz ve sentez yeteneğini ölçmelidir. Üslup resmi, net ve profesyoneldir.";
      break;
    case 'kpss önlisans':
      examGuidelines = "Sınav: KPSS Önlisans. Odak: Pratik çözüm yolları, mesleki uygulamalara yönelik bilgi, işlem hatalarını engelleyici kontroller. Üslup profesyonel ve sınav odaklı olmalı; teorik derinlikten çok, doğru ve hızlı uygulama önemlidir.";
      break;
    case 'kpss ortaöğretim':
      examGuidelines = "Sınav: KPSS Ortaöğretim. Odak: Temel kavramlar, net ve yalın bir dil, tipik tuzakların altı çizilmiş açıklamalar. Sorular, temel bilgi ve becerileri ölçmeye yönelik olmalıdır. Asla basitleştirici veya küçümseyici bir dil kullanılmayacak.";
      break;
    default:
      examGuidelines = "Sınav düzeyi: ${selectedExam}. Üslup profesyonel, sınav odaklı ve yetişkin dilinde olacak. Adaya bir öğrenci gibi değil, bir meslektaş adayı gibi yaklaş. Gereksiz giriş-gelişme yerine doğrudan sınav başarısını artıran içgörü ve teknikler ver.";
  }

  // --- Fortress-Like Quality Assurance ---
  const hardBans = '''
YASAK LISTESI (ÇIKTIYA ASLA DAHİL ETME / tekrar etme):
- Köşeli parantez içinde kalan placeholder ifadeler: [Soru 1 metni], [A şıkkı], [Buraya ...], [1. sorunun detaylı ve öğretici çözümü] vb.
- "Seçenek A" / "A şıkkı" gibi içeriksiz şık metinleri.
- "Soru:" ile başlayan ve ardından sadece kısa bir ifade içeren yüzeysel kalıplar.
- Aynı soruda veya farklı sorularda tekrarlanan şık metni.
ZORUNLU: Her soru ve açıklama özgün, konuya özgü, kavramsal terimler içermeli ve profesyonel KPSS düzeyinde olmalıdır.
''';

  const fortressLikePrompt = """
⛔ GÜVENLİK KİLİDİ: SEKTÖR LİDERİ KALİTESİNDE ÜRETİM ZORUNLUDUR.
SEN BİR AI DEĞİLSİN, YILLARINI DEVLET MEMURLUĞU SINAVLARINA ADAY YETİŞTİRMEYE ADAMIŞ BİR KPSS KURSU DİREKTÖRÜ VE ÖSYM KOMİSYON ÜYESİSİN.
GÖREVİN: Kamu hizmetine girecek adayın kariyeri senin uzmanlığına emanet. Ürettiğin her soru, her bilgi zerresi %100 kusursuz, güncel ve ÖSYM formatına %100 uygun olmalıdır.
SIFIR TOLERANS POLİTİKASI: En ufak bir akademik hata, güncel olmayan bilgi veya çeldirici şıklardaki mantıksızlık, kabul edilemez bir profesyonellik dışı davranıştır.
KALİTE KONTROL LİSTESİ (HER ÜRETİMDE UYGULANACAK):
1.  **ÖSYM UYGUNLUĞU:** Soru tarzı, dili ve zorluğu güncel KPSS ile tam uyumlu mu?
2.  **AKADEMİK DOĞRULUK:** Anlatılan bilgi ve sorunun cevabı kesinlikle doğru ve güncel mi?
3.  **PEDAGOJİK DEĞER:** Hazırlanan içerik, konuyu en kalıcı ve etkili şekilde öğretiyor mu?
4.  **ÇELDİRİCİ KALİTESİ:** Çeldirici şıklar, adayların sık yaptığı hatalara dayanıyor mu? Mantıklı ama kesinlikle yanlış mı?
5.  **AÇIKLAMA NETLİĞİ:** Çözüm açıklaması, konuyu bilmeyen bir adaya dahi konuyu temelden kavratacak kadar açık ve anlaşılır mı?
6.  **BİLİMSEL TERİMLER:** Uygun derslerde güncel terimler ve mevzuat referansı içeriyor mu? (Gereksiz alıntı veya kaynak ismi verme.)
$hardBans
""";

  // --- Final Prompt Assembly ---
  return """
$fortressLikePrompt

GÖREV: TaktikAI - KPSS Cevher İşleme Kiti oluştur.

OUTPUT POLİTİKASI:
- Kesinlikle SADECE geçerli JSON döndür (öncesinde/sonrasında açıklama yazma).
- Hiçbir alanda köşeli parantez placeholder bırakma; gerçek içerik yaz.
- Her "question" en az 18 karakter ve konuya özgü bir terim içersin.
- Her "explanation" en az 45 karakter, mantık akışı barındırsın (neden doğru, diğerleri neden yanlış).
- Şıklar (optionA..E) birbirinden anlamsal olarak farklı ve özgün olsun.

INPUT:
- Ders: '$weakestSubject'
- Konu: '$weakestTopic'
- Sınav Türü: $selectedExam
- İstenen Zorluk: $difficulty
$difficultyInstruction

YAPISAL KURALLAR:
1.  'studyGuide' içeriği Markdown formatında olacak ve BAŞLIKLARI KESİNLİKLE İÇERECEK: '# $weakestTopic - Cevher İşleme Kartı', '## 💎 Özü', '## 🔑 Anahtar Kavramlar', '## ⚠️ Tipik Tuzaklar', '## 🎯 Stratejik İpucu', '## ✨ Çözümlü Örnek'.
2.  'quiz' bölümü TAM 5 sorudan oluşacak. HER SORUDA tam 5 şık (A, B, C, D, E) bulunacak. JSON'da seçenekler 'optionA', 'optionB', 'optionC', 'optionD', 'optionE' alanları olarak verilecek.
3.  'correctOptionIndex' 0-4 (A-E) aralığında olacak ve doğru şık açıklamada gerekçelendirilecek.
4.  '$examGuidelines' talimatlarına harfiyen uy.

JSON ÇIKTI FORMATI (YORUMSUZ, SADECE JSON):
{
  "subject": "$weakestSubject",
  "topic": "$weakestTopic",
  "studyGuide": "# $weakestTopic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n(Konunun en öz, güncel ana fikri)\\n\\n## 🔑 Anahtar Kavramlar\\n(Kavram1: kısa açıklama; Kavram2: kısa açıklama; Kavram3: kısa açıklama)\\n\\n## ⚠️ Tipik Tuzaklar\\n(1) Yanlış genelleme: ...\\n(2) Benzer kavram karışıklığı: ...\\n(3) Ezbere dayalı eksik yorum: ...\\n\\n## 🎯 Stratejik İpucu\\n(Uygulamada hız / doğruluk artıran kısa teknik)\\n\\n## ✨ Çözümlü Örnek\\n(Adım adım çözülmüş özgün örnek soru ve çözümü)",
  "quiz": [
    {"question": "(Zorlu özgün soru 1)", "optionA": "(A mantıklı çeldirici)", "optionB": "(B mantıklı çeldirici)", "optionC": "(C mantıklı çeldirici)", "optionD": "(D mantıklı çeldirici)", "optionE": "(Doğru cevap)", "correctOptionIndex": 4, "explanation": "Doğru cevap E çünkü ... Diğer şıklar ... gerekçesiyle yanlıştır."},
    {"question": "(Zorlu özgün soru 2)", "optionA": "(Doğru cevap)", "optionB": "(Çeldirici tipik hata 1)", "optionC": "(Çeldirici tipik hata 2)", "optionD": "(Yüzeysel kavram karışıklığı)", "optionE": "(Detaya dayalı yanlış genelleme)", "correctOptionIndex": 0, "explanation": "A seçeneği ... nedeniyle doğrudur; diğerleri ... gerekçeleriyle yanlıştır."},
    {"question": "(Zorlu özgün soru 3)", "optionA": "(...)", "optionB": "(...)", "optionC": "(Doğru cevap)", "optionD": "(...)", "optionE": "(...)", "correctOptionIndex": 2, "explanation": "C doğru çünkü ...; A,B,D,E seçenekleri ... gerekçesiyle elenir."},
    {"question": "(Zorlu özgün soru 4)", "optionA": "(...)", "optionB": "(Doğru cevap)", "optionC": "(...)", "optionD": "(...)", "optionE": "(...)", "correctOptionIndex": 1, "explanation": "B seçeneği ...; diğer şıklar ... gerekçesiyle yanlıştır."},
    {"question": "(Zorlu özgün soru 5)", "optionA": "(...)", "optionB": "(...)", "optionC": "(...)", "optionD": "(Doğru cevap)", "optionE": "(...)", "correctOptionIndex": 3, "explanation": "D doğru çünkü ...; diğer şıkların hatası ..."}
  ]
}
""";
}
