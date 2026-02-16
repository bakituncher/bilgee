// lib/features/admin/screens/version_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/core/services/version_check_service.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class VersionManagementScreen extends ConsumerStatefulWidget {
  const VersionManagementScreen({super.key});

  @override
  ConsumerState<VersionManagementScreen> createState() => _VersionManagementScreenState();
}

class _VersionManagementScreenState extends ConsumerState<VersionManagementScreen> {
  final _androidFormKey = GlobalKey<FormState>();
  final _iosFormKey = GlobalKey<FormState>();

  // Android Controllers
  final _androidMinBuildCtrl = TextEditingController();
  final _androidMessageCtrl = TextEditingController();
  bool _androidForceUpdate = false;

  // iOS Controllers
  final _iosMinBuildCtrl = TextEditingController();
  final _iosMessageCtrl = TextEditingController();
  bool _iosForceUpdate = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _androidMinBuildCtrl.dispose();
    _androidMessageCtrl.dispose();
    _iosMinBuildCtrl.dispose();
    _iosMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_control')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};

        // Android config
        final androidData = data['android'] as Map<String, dynamic>?;
        if (androidData != null) {
          _androidMinBuildCtrl.text = androidData['minBuildNumber']?.toString() ?? '';
          _androidMessageCtrl.text = androidData['updateMessage'] ?? '';
          _androidForceUpdate = androidData['forceUpdate'] ?? false;
        }

        // iOS config
        final iosData = data['ios'] as Map<String, dynamic>?;
        if (iosData != null) {
          _iosMinBuildCtrl.text = iosData['minBuildNumber']?.toString() ?? '';
          _iosMessageCtrl.text = iosData['updateMessage'] ?? '';
          _iosForceUpdate = iosData['forceUpdate'] ?? false;
        }

        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAndroidConfig() async {
    if (!_androidFormKey.currentState!.validate()) return;

    // Onay diyalogu göster
    final confirmed = await _showConfirmationDialog(
      platform: 'Android',
      forceUpdate: _androidForceUpdate,
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await VersionCheckService.updateVersionConfig(
        platform: 'android',
        minBuildNumber: _androidMinBuildCtrl.text.trim().isEmpty ? null : int.tryParse(_androidMinBuildCtrl.text.trim()),
        updateMessage: _androidMessageCtrl.text.trim().isEmpty ? null : _androidMessageCtrl.text.trim(),
        forceUpdate: _androidForceUpdate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Android konfigürasyonu kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveIosConfig() async {
    if (!_iosFormKey.currentState!.validate()) return;

    // Onay diyalogu göster
    final confirmed = await _showConfirmationDialog(
      platform: 'iOS',
      forceUpdate: _iosForceUpdate,
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await VersionCheckService.updateVersionConfig(
        platform: 'ios',
        minBuildNumber: _iosMinBuildCtrl.text.trim().isEmpty ? null : int.tryParse(_iosMinBuildCtrl.text.trim()),
        updateMessage: _iosMessageCtrl.text.trim().isEmpty ? null : _iosMessageCtrl.text.trim(),
        forceUpdate: _iosForceUpdate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ iOS konfigürasyonu kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showConfirmationDialog({
    required String platform,
    required bool forceUpdate,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: forceUpdate ? theme.colorScheme.error : theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Onayla',
                  style: TextStyle(fontSize: 18),
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
                  '$platform konfigürasyonu kaydedilecek.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (forceUpdate) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.block,
                          color: theme.colorScheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Zorunlu güncelleme AÇIK!\nEski kullanıcılar uygulamaya giremeyecek.',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Zorunlu güncelleme kapalı.\nTüm kullanıcılar normal giriş yapabilir.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: forceUpdate ? theme.colorScheme.error : theme.colorScheme.primary,
                foregroundColor: forceUpdate ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
              ),
              child: const Text('ONAYLA'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Versiyon Yönetimi'),
        leading: const CustomBackButton(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Info Card
                Card(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 8),
                            Text(
                              'Zorunlu Güncelleme Sistemi',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Build number belirleyin\n'
                          '• Zorunlu güncellemeyi açın\n'
                          '• Kaydedin\n\n'
                          '→ Eski build kullanan kullanıcılar uygulamaya giremez.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Android Configuration
                _buildPlatformCard(
                  context,
                  'Android',
                  Icons.android,
                  Colors.green,
                  _androidFormKey,
                  _androidMinBuildCtrl,
                  _androidMessageCtrl,
                  _androidForceUpdate,
                  (value) => setState(() => _androidForceUpdate = value),
                  _saveAndroidConfig,
                ),
                const SizedBox(height: 24),

                // iOS Configuration
                _buildPlatformCard(
                  context,
                  'iOS',
                  Icons.apple,
                  Colors.grey.shade800,
                  _iosFormKey,
                  _iosMinBuildCtrl,
                  _iosMessageCtrl,
                  _iosForceUpdate,
                  (value) => setState(() => _iosForceUpdate = value),
                  _saveIosConfig,
                ),
              ],
            ),
    );
  }

  Widget _buildPlatformCard(
    BuildContext context,
    String platform,
    IconData icon,
    Color iconColor,
    GlobalKey<FormState> formKey,
    TextEditingController minBuildCtrl,
    TextEditingController messageCtrl,
    bool forceUpdate,
    Function(bool) onForceUpdateChanged,
    VoidCallback onSave,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    platform,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Build Number
              TextFormField(
                controller: minBuildCtrl,
                decoration: InputDecoration(
                  labelText: 'Minimum Build Number',
                  hintText: 'Örn: 51',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.tag),
                  helperText: 'Bu build\'den düşük kullanıcılar giremez',
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Build number zorunlu';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Update Message
              TextFormField(
                controller: messageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Güncelleme Mesajı',
                  hintText: 'Kritik güvenlik güncellemesi! Lütfen güncelleyin.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                  helperText: 'Kullanıcıya gösterilecek mesaj',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Force Update Switch
              Container(
                decoration: BoxDecoration(
                  color: forceUpdate
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: forceUpdate
                        ? theme.colorScheme.error.withValues(alpha: 0.5)
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Zorunlu Güncelleme',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: forceUpdate ? theme.colorScheme.error : null,
                    ),
                  ),
                  subtitle: Text(
                    forceUpdate
                        ? '⚠️ Eski kullanıcılar uygulamayı KULLANAMAZ'
                        : 'Kapalı - Herkes normal giriş yapar',
                  ),
                  value: forceUpdate,
                  onChanged: onForceUpdateChanged,
                  activeTrackColor: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : onSave,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text(
                    'Kaydet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
