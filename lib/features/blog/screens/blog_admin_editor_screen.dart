// lib/features/blog/screens/blog_admin_editor_screen.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BlogAdminEditorScreen extends ConsumerStatefulWidget {
  const BlogAdminEditorScreen({super.key});

  @override
  ConsumerState<BlogAdminEditorScreen> createState() => _BlogAdminEditorScreenState();
}

class _BlogAdminEditorScreenState extends ConsumerState<BlogAdminEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _excerptCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _authorCtrl = TextEditingController(text: 'BilgeAI');
  String _locale = 'tr';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _slugCtrl.dispose();
    _excerptCtrl.dispose();
    _coverUrlCtrl.dispose();
    _tagsCtrl.dispose();
    _contentCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  String _toSlug(String input) {
    var s = input.toLowerCase();
    const from = 'çğıöşüâîûäëïöüãõ';
    const to   = 'cgiosuaiuaeiouao';
    final fromChars = from.split('');
    final toChars = to.split('');
    for (int i = 0; i < fromChars.length && i < toChars.length; i++) {
      s = s.replaceAll(fromChars[i], toChars[i]);
    }
    // Whitespace türlerini tek boşluk yap
    s = s.replaceAll('\n', ' ').replaceAll('\r', ' ').replaceAll('\t', ' ');
    // Sadece a-z, 0-9, boşluk ve - kalsın
    final buf = StringBuffer();
    for (final code in s.codeUnits) {
      final c = String.fromCharCode(code);
      final isLower = code >= 97 && code <= 122; // a-z
      final isDigit = code >= 48 && code <= 57;  // 0-9
      if (isLower || isDigit || c == '-' || c == ' ') {
        buf.write(c);
      }
    }
    s = buf.toString();
    // Boşlukları tek tireye çevir
    s = s.trim().split(' ').where((e) => e.isNotEmpty).join('-');
    // Birden çok tireyi tek tire yap
    while (s.contains('--')) {
      s = s.replaceAll('--', '-');
    }
    // Baştaki/sondaki tireleri temizle
    while (s.startsWith('-')) {
      s = s.substring(1);
    }
    while (s.endsWith('-')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  int _estimateReadTime(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;
    final minutes = (words / 200).ceil();
    return minutes.clamp(1, 60);
  }

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final fs = FirebaseFirestore.instance;
      final now = DateTime.now();
      final title = _titleCtrl.text.trim();
      final slug = _slugCtrl.text.trim().isEmpty ? _toSlug(title) : _slugCtrl.text.trim();
      final content = _contentCtrl.text.trim();
      final readTime = _estimateReadTime(content);
      final tags = _tagsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final data = <String, dynamic>{
        'title': title,
        'slug': slug,
        'excerpt': _excerptCtrl.text.trim(),
        'contentMarkdown': content,
        'coverImageUrl': _coverUrlCtrl.text.trim(),
        'tags': tags,
        'locale': _locale,
        'status': publish ? 'published' : 'draft',
        'publishedAt': publish ? Timestamp.fromDate(now) : null,
        'updatedAt': Timestamp.fromDate(now),
        'author': _authorCtrl.text.trim().isEmpty ? 'BilgeAI' : _authorCtrl.text.trim(),
        'readTime': readTime,
      };

      // Slug'ı doküman ID yap → tekrar yazımlarda merge
      await fs.collection('posts').doc(slug).set(data, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(publish ? 'Yayınlandı' : 'Taslak kaydedildi')),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (Navigator.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/blog');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(adminClaimProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Blog Yazısı')),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (isAdmin) {
          if (!isAdmin) {
            return const Center(child: Text('Erişim yok (admin gerekli).'));
          }
          return AbsorbPointer(
            absorbing: _isSaving,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Başlık'),
                      onChanged: (v) {
                        if (_slugCtrl.text.trim().isEmpty) {
                          _slugCtrl.text = _toSlug(v);
                        }
                        setState(() {});
                      },
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _slugCtrl,
                      decoration: const InputDecoration(labelText: 'Slug (url-dostu)'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _excerptCtrl,
                      decoration: const InputDecoration(labelText: 'Özet (excerpt)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _coverUrlCtrl,
                      decoration: const InputDecoration(labelText: 'Kapak Görseli URL (opsiyonel)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tagsCtrl,
                      decoration: const InputDecoration(labelText: 'Etiketler (virgülle)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _locale,
                      items: const [
                        DropdownMenuItem(value: 'tr', child: Text('Türkçe (tr)')),
                        DropdownMenuItem(value: 'en', child: Text('English (en)')),
                      ],
                      onChanged: (v) => setState(() => _locale = v ?? 'tr'),
                      decoration: const InputDecoration(labelText: 'Dil'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _authorCtrl,
                      decoration: const InputDecoration(labelText: 'Yazar (opsiyonel)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contentCtrl,
                      decoration: const InputDecoration(labelText: 'İçerik (Markdown)'),
                      minLines: 10,
                      maxLines: 24,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: AppTheme.secondaryTextColor),
                        const SizedBox(width: 6),
                        Text('Tahmini okuma süresi: ${_estimateReadTime(_contentCtrl.text)} dk'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : () => _save(publish: false),
                            child: const Text('Taslak Kaydet'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : () => _save(publish: true),
                            child: const Text('Hemen Yayınla'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
