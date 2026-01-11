import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider definition
final questionSolverServiceProvider = Provider<QuestionSolverService>((ref) {
  return QuestionSolverService();
});

class QuestionSolverService {
  // Model name requested by user: Gemini-2.5-Flash (Mapping to latest stable Flash)
  // Currently using gemini-1.5-flash as the stable release.
  // If 2.0-flash-exp is available and stable, it can be swapped here.
  static const String _modelName = 'gemini-1.5-flash';

  QuestionSolverService();

  Future<String> solveQuestion(XFile imageFile) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API Anahtarı bulunamadı. Lütfen ayarları kontrol edin.');
      }

      // 1. Compress Image (Client-side optimization)
      final Uint8List? compressedBytes = await _compressImage(File(imageFile.path));
      if (compressedBytes == null) {
        throw Exception('Görsel işlenirken bir hata oluştu.');
      }

      // 2. Initialize Model with System Instruction
      final model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4, // Deterministic but creative enough for teaching
        ),
        systemInstruction: Content.system(_systemPrompt),
      );

      // 3. Prepare Prompt (Image Only, system prompt is now separate)
      final prompt = Content.multi([
        DataPart('image/jpeg', compressedBytes),
      ]);

      // 4. Call API (Direct Device -> API)
      final response = await model.generateContent([prompt]);
      final text = response.text;

      if (text == null || text.isEmpty) {
        throw Exception('Çözüm üretilemedi. Lütfen tekrar deneyin.');
      }

      return text;
    } catch (e) {
      // Re-throw to be handled by UI
      throw Exception('Bir hata oluştu: $e');
    }
  }

  Future<Uint8List?> _compressImage(File file) async {
    try {
      // Compress to ensure it's under API limits and faster to upload
      // Resize to max 1024x1024 to save bandwidth while keeping legibility for text
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80, // High quality for text readability
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      // Fallback: read original bytes if compression fails
      return await file.readAsBytes();
    }
  }

  static const String _systemPrompt = '''
Sen uzman bir eğitim koçu ve öğretmenisin. Önüne gelen soru görselini analiz edip öğrencine en iyi şekilde anlatmalısın.

GÖREVLERİN:
1. Soruyu Analiz Et: Hangi konuyla ilgili? Ne soruluyor?
2. Adım Adım Çöz: İşlemleri atlamadan, anlaşılır bir dille anlat.
3. Sonucu Belirt: Doğru cevabı açıkça yaz.
4. Püf Noktası Ver: Bu tarz sorularda kullanılabilecek pratik bir taktik veya ipucu ekle.

FORMAT KURALLARI:
- Çıktı tamamen Markdown formatında olmalıdır.
- Matematiksel ifadeler ve formüller için LaTeX formatı kullan. (Örnek: \$x^2 + y^2 = z^2\$)
- Başlıkları belirginleştir (**Kalın** veya # Başlık).
- Üslubun motive edici, sabırlı ve öğretici olsun ("Harikasın, şimdi şu adıma bakalım..." gibi).

NOT:
- Eğer görselde bir soru yoksa veya okunmuyorsa, kibarca görselin net olmadığını belirt.
- Sadece soruyu çözme, mantığını da öğret.
''';
}
