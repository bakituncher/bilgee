import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Provider for the SharedPreferences instance
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// 2. A simple provider to check if the welcome screen has been seen
// This depends on the FutureProvider above.
final hasSeenWelcomeScreenProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).asData?.value;
  return prefs?.getBool('hasSeenWelcomeScreen') ?? false;
});
