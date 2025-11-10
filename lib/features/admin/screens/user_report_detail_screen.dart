
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package.taktik/shared/widgets/app_loader.dart';
import 'package:timeago/timeago.dart' as timeago;

// Rapor detayını getiren provider
final reportDetailProvider = FutureProvider.family<DocumentSnapshot, String>((ref, reportId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('reports').doc(reportId).get();
});

class UserReportDetailScreen extends ConsumerStatefulWidget {
  final String reportId;
  const UserReportDetailScreen({super.key, required this.reportId});

  @override
  ConsumerState<UserReportDetailScreen> createState() => _UserReportDetailScreenState();
}

class _UserReportDetailScreenState extends ConsumerState<UserReportDetailScreen> {
  Future<void> _updateStatus(String newStatus) async {
    try {
      await ref.read(firestoreServiceProvider).updateReportStatus(
        reportId: widget.reportId,
        newStatus: newStatus,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rapor durumu "$newStatus" olarak güncellendi.')),
      );
      // Provider'ı yenileyerek ekranın güncel veriyi çekmesini sağla
      ref.invalidate(reportDetailProvider(widget.reportId));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Durum güncellenemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportDetailAsync = ref.watch(reportDetailProvider(widget.reportId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor Detayı'),
      ),
      body: reportDetailAsync.when(
        data: (doc) {
          if (!doc.exists) {
            return const Center(child: Text('Rapor bulunamadı.'));
          }
          final report = doc.data() as Map<String, dynamic>;
          final createdAt = (report['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _buildDetailRow('Rapor ID', widget.reportId),
                _buildDetailRow('Durum', report['status'] ?? 'Bilinmiyor'),
                _buildDetailRow('Rapor Edilen ID', report['reportedUserId'] ?? 'N/A'),
                _buildDetailRow('Raporlayan ID', report['reporterId'] ?? 'N/A'),
                _buildDetailRow('Tarih', timeago.format(createdAt, locale: 'tr')),
                const Divider(height: 32),
                Text('Neden', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(report['reason'] ?? 'Neden belirtilmemiş.'),
                const Divider(height: 32),
                Text('Aksiyonlar', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('İncelendi Olarak İşaretle'),
                      onPressed: () => _updateStatus('reviewed'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.gavel),
                      label: const Text('Aksiyon Alındı'),
                      onPressed: () => _updateStatus('action-taken'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Kapat'),
                      onPressed: () => _updateStatus('closed'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const AppLoader(),
        error: (e, s) => Center(child: Text('Rapor detayı yüklenemedi: $e')),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
