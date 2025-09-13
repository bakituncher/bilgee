// lib/features/admin/screens/question_reports_screen.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _reportSearchProvider = StateProvider.autoDispose<String>((_) => '');

class QuestionReportsScreen extends ConsumerWidget {
  const QuestionReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(adminClaimProvider);

    Future<void> _callAdminFn({required String mode, required String qhash}) async {
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('reports-adminDeleteQuestionReports');
        final res = await callable.call({'mode': mode, 'qhash': qhash});
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarılı: ${res.data}')));
      } on FirebaseFunctionsException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.message ?? e.code}')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }

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

                        return Dismissible(
                          key: ValueKey('idx_$qhash'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.orange,
                            child: const Icon(Icons.layers_clear_rounded, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('İndeks kaydı kaldırılsın mı?'),
                                content: const Text('Raporlar kalır; sadece listeden kaldırılır.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaldır')),
                                ],
                              ),
                            );
                            return ok ?? false;
                          },
                          onDismissed: (_) async {
                            await _callAdminFn(mode: 'indexOnly', qhash: qhash);
                          },
                          child: Card(
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
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'open') {
                                    // navigate
                                    // ignore: use_build_context_synchronously
                                    context.push('/admin/reports/$qhash');
                                  } else if (v == 'indexOnly') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Sadece indeks kaydı kaldırılsın mı?'),
                                        content: const Text('Raporlar kalır; sadece listeden kaldırılır.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaldır')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) await _callAdminFn(mode: 'indexOnly', qhash: qhash);
                                  } else if (v == 'byQhash') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Tüm raporları sil?'),
                                        content: const Text('Bu soruya ait tüm raporlar kalıcı olarak silinecek.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) await _callAdminFn(mode: 'byQhash', qhash: qhash);
                                  }
                                },
                                itemBuilder: (c) => const [
                                  PopupMenuItem(value: 'open', child: Text('Detayı aç')),
                                  PopupMenuItem(value: 'indexOnly', child: Text('Sadece indeks kaydını kaldır')),
                                  PopupMenuItem(value: 'byQhash', child: Text('Tüm raporları sil')),
                                ],
                              ),
                            ),
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
