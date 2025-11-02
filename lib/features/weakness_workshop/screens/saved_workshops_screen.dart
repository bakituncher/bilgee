// lib/features/weakness_workshop/screens/saved_workshops_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

final savedWorkshopsProvider = StreamProvider.autoDispose<List<SavedWorkshopModel>>((ref) {
  final userId = ref.watch(authControllerProvider).value?.uid;
  if (userId == null) {
    return Stream.value([]);
  }
  return ref.watch(firestoreServiceProvider).getSavedWorkshops(userId);
});

final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class SavedWorkshopsScreen extends ConsumerStatefulWidget {
  const SavedWorkshopsScreen({super.key});

  @override
  ConsumerState<SavedWorkshopsScreen> createState() => _SavedWorkshopsScreenState();
}

class _SavedWorkshopsScreenState extends ConsumerState<SavedWorkshopsScreen> {
  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu kaydı kalıcı olarak silmek istiyor musun?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final savedWorkshopsAsync = ref.watch(savedWorkshopsProvider);
    final query = ref.watch(_searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cevher Kasası"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Konu veya ders ara...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v.trim(),
            ),
          ),
          Expanded(
            child: savedWorkshopsAsync.when(
              data: (workshops) {
                final filtered = workshops.where((w) {
                  if (query.isEmpty) return true;
                  final q = query.toLowerCase();
                  return w.topic.toLowerCase().contains(q) || w.subject.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(query.isEmpty ? 'Kasan Henüz Boş' : 'Sonuç bulunamadı', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            query.isEmpty
                                ? 'Atölyede işlediğin değerli cevherleri buraya kaydederek onlara istediğin zaman geri dönebilirsin.'
                                : 'Farklı bir anahtar kelime dene.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final workshop = filtered[index];
                    final userId = ref.read(authControllerProvider).value?.uid;
                    return Dismissible(
                      key: Key(workshop.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                        child: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context),
                      onDismissed: (_) async {
                        if (userId != null) {
                          await ref.read(firestoreServiceProvider).deleteSavedWorkshop(userId, workshop.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıt silindi')));
                          }
                        }
                      },
                      child: _SavedWorkshopCard(workshop: workshop)
                          .animate()
                          .fadeIn(delay: (100 * index).ms)
                          .slideY(begin: 0.2),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("Hata: $e")),
            ),
          ),
        ],
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
      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
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
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Icon(Icons.diamond_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
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