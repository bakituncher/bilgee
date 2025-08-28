// lib/features/weakness_workshop/screens/saved_workshops_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:bilge_ai/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

final savedWorkshopsProvider = StreamProvider.autoDispose<List<SavedWorkshopModel>>((ref) {
  final userId = ref.watch(authControllerProvider).value?.uid;
  if (userId == null) {
    return Stream.value([]);
  }
  return ref.watch(firestoreServiceProvider).getSavedWorkshops(userId);
});

class SavedWorkshopsScreen extends ConsumerWidget {
  const SavedWorkshopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedWorkshopsAsync = ref.watch(savedWorkshopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cevher Kasan"),
      ),
      body: savedWorkshopsAsync.when(
        data: (workshops) {
          if (workshops.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 80, color: AppTheme.secondaryTextColor),
                  const SizedBox(height: 16),
                  Text('Kasan Henüz Boş', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Atölyede işlediğin değerli cevherleri buraya kaydederek onlara istediğin zaman geri dönebilirsin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: workshops.length,
            itemBuilder: (context, index) {
              final workshop = workshops[index];
              return _SavedWorkshopCard(workshop: workshop)
                  .animate()
                  .fadeIn(delay: (100 * index).ms)
                  .slideY(begin: 0.2);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Hata: $e")),
      ),
    );
  }
}

class _SavedWorkshopCard extends StatelessWidget {
  final SavedWorkshopModel workshop;
  const _SavedWorkshopCard({required this.workshop});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(
            '${AppRoutes.aiHub}/${AppRoutes.weaknessWorkshop}/${AppRoutes.savedWorkshopDetail}',
            extra: workshop,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.secondaryColor,
                child: Icon(Icons.diamond_rounded, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshop.topic,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${workshop.subject} | ${DateFormat.yMMMMd('tr').format(workshop.savedDate.toDate())}",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }
}