// lib/features/profile/widgets/profile_action_cards.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

class TimeManagementActions extends StatelessWidget {
  const TimeManagementActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.availability),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: Theme.of(context).colorScheme.secondary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Zaman Haritanı Düzenle", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Haftalık müsaitlik durumunu güncelle.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class StrategicActions extends ConsumerWidget {
  final UserModel user;
  const StrategicActions({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planDoc = ref.watch(planProvider).value;

    return Card(
      color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1)
      ),
      child: InkWell(
        onTap: () {
          if (user.weeklyAvailability.isEmpty || user.weeklyAvailability.values.every((list) => list.isEmpty)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Lütfen önce "Zaman Haritanı Düzenle" bölümünden müsaitlik durumunuzu belirtin.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: 'DÜZENLE',
                  textColor: Theme.of(context).colorScheme.onError,
                  onPressed: () => context.push(AppRoutes.availability),
                ),
              ),
            );
          } else {
            if (planDoc?.weeklyPlan != null) {
              context.push('/home/weekly-plan');
            } else {
              context.push('${AppRoutes.aiHub}/${AppRoutes.strategicPlanning}');
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.map_rounded, color: Theme.of(context).colorScheme.secondary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Zafer Planı", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text("Kişisel zafer planını oluştur veya görüntüle.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  )
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}