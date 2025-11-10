// lib/features/admin/screens/user_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/data/models/user_report_model.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:intl/intl.dart';

/// Kullanıcı raporlarını admin panelinde görüntüleyen ekran
class UserReportsScreen extends ConsumerStatefulWidget {
  const UserReportsScreen({super.key});

  @override
  ConsumerState<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends ConsumerState<UserReportsScreen> {
  ReportStatus _selectedStatus = ReportStatus.pending;
  List<Map<String, dynamic>>? _reports;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('moderation-adminListReports');
      final result = await callable.call<Map<String, dynamic>>({
        'status': _selectedStatus.value,
        'limit': 50,
      });

      final data = result.data;
      if (data != null && data['success'] == true) {
        final reports = data['reports'] as List<dynamic>?;
        setState(() {
          _reports = reports?.cast<Map<String, dynamic>>() ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Raporlar yüklenemedi';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateReport(String reportId, ReportStatus newStatus, String? adminNotes) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('moderation-adminUpdateReport');
      await callable.call<Map<String, dynamic>>({
        'reportId': reportId,
        'status': newStatus.value,
        'adminNotes': adminNotes,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapor güncellendi')),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Raporları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Durum filtreleri
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<ReportStatus>(
              segments: ReportStatus.values
                  .map((status) => ButtonSegment<ReportStatus>(
                        value: status,
                        label: Text(status.displayName),
                      ))
                  .toList(),
              selected: {_selectedStatus},
              onSelectionChanged: (Set<ReportStatus> newSelection) {
                setState(() {
                  _selectedStatus = newSelection.first;
                });
                _loadReports();
              },
            ),
          ),

          // Raporlar listesi
          Expanded(
            child: _isLoading
                ? const LogoLoader()
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                            const SizedBox(height: 16),
                            Text(_error!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadReports,
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      )
                    : _reports == null || _reports!.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bu durumda rapor yok',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReports,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _reports!.length,
                              itemBuilder: (context, index) {
                                final report = _reports![index];
                                return _ReportCard(
                                  report: report,
                                  onUpdate: (status, notes) {
                                    _updateReport(
                                      report['id'] as String,
                                      status,
                                      notes,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final Function(ReportStatus status, String? notes) onUpdate;

  const _ReportCard({
    required this.report,
    required this.onUpdate,
  });

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Bilinmiyor';
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
        date = (timestamp as dynamic).toDate();
      } else {
        return 'Bilinmiyor';
      }
      return DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(date);
    } catch (e) {
      return 'Bilinmiyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final reportedUserId = report['reportedUserId'] as String? ?? 'Bilinmiyor';
    final reporterUserId = report['reporterUserId'] as String? ?? 'Bilinmiyor';
    final reason = UserReportReason.fromString(report['reason'] as String? ?? 'other');
    final details = report['details'] as String?;
    final createdAt = report['createdAt'];
    final status = ReportStatus.fromString(report['status'] as String? ?? 'pending');
    final adminNotes = report['adminNotes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.error,
                    ),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.person_outlined,
              label: 'Raporlanan',
              value: reportedUserId,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.person,
              label: 'Raporlayan',
              value: reporterUserId,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.access_time,
              label: 'Tarih',
              value: _formatDate(createdAt),
            ),
            if (details != null && details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Detaylar:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                details,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (adminNotes != null && adminNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Notları:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminNotes,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
            if (status == ReportStatus.pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showUpdateDialog(context, ReportStatus.dismissed),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reddet'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showUpdateDialog(context, ReportStatus.resolved),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Çözüldü'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, ReportStatus newStatus) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Raporu ${newStatus.displayName} olarak işaretle'),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Admin Notları (Opsiyonel)',
            hintText: 'Karar hakkında notlar...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdate(newStatus, notesController.text.trim().isNotEmpty ? notesController.text.trim() : null);
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ReportStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case ReportStatus.pending:
        backgroundColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange;
        break;
      case ReportStatus.reviewed:
        backgroundColor = Colors.blue.withOpacity(0.2);
        textColor = Colors.blue;
        break;
      case ReportStatus.resolved:
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green;
        break;
      case ReportStatus.dismissed:
        backgroundColor = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

