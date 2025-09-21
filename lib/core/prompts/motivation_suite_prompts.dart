// lib/core/prompts/motivation_suite_prompts.dart
import 'package:taktik/core/prompts/trial_review_prompt.dart';
import 'package:taktik/core/prompts/strategy_consult_prompt.dart';
import 'package:taktik/core/prompts/psych_support_prompt.dart';
import 'package:taktik/core/prompts/motivation_corner_prompt.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/data/models/performance_summary.dart';

class MotivationSuitePrompts {
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
