// lib/features/admin/screens/question_report_detail_screen.dart
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class QuestionReportDetailScreen extends ConsumerWidget {
  final String qhash;
  const QuestionReportDetailScreen({super.key, required this.qhash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(adminClaimProvider);

    Future<void> callAdminFn(String mode, {String? reportId}) async {
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('reports-adminDeleteQuestionReports');
        final payload = {
          'mode': mode,
          if (mode == 'single' && reportId != null) 'reportId': reportId,
          if (mode != 'single') 'qhash': qhash,
        };
        final res = await callable.call(payload);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silme başarılı: ${res.data}')),
        );
      } on FirebaseFunctionsException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.message ?? e.code}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Detayı'),
        leading: const CustomBackButton(),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete_all') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Tüm raporları sil?'),
                    content: const Text('Bu soruya ait tüm raporlar silinecek. Emin misin?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                    ],
                  ),
                );
                if (ok == true) await callAdminFn('byQhash');
              } else if (v == 'delete_index') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sadece indeks kaydı kaldırılsın mı?'),
                    content: const Text('Rapor dokümanları kalır, liste görünümünden kalkar.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaldır')),
                    ],
                  ),
                );
                if (ok == true) await callAdminFn('indexOnly');
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'delete_all', child: Text('Tüm raporları sil')),
              PopupMenuItem(value: 'delete_index', child: Text('Sadece indeks kaydını kaldır')),
            ],
          ),
        ],
      ),
      body: isAdminAsync.when(
        data: (isAdmin) {
          if (!isAdmin) return const _Unauthorized();
          final stream = ref.watch(firestoreServiceProvider).streamQuestionReportsByHash(qhash);
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LogoLoader();
              }
              if (snapshot.hasError) {
                final msg = snapshot.error.toString();
                final needsIndex = msg.toLowerCase().contains('index') || msg.toLowerCase().contains('failed_precondition');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(needsIndex
                        ? 'Gerekli Firestore indexi eksik. Lütfen indexleri deploy edin.'
                        : 'Hata: $msg'),
                  ),
                );
              }
              final reports = snapshot.data ?? const [];
              if (reports.isEmpty) {
                return const Center(child: Text('Bu soruya ait bildirim bulunamadı.'));
              }

              final first = reports.first;
              final question = (first['question'] ?? '') as String;
              final options = (first['options'] ?? const []) as List;
              final correctIndex = (first['correctIndex'] ?? -1) as int;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Soru', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(question, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          ...List.generate(options.length, (i) => ListTile(
                                dense: true,
                                leading: Icon(
                                  i == correctIndex ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                  color: i == correctIndex
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                title: Text(options[i].toString()),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Kullanıcı Bildirimleri', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...reports.map((r) {
                    final reason = (r['reason'] ?? '').toString();
                    final selectedIndex = r['selectedIndex'];
                    final userId = r['userId'] ?? '-';
                    final ts = r['createdAt'];
                    final rid = r['id']?.toString();
                    return Dismissible(
                      key: ValueKey(rid ?? r.hashCode),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Rapor silinsin mi?'),
                            content: const Text('Bu işlem geri alınamaz.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                            ],
                          ),
                        );
                        return ok ?? false;
                      },
                      onDismissed: (_) async {
                        if (rid != null) {
                          await callAdminFn('single', reportId: rid);
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: Theme.of(context).colorScheme.error,
                        child: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.onError),
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text(reason.isEmpty ? '(Gerekçe yok)' : reason),
                          subtitle: Text('Kullanıcı: $userId  |  Seçim: ${selectedIndex ?? '-'}  |  Tarih: ${ts ?? '-'}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Rapor silinsin mi?'),
                                  content: const Text('Bu işlem geri alınamaz.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                                  ],
                                ),
                              );
                              if (ok == true && rid != null) {
                                await callAdminFn('single', reportId: rid);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
        error: (e, _) => Center(child: Text('Hata: $e')),
        loading: () => const LogoLoader(),
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
