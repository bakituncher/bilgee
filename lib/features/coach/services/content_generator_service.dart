import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/prompts/content_generator_prompts.dart';

/// İçerik üretici türleri
enum ContentType {
  flashcard,    // Flashcard Kartları (eski infoCards)
  quiz,         // Quiz Soruları (eski questionCards)
  summary,      // Özet
  mnemonic,     // Kodlama (Hafıza Teknikleri)
}

extension ContentTypeExtension on ContentType {
  String get displayName {
    switch (this) {
      case ContentType.flashcard:
        return 'Flashcard';
      case ContentType.quiz:
        return 'Quiz';
      case ContentType.summary:
        return 'Özet';
      case ContentType.mnemonic:
        return 'Kodlama';
    }
  }

  /// Kısa isim (UI için)
  String get shortName {
    switch (this) {
      case ContentType.flashcard:
        return 'Flashcard';
      case ContentType.quiz:
        return 'Quiz';
      case ContentType.summary:
        return 'Özet';
      case ContentType.mnemonic:
        return 'Kodlama';
    }
  }
}

/// Üretilen içerik modeli
class GeneratedContent {
  final ContentType type;
  final String rawContent;
  final List<ContentCard>? cards; // Kartlar için
  final String? summary; // Özet için
  final String? topic; // Konu başlığı
  final DateTime generatedAt;

  GeneratedContent({
    required this.type,
    required this.rawContent,
    this.cards,
    this.summary,
    this.topic,
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

  /// Maksimum yükleme boyutu (10MB)
  static const int maxUploadSize = 10 * 1024 * 1024;
  /// Firebase Functions için güvenli gönderim sınırı (~7MB payload)
  static const int _safePayloadSize = 7 * 1024 * 1024;

  /// PDF veya görsel dosyasından içerik üretir
  Future<GeneratedContent> generateContent({
    required File file,
    required ContentType contentType,
    required String mimeType,
    String? examType,
  }) async {
    try {
      // Dosya boyutu kontrolü
      final fileSize = await file.length();
      if (fileSize > maxUploadSize) {
        throw Exception('Dosya çok büyük (Maksimum 10MB). Lütfen daha küçük bir dosya seçin.');
      }

      // Dosyayı oku ve sıkıştır (görsel ise)
      final Uint8List bytes = await _processFile(file, mimeType);

      // Sıkıştırma sonrası kontrol
      if (bytes.lengthInBytes > maxUploadSize) {
        throw Exception('Dosya işlenemeyecek kadar büyük. Lütfen daha düşük çözünürlüklü bir görsel kullanın.');
      }

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
      // Ders dışı içerik hatası ise direkt göster (başında "Bir hata oluştu" yazmasın)
      if (e.toString().contains('ders içeriği barındırmıyor')) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }
      throw Exception('Bir hata oluştu: $e');
    }
  }

  /// Birden fazla görselden içerik üretir (kamera ile çoklu sayfa)
  Future<GeneratedContent> generateContentFromMultipleImages({
    required List<File> files,
    required ContentType contentType,
    String? examType,
  }) async {
    if (files.isEmpty) {
      throw Exception('En az bir görsel seçmelisiniz.');
    }

    try {
      // Tüm görselleri işle ve base64'e çevir
      final List<Map<String, String>> images = [];
      int totalSize = 0;

      for (final file in files) {
        final mimeType = getMimeType(file.path);
        final Uint8List bytes = await _processFile(file, mimeType);

        totalSize += bytes.lengthInBytes;
        if (totalSize > maxUploadSize) {
          throw Exception('Toplam görsel boyutu çok fazla. Lütfen daha az veya daha küçük görseller seçin.');
        }

        final b64 = base64Encode(bytes);
        images.add({
          'base64': b64,
          'mimeType': mimeType,
        });
      }

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('ai-generateGemini');

      final prompt = _buildMultiPagePrompt(contentType, examType, files.length);

      final result = await callable
          .call({
            'prompt': prompt,
            'expectJson': true,
            'requestType': 'content_generator',
            'images': images, // Birden fazla görsel
            'maxOutputTokens': 15000, // Daha fazla içerik için artırıldı
            'temperature': 0.4,
          })
          .timeout(const Duration(minutes: 7)); // Daha uzun timeout

      final data = result.data;
      final rawResponse = (data is Map && data['raw'] is String)
          ? (data['raw'] as String).trim()
          : '';

      if (rawResponse.isEmpty) {
        throw Exception('İçerik üretilemedi. Lütfen tekrar deneyin.');
      }

      return _parseResponse(rawResponse, contentType);
    } on FirebaseFunctionsException catch (e) {
      final msg = e.message ?? 'AI hizmeti hatası. Lütfen tekrar deneyin.';
      throw Exception(msg);
    } catch (e) {
      // Ders dışı içerik hatası ise direkt göster
      if (e.toString().contains('ders içeriği barındırmıyor')) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }
      throw Exception('Bir hata oluştu: $e');
    }
  }

