// lib/features/blog/screens/blog_admin_editor_screen.dart
import 'dart:convert';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class BlogAdminEditorScreen extends ConsumerStatefulWidget {
  const BlogAdminEditorScreen({super.key, this.initialSlug});
  final String? initialSlug;

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
  // Güvenli locale: yalnıza 'tr' veya 'en'
  String? get _safeLocale {
    final v = _locale.trim().toLowerCase();
    return (v == 'tr' || v == 'en') ? v : null;
  }
  bool _isSaving = false;
  bool _isEditing = false;
  String? _originalSlug;
  bool _isLoadingExisting = false;

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

  @override
  void initState() {
    super.initState();
    if (widget.initialSlug != null && widget.initialSlug!.trim().isNotEmpty) {
      _loadExisting(widget.initialSlug!.trim());
    }
  }

  Future<void> _loadExisting(String slug) async {
    setState(() { _isLoadingExisting = true; });
    try {
      final snap = await FirebaseFirestore.instance.collection('posts').doc(slug).get();
      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>;
        _titleCtrl.text = (d['title'] ?? '').toString();
        _slugCtrl.text = (d['slug'] ?? slug).toString();
        _excerptCtrl.text = (d['excerpt'] ?? '').toString();
        _coverUrlCtrl.text = (d['coverImageUrl'] ?? '').toString();
        _tagsCtrl.text = _normalizeTagsCsv((d['tags'] as List?)?.join(', ') ?? '');
        _contentCtrl.text = (d['contentMarkdown'] ?? '').toString();
        _authorCtrl.text = (d['author'] ?? 'BilgeAI').toString();
        final loc = (d['locale'] ?? 'tr').toString().trim().toLowerCase();
        _locale = (loc == 'tr' || loc == 'en') ? loc : 'tr';
        _isEditing = true;
        _originalSlug = slug;
      }
    } catch (_) {}
    finally { if (mounted) setState(() { _isLoadingExisting = false; }); }
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

  // Etiketleri normalize eden yardımcılar
  String _normalizeTagsCsv(String input) {
    // Köşeli parantezler ve tırnakları at, satır sonlarını boşluğa çevir
    var s = input.replaceAll(RegExp("[\\[\\]\\\"']"), ' ');
    s = s.replaceAll(RegExp(r"\s+"), ' ').trim();
    // Virgül ya da ' ve ' ile böl
    final parts = s.split(RegExp(r"\s*,\s*|\s+ve\s+", caseSensitive: false));
    final set = <String>{};
    for (var p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      set.add(t);
    }
    return set.join(', ');
  }

  List<String> _splitTagsToList(String input) {
    var s = input.replaceAll(RegExp("[\\[\\]\\\"']"), ' ');
    s = s.replaceAll(RegExp(r"\s+"), ' ').trim();
    final parts = s.split(RegExp(r"\s*,\s*|\s+ve\s+", caseSensitive: false));
    final set = <String>{};
    for (var p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      set.add(t);
    }
    return set.toList();
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
      final tags = _splitTagsToList(_tagsCtrl.text);

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

      await fs.collection('posts').doc(slug).set(data, SetOptions(merge: true));

      // Slug değiştiyse eskiyi sil
      if (_isEditing && _originalSlug != null && _originalSlug != slug) {
        await fs.collection('posts').doc(_originalSlug!).delete();
        _originalSlug = slug;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(publish ? (_isEditing ? 'Yazı güncellendi' : 'Yayınlandı') : 'Taslak kaydedildi')),
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

  Future<void> _importFromMarkdownFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md', 'markdown'],
        withData: true, // web desteği için
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) return;
      final content = utf8.decode(bytes);
      _applyImportedMarkdown(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dosya okunamadı: $e')));
      }
    }
  }

  Future<void> _importFromUrl() async {
    final urlCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Markdown URL\'si'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(hintText: 'https://.../yazi.md'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('İçe Aktar')),
        ],
      ),
    );
    if (confirmed != true) return;
    final url = urlCtrl.text.trim();
    if (url.isEmpty) return;
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        _applyImportedMarkdown(utf8.decode(resp.bodyBytes));
      } else {
        throw 'HTTP ${resp.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('URL okunamadı: $e')));
      }
    }
  }

  void _applyImportedMarkdown(String content) {
    // YAML front-matter varsa önce onu işle
    String body = content;
    if (content.trimLeft().startsWith('---')) {
      final lines = const LineSplitter().convert(content);
      int end = -1;
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') { end = i; break; }
      }
      if (end > 0) {
        final fmLines = lines.sublist(1, end);
        final rest = lines.sublist(end + 1).join('\n');
        final Map<String, String> kv = {};
        for (final l in fmLines) {
          final idx = l.indexOf(':');
          if (idx > 0) {
            final k = l.substring(0, idx).trim();
            final v = l.substring(idx + 1).trim();
            if (k.isNotEmpty) kv[k] = v;
          }
        }
        // Alanları doldur
        if (kv['title'] != null && kv['title']!.isNotEmpty) {
          _titleCtrl.text = kv['title']!;
          if (_slugCtrl.text.trim().isEmpty) {
            _slugCtrl.text = _toSlug(_titleCtrl.text);
          }
        }
        if (kv['slug'] != null && kv['slug']!.isNotEmpty) {
          _slugCtrl.text = kv['slug']!;
        }
        if (kv['excerpt'] != null) _excerptCtrl.text = kv['excerpt']!;
        if (kv['coverImageUrl'] != null) _coverUrlCtrl.text = kv['coverImageUrl']!;
        if (kv['tags'] != null) _tagsCtrl.text = _normalizeTagsCsv(kv['tags']!);
        if (kv['locale'] != null) {
          final loc = kv['locale']!.trim().toLowerCase();
          _locale = (loc == 'tr' || loc == 'en') ? loc : 'tr';
        }
        if (kv['author'] != null) _authorCtrl.text = kv['author']!;
        // status front-matter sadece önizleme için, kaydetmede zaten seçiyoruz
        body = rest;
      }
    }

    // Başlık ilk satırdan da alınabilir
    final lines = const LineSplitter().convert(body);
    if (_titleCtrl.text.trim().isEmpty && lines.isNotEmpty) {
      final l0 = lines.first.trim();
      final hMatch = RegExp(r'^#{1,6}\\s+(.+)$').firstMatch(l0);
      if (hMatch != null) {
        final title = hMatch.group(1)!.trim();
        _titleCtrl.text = title;
        if (_slugCtrl.text.trim().isEmpty) {
          _slugCtrl.text = _toSlug(title);
        }
      }
    }

    _contentCtrl.text = body;
    setState(() {});
  }

  Future<void> _goBack() async {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    if (_isEditing) {
      final slug = (_originalSlug ?? widget.initialSlug ?? _slugCtrl.text.trim());
      if (slug != null && slug.isNotEmpty) {
        context.go('/blog/$slug');
        return;
      }
    }
    context.go('/blog');
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(adminClaimProvider);

    return WillPopScope(
      onWillPop: () async {
        await _goBack();
        return false; // Navigasyonu biz yönetiyoruz
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Yazıyı Düzenle' : 'Yeni Blog Yazısı'),
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Geri',
            onPressed: _goBack,
          ),
        ),
        body: isAdminAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (isAdmin) {
            if (!isAdmin) {
              return const Center(child: Text('Erişim yok (admin gerekli).'));
            }
            if (_isLoadingExisting) {
              return const Center(child: CircularProgressIndicator());
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
                      // İçe aktarma kısa yolları
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _importFromMarkdownFile,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('MD Dosyası İçe Aktar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _importFromUrl,
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('URL\'den İçe Aktar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                        value: _safeLocale,
                        items: const [
                          DropdownMenuItem(value: 'tr', child: Text('Türkçe (tr)')),
                          DropdownMenuItem(value: 'en', child: Text('English (en)')),
                        ],
                        onChanged: (v) => setState(() => _locale = (v ?? 'tr')),
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
                              child: Text(_isEditing ? 'Taslağı Güncelle' : 'Taslak Kaydet'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : () => _save(publish: true),
                              child: Text(_isEditing ? 'Güncellemeyi Yayınla' : 'Hemen Yayınla'),
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
      ),
    );
  }
}
