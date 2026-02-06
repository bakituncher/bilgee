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
        return '❓';
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

  ContentCard({
    required this.title,
    required this.content,
    this.hint,
    this.answer,
  });

  factory ContentCard.fromJson(Map<String, dynamic> json) {
    return ContentCard(
      title: json['title'] ?? json['baslik'] ?? '',
      content: json['content'] ?? json['icerik'] ?? '',
      hint: json['hint'] ?? json['ipucu'],
      answer: json['answer'] ?? json['cevap'],
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
Sen bir sınav hazırlık uzmanısın. Gönderilen PDF veya görsel içindeki bilgileri analiz et ve öğrencinin kendini test edebileceği soru kartları oluştur.$examContext

GÖREVİN:
Verilen içerikten 5-10 adet soru kartı oluştur. Her soru, içerikteki önemli bir kavramı test etmeli.

KURALLAR:
1. Sorular açık ve anlaşılır olmalı.
2. Farklı zorluk seviyelerinde sorular oluştur (kolay, orta, zor).
3. Her sorunun bir ipucu ve doğru cevabı olmalı.
4. Sınavda çıkabilecek tarzda sorular sor.

JSON formatında yanıt ver:
{
  "cards": [
    {
      "title": "Soru",
      "content": "Soru metni buraya gelecek.",
      "hint": "Bu soruyu çözerken dikkat etmen gereken ipucu.",
      "answer": "Doğru cevap ve kısa açıklama."
    }
  ]
}

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
