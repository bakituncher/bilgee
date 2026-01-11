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

  Future<String> solveQuestion(XFile imageFile) async {
    try {
      // 1) Compress image (bandwidth + callable payload)
      final Uint8List bytes = await _compressImage(File(imageFile.path));

      // 2) Base64 encode (callable payload)
      final b64 = base64Encode(bytes);

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('ai-generateGemini');

      final prompt = _textOnlyPrompt;

      final result = await callable
          .call({
            'prompt': prompt,
            'expectJson': false,
            'requestType': 'question_solver',
            'imageBase64': b64,
            'imageMimeType': 'image/jpeg',
            // Keep the output reasonably sized; solution is markdown.
            'maxOutputTokens': 2048,
            // Deterministic but explanatory.
            'temperature': 0.4,
          })
          .timeout(const Duration(seconds: 70));

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

  static const String _textOnlyPrompt = '''
Sen uzman bir eğitim koçu ve öğretmensin. Kullanıcı sana bir soru görseli gönderiyor.

KURAL: Çıktıyı tamamen Markdown olarak yaz. Matematiksel ifadeler için LaTeX (\$...\$) kullan.

GÖREV:
1) Soruyu analiz et (konu + istenen).
2) Adım adım çöz (işlemleri atlama).
3) Cevabı net biçimde yaz.
4) En sonda 1-2 adet püf noktası ver.

Eğer görsel okunmuyorsa veya soru yoksa bunu kibarca belirt ve kullanıcıdan daha net fotoğraf iste.
''';
}