  /// Çoklu sayfa için prompt oluştur
  String _buildMultiPagePrompt(ContentType contentType, String? examType, int pageCount) {
    final basePrompt = _buildPrompt(contentType, examType);
    final multiPageContext = '''
ÖNEMLİ - ÇOKLU SAYFA ANALİZİ:
• Toplam $pageCount sayfa/görsel gönderildi
• Tüm sayfaları BÜTÜNLEŞIK olarak analiz et
• Sayfalar arası bilgi akışını takip et
• Tekrarlayan bilgileri TEK SEFER yaz
• Tüm sayfalardaki ÖNEMLİ bilgileri kapsa
• Çıktı tutarlı ve bütünlük içinde olsun

$basePrompt
''';

    return multiPageContext;
  }

  /// Dosyayı işle - görsel ise sıkıştır
  Future<Uint8List> _processFile(File file, String mimeType) async {
    // Önce dosya boyutunu disk üzerinden kontrol et (OOM önlemek için)
    final int initialSize = await file.length();

    if (initialSize > maxUploadSize) {
      throw Exception('Dosya boyutu limitlerin üzerinde (Maksimum 10MB).');
    }

    if (mimeType == 'application/pdf' && initialSize > _safePayloadSize) {
      // 7MB - 10MB arası PDF'ler için uyarı
      print('Uyarı: Büyük PDF dosyası gönderiliyor (${(initialSize / 1024 / 1024).toStringAsFixed(1)} MB)');
    }

    // Görsel dosyaları sıkıştır
    if (mimeType.startsWith('image/')) {
      try {
        int quality = 85;
        int minDimension = 1280;

        // Boyut kademelendirmesi
        if (initialSize > 5 * 1024 * 1024) { // 5MB+ ise
          quality = 75;
          minDimension = 1024;
        }

        final result = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: minDimension,
          minHeight: minDimension,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        if (result != null && result.isNotEmpty) {
          return result;
        }
      } catch (e) {
        print('Sıkıştırma hatası: $e');
      }
    }

    // Sıkıştırma başarısız olduysa veya PDF ise orijinalden devam et
    if (initialSize > maxUploadSize) {
      throw Exception('Dosya boyutu çok büyük (Maksimum 50MB).');
    }

    return await file.readAsBytes();
  }

  /// İçerik türüne göre prompt oluştur
  String _buildPrompt(ContentType contentType, String? examType) {
    switch (contentType) {
      case ContentType.flashcard:
        return ContentGeneratorPrompts.getInfoCardsPrompt(examType);
      case ContentType.quiz:
        return ContentGeneratorPrompts.getQuestionCardsPrompt(examType);
      case ContentType.summary:
        return ContentGeneratorPrompts.getSummaryPrompt(examType);
      case ContentType.mnemonic:
        return ContentGeneratorPrompts.getMnemonicPrompt(examType);
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

      // Hata kontrolü (AI tarafından döndürülen)
      if (json.containsKey('error')) {
        throw Exception(json['error']);
      }

      if (contentType == ContentType.summary) {
        return GeneratedContent(
          type: contentType,
          rawContent: rawResponse,
          summary: json['summary'] ?? json['ozet'] ?? '',
          topic: json['topic'] ?? json['konu'],
        );
      } else if (contentType == ContentType.mnemonic) {
        return GeneratedContent(
          type: contentType,
          rawContent: rawResponse,
          summary: json['content'] ?? json['icerik'] ?? json['mnemonic'] ?? rawResponse,
          topic: json['topic'] ?? json['konu'],
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
          topic: json['topic'] ?? json['konu'],
        );
      }
    } catch (e) {
      // Bilinen hataları (ders dışı içerik vb.) yukarı fırlat
      if (e.toString().contains('ders içeriği barındırmıyor')) {
        rethrow;
      }

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
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
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
