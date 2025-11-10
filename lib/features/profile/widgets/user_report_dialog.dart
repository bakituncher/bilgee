// lib/features/profile/widgets/user_report_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/user_report_model.dart';
import 'package:taktik/data/providers/moderation_providers.dart';

/// Kompakt kullanıcı raporlama dialog'u
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

class _UserReportDialogState extends ConsumerState<UserReportDialog>
    with SingleTickerProviderStateMixin {
  UserReportReason? _selectedReason;
  bool _isSubmitting = false;
  bool _showDetailsStep = false;
  final TextEditingController _detailsController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleReasonSelected(UserReportReason reason) {
    setState(() {
      _selectedReason = reason;
      if (reason == UserReportReason.other) {
        _showDetailsStep = true;
      } else {
        _showDetailsStep = false;
      }
    });
  }

  void _handleBack() {
    setState(() {
      _showDetailsStep = false;
      _detailsController.clear();
    });
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      _showSnackBar('Lütfen bir neden seçin', isError: true);
      return;
    }

    // Diğer seçiliyse ve açıklama yoksa uyar
    if (_selectedReason == UserReportReason.other &&
        _detailsController.text.trim().isEmpty) {
      _showSnackBar('Lütfen açıklama yazın', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(moderationServiceProvider);
      await service.reportUser(
        targetUserId: widget.targetUserId,
        reason: _selectedReason!,
        details: _selectedReason == UserReportReason.other
            ? _detailsController.text.trim()
            : null,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
      _showSnackBar('Rapor gönderildi', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(_getErrorMessage(e.toString()), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Çok fazla')) {
      return 'Çok fazla istek';
    } else if (error.contains('zaman aşımı')) {
      return 'Bağlantı hatası';
    } else if (error.contains('giriş')) {
      return 'Tekrar giriş yapın';
    }
    return 'Bir hata oluştu';
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        color: colorScheme.error,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kullanıcıyı Raporla',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.targetUserName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_showDetailsStep) ...[
                        // Adım 1: Sebep Seçimi
                        Text(
                          'Neden',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Reason cards
                        ...UserReportReason.values.map((reason) {
                          final isSelected = _selectedReason == reason;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ReasonCard(
                              reason: reason,
                              isSelected: isSelected,
                              enabled: !_isSubmitting,
                              onTap: () => _handleReasonSelected(reason),
                            ),
                          );
                        }),
                      ] else ...[
                        // Adım 2: Açıklama (sadece Diğer için)
                        Row(
                          children: [
                            IconButton(
                              onPressed: _isSubmitting ? null : _handleBack,
                              icon: const Icon(Icons.arrow_back),
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Açıklama',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _detailsController,
                          maxLines: 4,
                          maxLength: 300,
                          enabled: !_isSubmitting,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Lütfen detaylı açıklayın...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  if (_showDetailsStep) {
                                    _handleBack();
                                  } else {
                                    Navigator.of(context).pop(false);
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(_showDetailsStep ? 'Geri' : 'İptal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  if (_selectedReason == null) {
                                    _showSnackBar('Lütfen bir neden seçin', isError: true);
                                    return;
                                  }

                                  if (_selectedReason == UserReportReason.other && !_showDetailsStep) {
                                    // Diğer seçili ve henüz açıklama adımında değilse, açıklama adımına geç
                                    setState(() => _showDetailsStep = true);
                                  } else {
                                    // Diğer seçeneği değilse veya açıklama adımındaysa, direkt gönder
                                    _submitReport();
                                  }
                                },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: colorScheme.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _showDetailsStep
                                      ? 'Gönder'
                                      : (_selectedReason == UserReportReason.other
                                          ? 'Devam'
                                          : 'Gönder'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final UserReportReason reason;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _ReasonCard({
    required this.reason,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (reason) {
      case UserReportReason.spam:
        return Icons.block;
      case UserReportReason.harassment:
        return Icons.warning_amber_rounded;
      case UserReportReason.inappropriate:
        return Icons.report_gmailerrorred;
      case UserReportReason.impersonation:
        return Icons.person_off;
      case UserReportReason.underage:
        return Icons.child_care;
      case UserReportReason.hateSpeech:
        return Icons.sentiment_very_dissatisfied;
      case UserReportReason.scam:
        return Icons.gpp_bad;
      case UserReportReason.other:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.5)
                : colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getIcon(),
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reason.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
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
    barrierDismissible: false,
    builder: (context) => UserReportDialog(
      targetUserId: targetUserId,
      targetUserName: targetUserName,
    ),
  );
}

