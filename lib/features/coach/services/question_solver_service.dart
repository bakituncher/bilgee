import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider definition
final questionSolverServiceProvider = Provider<QuestionSolverService>((ref) {
  return QuestionSolverService();
});

class QuestionSolverService {
  QuestionSolverService();

  Future<String> solveQuestion(XFile imageFile, {String? examType}) async {
    try {
      // 1) Compress image (bandwidth + callable payload)
      final Uint8List bytes = await _compressImage(File(imageFile.path));

      // 2) Base64 encode (callable payload)
      final b64 = base64Encode(bytes);

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('ai-generateGemini');

      final prompt = _buildPrompt(examType);

      final result = await callable
          .call({
            'prompt': prompt,
            'expectJson': false,
            'requestType': 'question_solver',
            'imageBase64': b64,
            'imageMimeType': 'image/jpeg',
            // Keep the output reasonably sized; solution is markdown.
            'maxOutputTokens': 8192,
            // Daha doğal ve insansı bir ton için sıcaklığı biraz artırdık (0.4 -> 0.5)
            'temperature': 0.5,
          })
          .timeout(const Duration(minutes: 5));

      final data = result.data;
      final rawResponse = (data is Map && data['raw'] is String) ? (data['raw'] as String).trim() : '';

      if (rawResponse.isEmpty) {
        throw Exception('Çözüm üretilemedi. Lütfen tekrar deneyin.');
      }

      return rawResponse;
    } on FirebaseFunctionsException catch (e) {
      // Forward backend-friendly messages.
      final msg = e.message ?? 'AI hizmeti hatası. Lütfen tekrar deneyin.';
      throw Exception(msg);
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  Future<Uint8List> _compressImage(File file) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      if (result != null && result.isNotEmpty) return result;
    } catch (_) {
      // fall through
    }
    return await file.readAsBytes();
  }

  String _buildPrompt(String? examType) {
    String examContext = '';
    if (examType != null && examType.isNotEmpty) {
      examContext = '\n\n**ÖNEMLİ:** Kullanıcı **$examType** sınavına hazırlanıyor. Çözümü ve açıklamaları bu sınavın seviyesine, formatına ve müfredatına uygun şekilde hazırla.';
    }

    return '''
Sen öğrencinin en yakın "zekî çalışma arkadaşısın". Karşındaki kişiyle yan yana ders çalışıyormuş gibi konuş.$examContext

GÖREVİN:
Kullanıcının gönderdiği soruyu analiz et ve çözümünü "biz bize", samimi, akıcı ve net bir dille anlat.

KURALLAR VE TON:
1. **Samimi Ol:** "Merhaba sevgili öğrencim" gibi resmi girişler YAPMA. Doğrudan "Bak şimdi kanka," veya "Gel bu soruyu halledelim," gibi doğal, konuşma diliyle başla.
2. **Robotlaşma:** "İlk olarak verileri analiz edelim" gibi basmakalıp laflar etme. "Şunu şuraya atıyoruz, bunu bununla çarpıyoruz" gibi aktif ve canlı anlat.
3. **Net ve Pratik Ol:** İşlemleri adım adım göster ama gereksiz uzatma. Sektördeki en pratik, en "kestirme" yol neyse onu göster. Laf kalabalığı yapma.
4. **Görsel Düzen:**
   - Matematiksel ifadeleri mutlaka LaTeX formatında yaz (Örn: \$x^2 + 5x = 0\$).
   - Önemli yerleri **kalın** yazarak vurgula.
   - Çıktın Markdown formatında olsun.
5. **Final Dokunuşu:** Çözümü bitirdikten sonra en alta "💡 Aklında Olsun:" başlığıyla, bu tarz sorularda hayat kurtaran tek cümlelik bir taktik veya püf noktası bırak.

Eğer görsel okunmuyorsa veya soru yoksa; teknik hata mesajı verme. "Kanka bu fotoyu okuyamadım ya, biraz daha net çekip atar mısın?" şeklinde samimi bir uyarı ver.
''';
  }

  // YENİ: Takip eden sorular için sohbet fonksiyonu
  Future<String> solveFollowUp({
    required String originalPrompt,
    required String previousSolution,
    required String userQuestion,
    String? examType,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('ai-generateGemini');

      // AI'a rolünü ve geçmişi hatırlatan prompt
      String examContext = '';
      if (examType != null && examType.isNotEmpty) {
        examContext = '\n\n**SINAV:** Öğrenci **$examType** sınavına hazırlanıyor.';
      }

      final contextPrompt = '''
GÖREVİN:
Sen bir öğrencinin yanındaki "zekî çalışma arkadaşısın". Daha önce bir soru çözdün.$examContext

Önceki Çözümün:
$previousSolution

Öğrenci şimdi bu çözümle ilgili şunu soruyor:
"$userQuestion"

Bu soruya samimi, açıklayıcı ve motive edici bir dille, önceki çözümünü referans alarak cevap ver.
Yine LaTeX formatını (\$\$) kullan ve Markdown ile biçimlendir. Kısa ve öz ol, gereksiz tekrar yapma.
Konuşma dilin doğal, "biz bize" tarzında olsun.
''';

      final result = await callable.call({
        'prompt': contextPrompt,
        'expectJson': false,
        'requestType': 'chat',
        'temperature': 0.5,
        'maxOutputTokens': 8192,
      });

      final data = result.data;
      final rawResponse = (data is Map && data['raw'] is String) ? (data['raw'] as String).trim() : '';

      if (rawResponse.isEmpty) {
        throw Exception('Cevap alınamadı.');
      }

      return rawResponse;
    } on FirebaseFunctionsException catch (e) {
      final msg = e.message ?? 'AI hizmeti hatası. Lütfen tekrar deneyin.';
      throw Exception(msg);
    } catch (e) {
      throw Exception('Sohbet hatası: $e');
    }
  }
}
