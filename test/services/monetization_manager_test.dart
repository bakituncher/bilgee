import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktik/core/services/monetization_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonetizationManager 1 ad / 1 paywall', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('alternates: #1 ad, #2 paywall, #3 ad, #4 paywall (cooldown disabled)', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = MonetizationManager(prefs, disableCooldownForTesting: true);

      expect(manager.getActionAfterTestSubmission(), MonetizationAction.showAd);
      expect(manager.getActionAfterTestSubmission(), MonetizationAction.showPaywall);
      expect(manager.getActionAfterTestSubmission(), MonetizationAction.showAd);
      expect(manager.getActionAfterTestSubmission(), MonetizationAction.showPaywall);
    });

    test('cooldown: if last ad is now, next odd submission returns showNothing', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = MonetizationManager(prefs);

      // First submission -> ad (also records last ad time)
      expect(manager.getActionAfterTestSubmission(), MonetizationAction.showAd);

      // Force next submission to be odd again, and make sure cooldown is definitely active.
      await prefs.setInt('monetization_test_count', 0);
      await prefs.setInt('monetization_last_ad_time', DateTime.now().millisecondsSinceEpoch);

      expect(manager.getActionAfterTestSubmission(), MonetizationAction.showNothing);
    });

    test('separate counters: test and lessonNet do not affect each other (cooldown disabled)', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = MonetizationManager(prefs, disableCooldownForTesting: true);

      // Test #1 -> ad
      expect(manager.getActionAfterTestSubmission(), MonetizationAction.showAd);

      // Lesson net #1 should still be ad (separate counter)
      expect(manager.getActionAfterLessonNetSubmission(), MonetizationAction.showAd);
    });
  });
}
