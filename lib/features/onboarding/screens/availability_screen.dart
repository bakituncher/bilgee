// lib/features/onboarding/screens/availability_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';

// --- STATE MANAGEMENT ---
final availabilityProvider = StateProvider.autoDispose<Map<String, List<String>>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  return Map<String, List<String>>.from(user?.weeklyAvailability.map((key, value) => MapEntry(key, List<String>.from(value))) ?? {});
});

final clipboardProvider = StateProvider.autoDispose<List<String>?>((ref) => null);

// --- ANA EKRAN WIDGET'I ---
class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  static const List<String> days = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];
  // *** KESİN ÇÖZÜM: 24 SAATLİK, AI DOSTU ZAMAN DİLİMLERİ ***
  static const Map<String, List<String>> timeSlotGroups = {
    "Gündoğumu (05-09)": ["05:00-07:00", "07:00-09:00"],
    "Sabah (09-13)": ["09:00-11:00", "11:00-13:00"],
    "Öğleden Sonra (13-18)": ["13:00-15:00", "15:00-18:00"],
    "Akşam (18-23)": ["18:00-20:00", "20:00-23:00"],
    "Gece Vardiyası (23-05)": ["23:00-01:00", "01:00-03:00", "03:00-05:00"],
  };
  static List<String> get allTimeSlots => timeSlotGroups.values.expand((slots) => slots).toList();

  void _onSave(BuildContext context, WidgetRef ref) async {
    final availability = ref.read(availabilityProvider);
    final userId = ref.read(userProfileProvider).value!.id;

    if (availability.values.every((list) => list.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zafer planı için en az bir zaman dilimi belirlemelisin.'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
      return;
    }

    await ref.read(firestoreServiceProvider).updateWeeklyAvailability(
      userId: userId,
      availability: availability,
    );

    if (context.mounted) {
      ref.read(clipboardProvider.notifier).state = null;
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final clipboard = ref.watch(clipboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Zaman Haritası"),
        automaticallyImplyLeading: context.canPop(),
        actions: [
          if (clipboard != null)
            TextButton.icon(
              onPressed: () {
                final availabilityNotifier = ref.read(availabilityProvider.notifier);
                final currentAvailability = Map<String, List<String>>.from(availabilityNotifier.state);
                for (var day in days) {
                  currentAvailability[day] = List.from(clipboard);
                }
                availabilityNotifier.state = currentAvailability;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Kopyalanan plan tüm haftaya uygulandı!"),
                  backgroundColor: AppTheme.successColor,
                ));
              },
              icon: const Icon(Icons.content_paste_go_rounded),
              label: const Text("Tümüne Yapıştır"),
            ).animate().fadeIn(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextButton(
              onPressed: () => _onSave(context, ref),
              child: const Text("Kaydet ve Bitir"),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Harekât Zamanlarını Belirle",
              style: textTheme.headlineSmall,
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              "Stratejik planın, sadece bu haritada işaretlediğin zamanlara göre oluşturulacak. Unutma, her saniye önemlidir.",
              style: textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 24),
            ...days.map((day) {
              return _DayAvailabilityCard(
                key: ValueKey(day),
                day: day,
                timeSlotGroups: timeSlotGroups,
              ).animate().fadeIn(delay: (100 * days.indexOf(day)).ms).slideX(begin: -0.2);
            }).toList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _DayAvailabilityCard extends StatelessWidget {
  const _DayAvailabilityCard({
    super.key,
    required this.day,
    required this.timeSlotGroups,
  });

  final String day;
  final Map<String, List<String>> timeSlotGroups;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayHeader(day: day, allSlots: AvailabilityScreen.allTimeSlots),
            const SizedBox(height: 12),
            ...timeSlotGroups.entries.map((entry) {
              return _TimeSlotGroup(
                title: entry.key,
                slots: entry.value,
                day: day,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends ConsumerWidget {
  final String day;
  final List<String> allSlots;

  const _DayHeader({required this.day, required this.allSlots});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipboard = ref.watch(clipboardProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(day, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Row(
          children: [
            TextButton(
              onPressed: () {
                final availabilityNotifier = ref.read(availabilityProvider.notifier);
                final currentAvailability = Map<String, List<String>>.from(availabilityNotifier.state);
                final areAllSelected = (currentAvailability[day]?.length ?? 0) == allSlots.length;
                currentAvailability[day] = areAllSelected ? [] : List.from(allSlots);
                availabilityNotifier.state = currentAvailability;
              },
              child: const Text("Doldur/Boşalt"),
            ),
            IconButton(
              icon: const Icon(Icons.copy_all_rounded),
              tooltip: "Bu günün planını kopyala",
              onPressed: () {
                ref.read(clipboardProvider.notifier).state = ref.read(availabilityProvider)[day];
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("$day programı panoya kopyalandı!")));
              },
            ),
            if (clipboard != null)
              IconButton(
                icon: const Icon(Icons.content_paste_rounded, color: AppTheme.successColor),
                tooltip: "Kopyalanan planı bu güne yapıştır",
                onPressed: () {
                  final availabilityNotifier = ref.read(availabilityProvider.notifier);
                  final newAvailability = Map<String, List<String>>.from(availabilityNotifier.state);
                  newAvailability[day] = List.from(clipboard);
                  availabilityNotifier.state = newAvailability;
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _TimeSlotGroup extends ConsumerWidget {
  final String title;
  final List<String> slots;
  final String day;

  const _TimeSlotGroup({
    required this.title,
    required this.slots,
    required this.day,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSlots = ref.watch(availabilityProvider.select((av) => av[day] ?? []));

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, right: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.secondaryTextColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: slots.map((slot) {
              final isSelected = selectedSlots.contains(slot);
              return InkWell(
                onTap: () {
                  final availabilityNotifier = ref.read(availabilityProvider.notifier);
                  final currentMap = availabilityNotifier.state;
                  final daySlots = List<String>.from(currentMap[day] ?? []);

                  if (isSelected) {
                    daySlots.remove(slot);
                  } else {
                    daySlots.add(slot);
                  }

                  final newMap = Map<String, List<String>>.from(currentMap);
                  newMap[day] = daySlots;
                  availabilityNotifier.state = newMap;
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.successColor.withOpacity(0.3) : AppTheme.lightSurfaceColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.successColor : AppTheme.lightSurfaceColor,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.successColor : AppTheme.textColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}