// lib/core/prompts/motivation_suite_prompts.dart
import 'package:bilge_ai/core/prompts/trial_review_prompt.dart';
import 'package:bilge_ai/core/prompts/strategy_consult_prompt.dart';
import 'package:bilge_ai/core/prompts/psych_support_prompt.dart';
import 'package:bilge_ai/core/prompts/motivation_corner_prompt.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';

class MotivationSuitePrompts {
  static String _toneByExam(String? examName) {
    final name = (examName ?? '').toLowerCase();
    if (name.contains('lgs')) {
      return 'Ton: sıcak, gündelik ve motive edici; 8. sınıf/LGS bağlamı. Açık, kısa, net cümleler.';
    } else if (name.contains('yks')) {
      return 'Ton: sakin, stratejik ve sonuç odaklı; TYT/AYT ritmine uygun, minimal ve net.';
    } else if (name.contains('kpss')) {
      return 'Ton: olgun, profesyonel ve sürdürülebilirlik odaklı; süreklilik ve ölçülebilirlik vurgusu.';
    }
    return 'Ton: destekleyici, net ve sade; sınav bağlamına uyumlu, gereksiz süs yok.';
  }

  static String trialReview({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required PerformanceSummary performance,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    return TrialReviewPrompt.build(
      user: user,
      tests: tests,
      analysis: analysis,
      performance: performance,
      examName: examName,
      conversationHistory: conversationHistory,
      lastUserMessage: lastUserMessage,
    );
  }

  static String strategyConsult({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required PerformanceSummary performance,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    return StrategyConsultPrompt.build(
      user: user,
      tests: tests,
      analysis: analysis,
      performance: performance,
      examName: examName,
      conversationHistory: conversationHistory,
      lastUserMessage: lastUserMessage,
    );
  }

  static String psychSupport({
    required UserModel user,
    required String? examName,
    String? emotion,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    return PsychSupportPrompt.build(
      user: user,
      examName: examName,
      emotion: emotion,
      conversationHistory: conversationHistory,
      lastUserMessage: lastUserMessage,
    );
  }

  static String motivationCorner({
    required UserModel user,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    return MotivationCornerPrompt.build(
      user: user,
      examName: examName,
      conversationHistory: conversationHistory,
      lastUserMessage: lastUserMessage,
    );
  }
}
