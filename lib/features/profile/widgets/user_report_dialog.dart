// lib/features/profile/widgets/user_report_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/user_report_model.dart';
import 'package:taktik/data/providers/moderation_providers.dart';

/// Kullanıcı raporlama dialog'u
class UserReportDialog extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const UserReportDialog({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  ConsumerState<UserReportDialog> createState() => _UserReportDialogState();
}

class _UserReportDialogState extends ConsumerState<UserReportDialog> {
  UserReportReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir neden seçin')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(moderationServiceProvider);
      await service.reportUser(
        targetUserId: widget.targetUserId,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isNotEmpty
            ? _detailsController.text.trim()
            : null,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapor gönderildi. İnceleme süreci başlatıldı.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.flag_outlined, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kullanıcıyı Raporla',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.targetUserName} kullanıcısını neden raporluyorsunuz?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            // Raporlama nedenleri
            ...UserReportReason.values.map((reason) {
              return RadioListTile<UserReportReason>(
                value: reason,
                groupValue: _selectedReason,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _selectedReason = value);
                      },
                title: Text(
                  reason.displayName,
                  style: theme.textTheme.bodyMedium,
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: colorScheme.error,
              );
            }),
            const SizedBox(height: 16),
            // Ek detaylar
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 500,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: 'Ek Detaylar (Opsiyonel)',
                hintText: 'Durumu açıklayın...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Not: Raporunuz gizli kalacak ve incelenecektir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onError,
                  ),
                )
              : const Text('Gönder'),
        ),
      ],
    );
  }
}

/// Kullanıcı raporlama dialog'unu göster
Future<bool?> showUserReportDialog(
  BuildContext context, {
  required String targetUserId,
  required String targetUserName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => UserReportDialog(
      targetUserId: targetUserId,
      targetUserName: targetUserName,
    ),
  );
}

