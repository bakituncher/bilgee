// lib/features/admin/screens/question_report_detail_screen.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuestionReportDetailScreen extends ConsumerWidget {
  final String qhash;
  const QuestionReportDetailScreen({super.key, required this.qhash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(adminClaimProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Detayı'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isAdminAsync.when(
        data: (isAdmin) {
          if (!isAdmin) return const _Unauthorized();
          final stream = ref.watch(firestoreServiceProvider).streamQuestionReportsByHash(qhash);
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
                                  color: i == correctIndex ? AppTheme.successColor : AppTheme.secondaryTextColor,
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
                    return Card(
                      child: ListTile(
                        title: Text(reason.isEmpty ? '(Gerekçe yok)' : reason),
                        subtitle: Text('Kullanıcı: $userId  |  Seçim: ${selectedIndex ?? '-'}  |  Tarih: ${ts ?? '-'}'),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
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
