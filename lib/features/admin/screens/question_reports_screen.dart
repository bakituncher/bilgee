// lib/features/admin/screens/question_reports_screen.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _reportSearchProvider = StateProvider.autoDispose<String>((_) => '');

class QuestionReportsScreen extends ConsumerWidget {
  const QuestionReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(adminClaimProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cevher Bildirimleri'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: isAdminAsync.when(
        data: (isAdmin) {
          if (!isAdmin) {
            return const _Unauthorized();
          }
          final search = ref.watch(_reportSearchProvider);
          final stream = ref.watch(firestoreServiceProvider).streamQuestionReportIndex();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Soru veya gerekçe ara... (admin)',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => ref.read(_reportSearchProvider.notifier).state = v.trim(),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Hata: ${snapshot.error}'));
                    }
                    final data = snapshot.data ?? const [];
                    final q = search.toLowerCase();
                    final items = q.isEmpty
                        ? data
                        : data.where((m) {
                            final question = (m['question'] ?? '').toString().toLowerCase();
                            final reasons = (m['sampleReasons'] ?? []).toString().toLowerCase();
                            return question.contains(q) || reasons.contains(q);
                          }).toList();

                    if (items.isEmpty) {
                      return const Center(child: Text('Bildirim yok.'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final m = items[index];
                        final qhash = m['id'] as String;
                        final question = (m['question'] ?? '') as String;
                        final reportCount = (m['reportCount'] ?? 0) as int;
                        final reasons = (m['sampleReasons'] ?? []) as List;
                        final subjects = (m['subjects'] ?? []) as List;
                        final topics = (m['topics'] ?? []) as List;
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            onTap: () => context.push('/admin/reports/$qhash'),
                            title: Text(question, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Rapor sayısı: $reportCount'),
                                if (subjects.isNotEmpty && topics.isNotEmpty)
                                  Text('${subjects.toSet().join(', ')} | ${topics.toSet().join(', ')}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
                                if (reasons.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: -8,
                                      children: reasons.take(4).map((e) => Chip(label: Text(e.toString()))).toList(),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (e, _) => Center(child: Text('Hata: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _Unauthorized extends StatelessWidget {
  const _Unauthorized();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('Erişim yetkin yok.'),
      ),
    );
  }
}
