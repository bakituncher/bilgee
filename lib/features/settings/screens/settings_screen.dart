// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/settings/logic/settings_notifier.dart';
import 'package:taktik/features/settings/widgets/settings_section.dart';
import 'package:taktik/features/settings/widgets/settings_tile.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // ONAY AKIŞINI YÖNETEN FONKSİYONLAR

  void _showExamChangeFlow(BuildContext context, WidgetRef ref) {
    // 1. Onay Diyaloğu
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentColor),
            SizedBox(width: 10),
            Expanded(child: Text("Çok Önemli Uyarı", overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: const Text(
            "Sınav türünü değiştirmek, mevcut ilerlemenizi tamamen sıfırlayacaktır.\n\n"
                "• Tüm deneme sonuçlarınız\n"
                "• Haftalık planlarınız ve stratejileriniz\n"
                "• Konu analizleriniz ve istatistikleriniz\n\n"
                "kalıcı olarak silinecektir. Bu işlem geri alınamaz. Devam etmek istediğinizden emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("İptal Et"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
            onPressed: () {
              Navigator.of(context).pop();
              _showFinalConfirmationDialog(context, ref); // 2. Onay Diyaloğuna geç
            },
            child: const Text("Anladım, Devam Et"),
          ),
        ],
      ),
    );
  }

  void _showFinalConfirmationDialog(BuildContext context, WidgetRef ref) {
    final confirmationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const confirmationText = "SİL";

    showDialog(
      context: context,
      barrierDismissible: false, // İşlem sırasında kapatılmasını engelle
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "Bu son adımdır. Devam etmek için lütfen aşağıdaki alana büyük harflerle 'SİL' yazın."),
                  const SizedBox(height: 20),
                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: confirmationController,
                      validator: (value) {
                        if (value == null || value.trim() != confirmationText) {
                          return 'Lütfen büyük harflerle "SİL" yazın.';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Onay için "SİL" yazın',
                        hintText: 'SİL',
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Vazgeç"),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final isLoading = ref.watch(settingsNotifierProvider).isLoading;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
                      onPressed: (confirmationController.text == confirmationText && !isLoading)
                          ? () {
                        if (formKey.currentState!.validate()) {
                          // SADECE İŞLEMİ TETİKLE VE DİYALOĞU KAPAT.
                          // NAVİGASYON YAPMA! GoRouter halledecek.
                          Navigator.of(dialogContext).pop();
                          ref.read(settingsNotifierProvider.notifier).resetAccountForNewExam();
                        }
                      }
                          : null, // Butonu pasif yap
                      child: isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Tüm Verileri Sil ve Değiştir"),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bağlantı açılamadı: $url')),
      );
    }
  }

  Future<void> _launchEmail(BuildContext context, String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=TaktikAI Geri Bildirim',
    );
    if (!await launchUrl(emailUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta uygulaması bulunamadı.')),
      );
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text("Çıkış Yap"),
          content: const Text("Oturumu sonlandırmak istediğinizden emin misiniz?"),
          actions: <Widget>[
            TextButton(
              child: const Text("İptal"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Çıkış Yap", style: TextStyle(color: AppTheme.accentColor)),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider.notifier).signOut();
              },
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSubmitting = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setState(() => isSubmitting = true);
              try {
                await ref.read(authControllerProvider.notifier).updatePassword(
                      currentPassword: currentController.text.trim(),
                      newPassword: newController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Şifre başarıyla güncellendi.'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: AppTheme.accentColor,
                    ),
                  );
                }
              } finally {
                if (context.mounted) setState(() => isSubmitting = false);
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.cardColor,
              title: const Text('Şifreyi Değiştir'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentController,
                        decoration: InputDecoration(
                          labelText: 'Mevcut Şifre',
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            tooltip: obscureCurrent ? 'Şifreyi göster' : 'Şifreyi gizle',
                            onPressed: isSubmitting
                                ? null
                                : () => setState(() => obscureCurrent = !obscureCurrent),
                          ),
                        ),
                        obscureText: obscureCurrent,
                        validator: (v) => (v == null || v.isEmpty) ? 'Mevcut şifre gerekli.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newController,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre',
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            tooltip: obscureNew ? 'Şifreyi göster' : 'Şifreyi gizle',
                            onPressed: isSubmitting
                                ? null
                                : () => setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        obscureText: obscureNew,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Yeni şifre gerekli.';
                          if (v.length < 6) return 'En az 6 karakter olmalı.';
                          if (v == currentController.text) return 'Yeni şifre eskisiyle aynı olamaz.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmController,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre (Tekrar)',
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            tooltip: obscureConfirm ? 'Şifreyi göster' : 'Şifreyi gizle',
                            onPressed: isSubmitting
                                ? null
                                : () => setState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        obscureText: obscureConfirm,
                        validator: (v) => v != newController.text ? 'Şifreler eşleşmiyor.' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Güncelle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sadece hata durumunda kullanıcıya mesaj göstermek için dinle
    ref.listen<SettingsState>(settingsNotifierProvider, (previous, next) {
      if (next.resetStatus == ResetStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veriler sıfırlanırken bir hata oluştu. Lütfen tekrar deneyin."),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        ref.read(settingsNotifierProvider.notifier).resetOperationStatus();
      }
    });

    final user = ref.watch(userProfileProvider).value;
    // Admin claim durumunu oku (yükleneceği için null olabilir)
    final isAdmin = ref.watch(adminClaimProvider).value ?? false;

    Future<void> _handleBack() async {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ayarlar"),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: _handleBack,
        ),
      ),
      body: user == null
          ? const LogoLoader()
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SettingsSection(title: "Hesap"),
           SettingsTile(
            icon: Icons.person_outline_rounded,
            title: "Profili Düzenle",
            subtitle: "Kişisel bilgilerinizi güncelleyin",
            onTap: () => context.push(AppRoutes.editProfile),
          ),
          SettingsTile(
            icon: Icons.alternate_email_rounded,
            title: "E-posta",
            subtitle: user.email,
          ),
          SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Şifreyi Değiştir',
            subtitle: 'Güvenliğiniz için şifrenizi güncelleyin',
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          const SettingsSection(title: "Sınav ve Planlama"),
          SettingsTile(
            icon: Icons.school_outlined,
            title: "Sınavı Değiştir",
            subtitle: "Tüm ilerlemeniz sıfırlanacak",
            onTap: () => _showExamChangeFlow(context, ref),
          ),
          SettingsTile(
            icon: Icons.edit_calendar_outlined,
            title: "Zaman Haritası",
            subtitle: "Haftalık çalışma takviminizi düzenleyin",
            onTap: () => context.push(AppRoutes.availability),
          ),
          const SettingsSection(title: "Uygulama"),
           SettingsTile(
            icon: Icons.description_outlined,
            title: "Kullanım Sözleşmesi",
            subtitle: "Hizmet şartlarımızı okuyun",
            onTap: () => _launchURL(context, "https://codenzi.com"),
          ),
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: "Gizlilik Politikası",
            subtitle: "Verilerinizi nasıl koruduğumuzu öğrenin",
            onTap: () => _launchURL(context, "https://codenzi.com"),
          ),
          SettingsTile(
            icon: Icons.contact_support_outlined,
            title: "Bize Ulaşın",
            subtitle: "Görüş ve önerileriniz için",
            onTap: () => _launchEmail(context, "info@codenzi.com"),
          ),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            title: "Uygulama Hakkında",
            subtitle: "Versiyon 1.0.0",
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'TaktikAI',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Codenzi. Tüm hakları saklıdır.',
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 15),
                    child: Text('TaktikAI, kişisel yapay zeka destekli sınav koçunuzdur.'),
                  )
                ],
              );
            },
          ),
          // --- Admin: sadece admin claim varsa göster ---
          if (isAdmin) ...[
            const SettingsSection(title: "Admin"),
          ],
          const SettingsSection(title: "Oturum"),
          SettingsTile(
            icon: Icons.logout_rounded,
            title: "Çıkış Yap",
            subtitle: "Hesabınızdan güvenle çıkış yapın",
            iconColor: AppTheme.accentColor,
            textColor: AppTheme.accentColor,
            onTap: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
    );
  }
}
