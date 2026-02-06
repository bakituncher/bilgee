import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// İçerik üretici türleri
enum ContentType {
  infoCards,    // Bilgi Kartları
  questionCards, // Soru Kartları
  summary,      // Özet
}

extension ContentTypeExtension on ContentType {
  String get displayName {
    switch (this) {
      case ContentType.infoCards:
        return 'Bilgi Kartları';
      case ContentType.questionCards:
        return 'Soru Kartları';
      case ContentType.summary:
        return 'Özet';
    }
  }

  String get icon {
    switch (this) {
      case ContentType.infoCards:
        return '📚';
      case ContentType.questionCards:
        return '✅';
      case ContentType.summary:
        return '📝';
    }
  }
}

/// Üretilen içerik modeli
class GeneratedContent {
  final ContentType type;
  final String rawContent;
  final List<ContentCard>? cards; // Kartlar için
  final String? summary; // Özet için
  final DateTime generatedAt;

  GeneratedContent({
    required this.type,
    required this.rawContent,
    this.cards,
    this.summary,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();
}

/// Kart modeli (Bilgi kartları ve soru kartları için)
class ContentCard {
  final String title;
  final String content;
  final String? hint; // Soru kartları için ipucu
  final String? answer; // Soru kartları için cevap
  final List<String>? options; // Test şıkları (A, B, C, D)
  final int? correctIndex; // Doğru şık indeksi (0-3)

  ContentCard({
    required this.title,
    required this.content,
    this.hint,
    this.answer,
    this.options,
    this.correctIndex,
  });

  factory ContentCard.fromJson(Map<String, dynamic> json) {
    // Şıkları parse et
    List<String>? options;
    if (json['options'] != null) {
      options = (json['options'] as List).map((e) => e.toString()).toList();
    } else if (json['siklar'] != null) {
      options = (json['siklar'] as List).map((e) => e.toString()).toList();
    }

    // Doğru cevap indeksini parse et
    int? correctIndex;
    if (json['correctIndex'] != null) {
      correctIndex = json['correctIndex'] as int;
    } else if (json['dogruIndex'] != null) {
      correctIndex = json['dogruIndex'] as int;
    } else if (json['correct_index'] != null) {
      correctIndex = json['correct_index'] as int;
    }

    return ContentCard(
      title: json['title'] ?? json['baslik'] ?? '',
      content: json['content'] ?? json['icerik'] ?? json['question'] ?? json['soru'] ?? '',
      hint: json['hint'] ?? json['ipucu'],
      answer: json['answer'] ?? json['cevap'] ?? json['explanation'] ?? json['aciklama'],
      options: options,
      correctIndex: correctIndex,
    );
  }
}

// Provider tanımı
final contentGeneratorServiceProvider = Provider<ContentGeneratorService>((ref) {
  return ContentGeneratorService();
});

class ContentGeneratorService {
  ContentGeneratorService();

  /// PDF veya görsel dosyasından içerik üretir
  Future<GeneratedContent> generateContent({
    required File file,
    required ContentType contentType,
    required String mimeType,
    String? examType,
  }) async {
    try {
      // Dosyayı oku ve sıkıştır (görsel ise)
      final Uint8List bytes = await _processFile(file, mimeType);

      // Base64 encode
      final b64 = base64Encode(bytes);

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('ai-generateGemini');

      final prompt = _buildPrompt(contentType, examType);

      final result = await callable
          .call({
            'prompt': prompt,
            'expectJson': true, // JSON formatında yanıt bekliyoruz
            'requestType': 'content_generator',
            'imageBase64': b64,
            'imageMimeType': mimeType,
            'maxOutputTokens': 10000,
            'temperature': 0.4, // Tutarlı çıktılar için düşük sıcaklık
          })
          .timeout(const Duration(minutes: 5));

      final data = result.data;
      final rawResponse = (data is Map && data['raw'] is String)
          ? (data['raw'] as String).trim()
          : '';

      if (rawResponse.isEmpty) {
        throw Exception('İçerik üretilemedi. Lütfen tekrar deneyin.');
      }

      // JSON'u parse et
      return _parseResponse(rawResponse, contentType);
    } on FirebaseFunctionsException catch (e) {
      final msg = e.message ?? 'AI hizmeti hatası. Lütfen tekrar deneyin.';
      throw Exception(msg);
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  /// Dosyayı işle - görsel ise sıkıştır
  Future<Uint8List> _processFile(File file, String mimeType) async {
    // PDF dosyası doğrudan okunur
    if (mimeType == 'application/pdf') {
      return await file.readAsBytes();
    }

    // Görsel dosyaları sıkıştır
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      if (result != null && result.isNotEmpty) return result;
    } catch (_) {
      // fall through
    }
    return await file.readAsBytes();
  }

  /// İçerik türüne göre prompt oluştur
  String _buildPrompt(ContentType contentType, String? examType) {
    String examContext = '';
    if (examType != null && examType.isNotEmpty) {
      examContext = '\n\n**SINAV BAĞLAMI:** İçeriği **$examType** sınavına hazırlanan öğrenciler için uygun şekilde hazırla.';
    }

    switch (contentType) {
      case ContentType.infoCards:
        return '''
Sen bir eğitim içeriği uzmanısın. Gönderilen PDF veya görsel içindeki bilgileri analiz et ve öğrenci dostu bilgi kartlarına dönüştür.$examContext

GÖREVİN:
Verilen içerikten 5-10 adet bilgi kartı oluştur. Her kart, tek bir kavram veya bilgiyi açıkça anlatmalı.

KURALLAR:
1. Her kart kısa, öz ve akılda kalıcı olmalı.
2. Karmaşık konuları basitleştir.
3. Görsel dil kullan (emoji, vurgu vb.)
4. Bilgileri öncelik sırasına göre düzenle.

JSON formatında yanıt ver:
{
  "cards": [
    {
      "title": "Kart Başlığı",
      "content": "Kartın açıklaması veya bilgisi. Markdown formatında olabilir."
    }
  ]
}

SADECE JSON döndür, başka hiçbir şey yazma.
''';

      case ContentType.questionCards:
        return '''
Sen bir sınav hazırlık uzmanısın. Gönderilen PDF veya görsel içindeki bilgileri analiz et ve çoktan seçmeli test soruları oluştur.$examContext

GÖREVİN:
Verilen içerikten 5-10 adet çoktan seçmeli test sorusu oluştur. Her soru 4 şıklı (A, B, C, D) olmalı.

KURALLAR:
1. Sorular net, anlaşılır ve sınav formatında olmalı.
2. Her sorunun 4 şıkkı olmalı, sadece 1 tanesi doğru.
3. Şıklar mantıklı ve birbirine yakın olmalı (çeldirici şıklar).
4. Farklı zorluk seviyelerinde sorular oluştur.
5. Her sorunun kısa bir açıklaması (neden doğru cevap bu) olmalı.

JSON formatında yanıt ver:
{
  "cards": [
    {
      "title": "Soru 1",
      "content": "Soru metni buraya gelecek?",
      "options": ["A şıkkı metni", "B şıkkı metni", "C şıkkı metni", "D şıkkı metni"],
      "correctIndex": 0,
      "explanation": "Doğru cevap A çünkü..."
    }
  ]
}

ÖNEMLİ: correctIndex 0'dan başlar (0=A, 1=B, 2=C, 3=D).
SADECE JSON döndür, başka hiçbir şey yazma.
''';

      case ContentType.summary:
        return '''
Sen bir özetleme uzmanısın. Gönderilen PDF veya görsel içindeki bilgileri analiz et ve kapsamlı bir özet oluştur.$examContext

GÖREVİN:
Verilen içeriğin önemli noktalarını vurgulayan, akıcı ve öğrenci dostu bir özet hazırla.

KURALLAR:
1. Ana konuları ve alt başlıkları belirle.
2. Önemli kavramları vurgula.
3. Gereksiz detayları ele, özü çıkar.
4. Markdown formatında (başlıklar, listeler, kalın yazı) düzenle.
5. En alta "📌 Hatırlatma" başlığıyla 3-5 maddelik kritik noktalar ekle.

JSON formatında yanıt ver:
{
  "summary": "Markdown formatında özet metni buraya gelecek."
}

SADECE JSON döndür, başka hiçbir şey yazma.
''';
    }
  }

  /// API yanıtını parse et
  GeneratedContent _parseResponse(String rawResponse, ContentType contentType) {
    try {
      // JSON temizleme (bazen ```json ile sarılı gelebilir)
      String cleanJson = rawResponse;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> json = jsonDecode(cleanJson);

      if (contentType == ContentType.summary) {
        return GeneratedContent(
          type: contentType,
          rawContent: rawResponse,
          summary: json['summary'] ?? json['ozet'] ?? '',
        );
      } else {
        final List<dynamic> cardsJson = json['cards'] ?? json['kartlar'] ?? [];
        final cards = cardsJson
            .map((c) => ContentCard.fromJson(c as Map<String, dynamic>))
            .toList();

        return GeneratedContent(
          type: contentType,
          rawContent: rawResponse,
          cards: cards,
        );
      }
    } catch (e) {
      // JSON parse hatası durumunda raw içeriği döndür
      return GeneratedContent(
        type: contentType,
        rawContent: rawResponse,
        summary: contentType == ContentType.summary ? rawResponse : null,
      );
    }
  }

  /// MIME türünü dosya uzantısından belirle
  static String getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
