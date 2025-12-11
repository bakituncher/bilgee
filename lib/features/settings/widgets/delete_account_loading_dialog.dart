// lib/features/settings/widgets/delete_account_loading_dialog.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class DeleteAccountLoadingDialog extends StatelessWidget {
  const DeleteAccountLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Yükleme göstergesi
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.error,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Mesaj
              Text(
                "Hesabınız siliniyor...",
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

