// lib/features/weakness_workshop/screens/saved_workshops_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

final savedWorkshopsProvider = StreamProvider.autoDispose<List<WorkshopModel>>((ref) {
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
  @override
  Widget build(BuildContext context) {
    final savedWorkshopsAsync = ref.watch(savedWorkshopsProvider);
    final query = ref.watch(_searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Etüt Geçmişi"),
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
                                ? 'Atölyede çalıştığın konuları buraya kaydederek onlara istediğin zaman geri dönebilirsin.'
                                : 'Farklı bir anahtar kelime dene.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Konu başlığına göre grupla (subject + topic kombinasyonu)
                final Map<String, List<WorkshopModel>> groupedWorkshops = {};
                for (var workshop in filtered) {
                  final key = '${workshop.subject}|||${workshop.topic}';
                  if (!groupedWorkshops.containsKey(key)) {
                    groupedWorkshops[key] = [];
                  }
                  groupedWorkshops[key]!.add(workshop);
                }

                // Her grup için en son kayıt tarihine göre sırala
                final sortedGroups = groupedWorkshops.entries.toList()
                  ..sort((a, b) {
                    final aLatest = a.value.map((w) => w.savedDate?.toDate() ?? DateTime(2000)).reduce((a, b) => a.isAfter(b) ? a : b);
                    final bLatest = b.value.map((w) => w.savedDate?.toDate() ?? DateTime(2000)).reduce((a, b) => a.isAfter(b) ? a : b);
                    return bLatest.compareTo(aLatest);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: sortedGroups.length,
                  itemBuilder: (context, index) {
                    final group = sortedGroups[index].value;
                    // Grup içindeki workshop'ları tarihe göre sırala (en yeni önce)
                    group.sort((a, b) {
                      final aDate = a.savedDate?.toDate() ?? DateTime(2000);
                      final bDate = b.savedDate?.toDate() ?? DateTime(2000);
                      return bDate.compareTo(aDate);
                    });

                    return _SavedWorkshopGroupCard(workshops: group)
                        .animate()
                        .fadeIn(delay: (100 * index).ms)
                        .slideY(begin: 0.2);
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

class _SavedWorkshopGroupCard extends ConsumerStatefulWidget {
  final List<WorkshopModel> workshops;
  const _SavedWorkshopGroupCard({required this.workshops});

  @override
  ConsumerState<_SavedWorkshopGroupCard> createState() => _SavedWorkshopGroupCardState();
}

class _SavedWorkshopGroupCardState extends ConsumerState<_SavedWorkshopGroupCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final workshop = widget.workshops.first; // Grup başlığı için ilk workshop'u kullan
    final count = widget.workshops.length;
    final latestDate = widget.workshops.first.savedDate; // Zaten sıralı, ilki en yeni

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (count == 1) {
                // Tek kayıt varsa direkt aç
                context.push(
                  '${AppRoutes.aiHub}/${AppRoutes.weaknessWorkshop}/${AppRoutes.savedWorkshopDetail}',
                  extra: widget.workshops.first,
                );
              } else {
                // Birden fazla kayıt varsa genişlet/daralt
                setState(() => _isExpanded = !_isExpanded);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.secondaryContainer,
                        ],
                      ),
                    ),
                    child: count > 1
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.diamond_rounded,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                size: 28,
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Icon(
                            Icons.diamond_rounded,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
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
                          "${workshop.subject} | ${latestDate != null ? DateFormat.yMMMMd('tr').format(latestDate.toDate()) : 'Tarih yok'}",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    count > 1
                        ? (_isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded)
                        : Icons.arrow_forward_ios_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded && count > 1)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: widget.workshops.map((w) {
                  if (w.id == null) return const SizedBox.shrink();
                  return InkWell(
                    onTap: () {
                      context.push(
                        '${AppRoutes.aiHub}/${AppRoutes.weaknessWorkshop}/${AppRoutes.savedWorkshopDetail}',
                        extra: w,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.history_edu_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              w.savedDate != null
                                  ? DateFormat('d MMMM yyyy, HH:mm', 'tr').format(w.savedDate!.toDate())
                                  : 'Tarih yok',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}