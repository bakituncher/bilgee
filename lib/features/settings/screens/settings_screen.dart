// lib/features/settings/screens/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/settings/logic/settings_notifier.dart';
import 'package:taktik/features/settings/widgets/settings_section.dart';
import 'package:taktik/features/settings/widgets/settings_tile.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/core/theme/theme_provider.dart';
import 'package:taktik/core/utils/app_info_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  // HESAP SİLME AKIŞI

  void _showDeleteAccountFlow(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                color: theme.colorScheme.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Hesabınızı Silmek İstiyor Musunuz?",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.delete_sweep_rounded,
                    color: theme.colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Bu işlem geri alınamaz!",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tüm verileriniz kalıcı olarak silinecektir.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("İptal"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteAccountConfirmation(context, ref);
            },
            child: const Text("Devam Et"),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsAlignment: MainAxisAlignment.end,
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context, WidgetRef ref) {
    final confirmationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const confirmationText = "HESABIMI SİL";
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Başlık
                      Text(
                        "Son Onay",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Uyarı Mesajı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Bu işlem kalıcıdır ve geri alınamaz!",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Talimat
                      Text(
                        "Onaylamak için aşağıya yazın:",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Onay Metni
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.error.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          confirmationText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.colorScheme.error,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Form
                      Form(
                        key: formKey,
                        child: TextFormField(
                          controller: confirmationController,
                          onChanged: (_) => setState(() {}),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1.3,
                            color: theme.colorScheme.onSurface,
                          ),
                          validator: (value) {
                            if (value == null || value.trim() != confirmationText) {
                              return 'Lütfen "$confirmationText" yazın';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: confirmationText,
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.25),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.1,
                            ),
                            errorMaxLines: 2,
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: theme.colorScheme.error,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: theme.colorScheme.error,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: theme.colorScheme.error,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Butonlar
                      Consumer(
                        builder: (context, ref, child) {
                          final isLoading = ref.watch(settingsNotifierProvider).isLoading;
                          final isValid = confirmationController.text == confirmationText;

                          return Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => Navigator.of(dialogContext).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    "Vazgeç",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error,
                                    foregroundColor: theme.colorScheme.onError,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    minimumSize: const Size.fromHeight(44),
                                    disabledBackgroundColor:
                                        theme.colorScheme.surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: (isValid && !isLoading)
                                      ? () {
                                    if (formKey.currentState!.validate()) {
                                      Navigator.of(dialogContext).pop();
                                      ref.read(settingsNotifierProvider.notifier)
                                          .deleteAccount();
                                    }
                                  }
                                      : null,
                                  child: isLoading
                                      ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onError,
                                    ),
                                  )
                                      : const Text(
                                    "Hesabımı Sil",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bağlantı açılamadı: $url')),
      );
    }
  }

  Future<void> _launchEmail(BuildContext context, String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Taktik Geri Bildirim',
    );
    if (!await launchUrl(emailUri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta uygulaması bulunamadı.')),
      );
    }
  }

  Future<void> _launchSubscriptionManagement(BuildContext context) async {
    String url;

    if (Platform.isIOS) {
      // iOS için App Store abonelik yönetimi
      url = 'https://apps.apple.com/account/subscriptions';
    } else if (Platform.isAndroid) {
      // Android için Google Play abonelik yönetimi
      url = 'https://play.google.com/store/account/subscriptions';
    } else {
      // Diğer platformlar için (web vb.)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu platform için abonelik yönetimi desteklenmiyor.')),
      );
      return;
    }

    await _launchURL(context, url);
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: const Text("Çıkış Yap"),
          content: const Text("Oturumu sonlandırmak istediğinizden emin misiniz?"),
          actions: <Widget>[
            TextButton(
              child: const Text("İptal"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("Çıkış Yap", style: TextStyle(color: theme.colorScheme.error)),
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
                    SnackBar(
                      content: const Text('Şifre başarıyla güncellendi.'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              } finally {
                if (context.mounted) setState(() => isSubmitting = false);
              }
            }

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
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

  // Profil header widget'ı
  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    final theme = Theme.of(context);
    final firstName = user.firstName ?? '';
    final lastName = user.lastName ?? '';
    final email = user.email ?? '';
    final displayName = firstName.isNotEmpty
        ? '$firstName ${lastName.isNotEmpty ? lastName : ''}'.trim()
        : 'Kullanıcı';
    final initials = firstName.isNotEmpty
        ? firstName.substring(0, 1).toUpperCase()
        : email.isNotEmpty
            ? email.substring(0, 1).toUpperCase()
            : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: Icon(
              Icons.edit_rounded,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            tooltip: 'Profili Düzenle',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hesap silme işlemlerini dinle
    ref.listen<SettingsState>(settingsNotifierProvider, (previous, next) {
      if (next.resetStatus == ResetStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Hesap silinirken bir hata oluştu. Lütfen tekrar deneyin."),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(settingsNotifierProvider.notifier).resetOperationStatus();
      } else if (next.resetStatus == ResetStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Hesabınız başarıyla silindi. Sizi özleyeceğiz."),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(settingsNotifierProvider.notifier).resetOperationStatus();
        // signOut zaten notifier'da çağrıldı, burada ek işlem gerekmez
      }
    });

    final user = ref.watch(userProfileProvider).value;
    final isAdmin = ref.watch(adminClaimProvider).value ?? false;

    Future<void> handleBack() async {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Ayarlar"),
        centerTitle: false,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: handleBack,
        ),
      ),
      body: user == null
          ? const LogoLoader()
          : ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Profil Header
          _buildProfileHeader(context, user),

          // Hesap Bölümü
          const SettingsSection(title: "Hesap"),
          _SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Şifreyi Değiştir',
                subtitle: 'Hesap şifrenizi değiştirin',
                onTap: () => _showChangePasswordDialog(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Icons.block_outlined,
                title: 'Engellenen Kullanıcılar',
                subtitle: 'Engellediğiniz kullanıcıları yönetin',
                onTap: () => context.push('/blocked-users'),
              ),
            ],
          ),

          // Planlama
          const SettingsSection(title: "Planlama"),
          _SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.edit_calendar_outlined,
                title: "Zaman Haritası",
                subtitle: "Haftalık çalışma takviminizi düzenleyin",
                onTap: () => context.push(AppRoutes.availability),
              ),
            ],
          ),

          // Görünüm
          const SettingsSection(title: "Görünüm"),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _ThemeSelection(),
              ),
            ],
          ),

          // Uygulama
          const SettingsSection(title: "Yardım ve Destek"),
          _SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.contact_support_outlined,
                title: "Bize Ulaşın",
                subtitle: "Görüş ve önerileriniz için",
                onTap: () => _launchEmail(context, "info@codenzi.com"),
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Icons.description_outlined,
                title: "Kullanım Sözleşmesi",
                subtitle: "Hizmet şartlarımızı okuyun",
                onTap: () => _launchURL(context, "https://www.codenzi.com/taktik-kullanim-sozlesmesi.html"),
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: "Gizlilik Politikası",
                subtitle: "Verilerinizi nasıl koruduğumuzu öğrenin",
                onTap: () => _launchURL(context, "https://www.codenzi.com/taktik-gizlilik-politikasi.html"),
              ),
              const Divider(height: 1, indent: 56),
              SettingsTile(
                icon: Icons.subscriptions_outlined,
                title: "Abonelikleri Yönet",
                subtitle: Platform.isIOS
                    ? "Aboneliklerinizi App Store'da yönetin"
                    : "Aboneliklerinizi Google Play'de yönetin",
                onTap: () => _launchSubscriptionManagement(context),
              ),
              const Divider(height: 1, indent: 56),
              Consumer(
                builder: (context, ref, child) {
                  final appVersion = ref.watch(appVersionProvider);
                  final appFullVersion = ref.watch(appFullVersionProvider);

                  return SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: "Uygulama Hakkında",
                    subtitle: "Versiyon $appFullVersion",
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Taktik',
                        applicationVersion: appVersion,
                        applicationLegalese: '© 2025 Codenzi. Tüm hakları saklıdır.',
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 15),
                            child: Text('Taktik, kişisel yapay zeka destekli sınav koçunuzdur.'),
                          )
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),

          // Admin (sadece admin ise)
          if (isAdmin) ...[
            const SettingsSection(title: "Admin"),
            _SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: "Admin Paneli",
                  subtitle: "Yönetim araçları",
                  onTap: () {}, // Admin panel eklenebilir
                ),
              ],
            ),
          ],

          // Tehlikeli Bölge
          const SettingsSection(title: "Tehlikeli Bölge"),
          _SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.delete_forever_rounded,
                title: "Hesabı Sil",
                subtitle: "Hesabınızı kalıcı olarak silin",
                iconColor: Theme.of(context).colorScheme.error,
                textColor: Theme.of(context).colorScheme.error,
                onTap: () => _showDeleteAccountFlow(context, ref),
              ),
            ],
          ),

          // Oturum
          const SettingsSection(title: "Oturum"),
          _SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                title: "Çıkış Yap",
                subtitle: "Hesabınızdan güvenle çıkış yapın",
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// CARD CONTAINER WIDGET
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// TEMA SEÇİMİ WIDGET
class _ThemeSelection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeNotifierProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.palette_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Tema',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: <ButtonSegment<ThemeMode>>[
            ButtonSegment<ThemeMode>(
              value: ThemeMode.light,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text('Açık'),
              ),
              icon: const Icon(Icons.wb_sunny_outlined, size: 18),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.dark,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text('Koyu'),
              ),
              icon: const Icon(Icons.nightlight_round, size: 18),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.system,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text('Sistem'),
              ),
              icon: const Icon(Icons.phone_iphone_rounded, size: 18),
            ),
          ],
          selected: <ThemeMode>{currentThemeMode},
          onSelectionChanged: (Set<ThemeMode> newSelection) {
            ref.read(themeModeNotifierProvider.notifier).setThemeMode(newSelection.first);
          },
          style: SegmentedButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            selectedForegroundColor: theme.colorScheme.onPrimary,
            selectedBackgroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
