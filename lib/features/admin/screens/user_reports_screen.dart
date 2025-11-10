
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/shared/widgets/app_loader.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';

// Raporları getiren provider
final reportsProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

class UserReportsScreen extends ConsumerWidget {
  const UserReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Raporları'),
      ),
      body: reportsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return const Center(child: Text('Henüz hiç rapor gönderilmemiş.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final report = docs[index].data() as Map<String, dynamic>;
              final createdAt = (report['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

              return ListTile(
                leading: Icon(
                  report['status'] == 'reviewed' ? Icons.check_circle_outline : Icons.report_problem_outlined,
                  color: report['status'] == 'reviewed' ? Colors.green : Colors.orange,
                ),
                title: Text('Rapor Edilen: ${report['reportedUserId']}'),
                subtitle: Text('Neden: ${report['reason']}\nRaporlayan: ${report['reporterId']}'),
                trailing: Text(timeago.format(createdAt, locale: 'tr')),
                isThreeLine: true,
                onTap: () {
                  context.push('/admin/user-reports/${docs[index].id}');
                },
              );
            },
          );
        },
        loading: () => const AppLoader(),
        error: (e, s) => Center(child: Text('Raporlar yüklenemedi: $e')),
      ),
    );
  }
}
