// lib/core/services/firebase_analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics servisi
/// AD_ID izni olmadan çalışacak şekilde yapılandırılmıştır
class FirebaseAnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  /// Ekran görüntüleme olayı
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] Screen view error: $e');
      }
    }
  }

  /// Özel olay kaydı
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] Event log error: $e');
      }
    }
  }

  /// Kullanıcı özelliği ayarla
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(
        name: name,
        value: value,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] User property error: $e');
      }
    }
  }

  /// Kullanıcı ID'si ayarla
  static Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] User ID error: $e');
      }
    }
  }

  /// Giriş olayı
  static Future<void> logLogin({String? method}) async {
    await logEvent(
      name: 'login',
      parameters: method != null ? {'method': method} : null,
    );
  }

  /// Kayıt olayı
  static Future<void> logSignUp({String? method}) async {
    await logEvent(
      name: 'sign_up',
      parameters: method != null ? {'method': method} : null,
    );
  }

  /// Soru çözme olayı
  static Future<void> logSolveQuestion({
    required String examType,
    required String subject,
    bool? isCorrect,
  }) async {
    await logEvent(
      name: 'solve_question',
      parameters: {
        'exam_type': examType,
        'subject': subject,
        if (isCorrect != null) 'is_correct': isCorrect,
      },
    );
  }

  /// Deneme sınavı tamamlama olayı
  static Future<void> logCompleteExam({
    required String examType,
    required int questionCount,
    required int correctCount,
  }) async {
    await logEvent(
      name: 'complete_exam',
      parameters: {
        'exam_type': examType,
        'question_count': questionCount,
        'correct_count': correctCount,
        'success_rate': (correctCount / questionCount * 100).toStringAsFixed(1),
      },
    );
  }

  /// Premium satın alma olayı
  static Future<void> logPurchase({
    required String productId,
    required double value,
    required String currency,
  }) async {
    await logEvent(
      name: 'purchase',
      parameters: {
        'product_id': productId,
        'value': value,
        'currency': currency,
      },
    );
  }

  /// Yapay zeka asistan kullanımı
  static Future<void> logAiAssistantUsage({
    required String assistantType,
    required String action,
  }) async {
    await logEvent(
      name: 'ai_assistant_usage',
      parameters: {
        'assistant_type': assistantType,
        'action': action,
      },
    );
  }
}

