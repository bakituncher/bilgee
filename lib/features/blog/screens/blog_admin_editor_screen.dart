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
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final _authorCtrl = TextEditingController(text: 'TaktikAI');
  String _locale = 'tr';
  // Güvenli locale: yalnızca 'tr' veya 'en'
  String? get _safeLocale {
    final v = _locale.trim().toLowerCase();
    return (v == 'tr' || v == 'en') ? v : null;
  }
  // Hedef kitle: 'all' | 'yks' | 'lgs' | 'kpss'
  String _targetExam = 'all';
  bool _isSaving = false;
  bool _isEditing = false;
  String? _originalSlug;
  bool _isLoadingExisting = false;
  bool _isUploadingCover = false;
  bool _previewMode = false;
  // Yayın süresi
  String _expiryType = 'forever'; // 'forever' | '1d' | '7d' | '30d'
  DateTime? _expireAt; // sadece bilgi amaçlı, publish anında hesaplanır

  Future<void> _showImportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) {
        Widget option({required IconData icon, required String title, required String desc, required VoidCallback onTap}) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .35))),
            child: ListTile(
              leading: Icon(icon, color: AppTheme.secondaryColor),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(desc, style: TextStyle(color: AppTheme.secondaryTextColor)),
              onTap: () { Navigator.of(c).pop(); onTap(); },
            ),
          );
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppTheme.lightSurfaceColor.withValues(alpha: .6), borderRadius: BorderRadius.circular(2)))),
                Text('İçe Aktar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                option(
                  icon: Icons.upload_file_rounded,
                  title: 'Markdown Dosyası (.md)',
                  desc: 'Bilgisayarından bir markdown dosyası seç ve yükle',
                  onTap: _importFromMarkdownFile,
                ),
                option(
                  icon: Icons.link_rounded,
                  title: 'URL’den İçe Aktar',
                  desc: 'Bir markdown içeriğini URL ile içe aktar',
                  onTap: _importFromUrl,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
        _authorCtrl.text = (d['author'] ?? 'TaktikAI').toString();
        final loc = (d['locale'] ?? 'tr').toString().trim().toLowerCase();
        _locale = (loc == 'tr' || loc == 'en') ? loc : 'tr';
        // Hedef kitleyi oku
        final t = (d['targetExams'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? const ['all'];
        if (t.contains('all')) _targetExam = 'all';
        else if (t.contains('yks')) _targetExam = 'yks';
        else if (t.contains('lgs')) _targetExam = 'lgs';
        else if (t.any((e) => e.startsWith('kpss'))) _targetExam = 'kpss';
        _isEditing = true;
        _originalSlug = slug;
        // Yayın süresi alanları
        final et = (d['expiryType'] ?? 'forever').toString();
        if (['forever','1d','7d','30d'].contains(et)) {
          _expiryType = et;
        } else {
          _expiryType = 'forever';
        }
        _expireAt = (d['expireAt'] is Timestamp) ? (d['expireAt'] as Timestamp).toDate() : null;
      }
    } catch (_) {}
    finally { if (mounted) setState(() { _isLoadingExisting = false; }); }
  }

  DateTime? _calcExpireAt(DateTime base, String type) {
    switch (type) {
      case '1d':
        return base.add(const Duration(days: 1));
      case '7d':
        return base.add(const Duration(days: 7));
      case '30d':
        return DateTime(base.year, base.month + 1, base.day, base.hour, base.minute, base.second, base.millisecond, base.microsecond);
      case 'forever':
      default:
        return null;
    }
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
      final target = _targetExam.trim().toLowerCase();
      final targetArray = target == 'all' ? ['all'] : [target];

      // Yayın süresi hesapla (yalnızca publish ediliyorsa expireAt belirle)
      DateTime? expireAt;
      String expiryType = _expiryType;
      if (publish) {
        expireAt = _calcExpireAt(now, expiryType);
      } else {
        // taslakta expireAt yazmayalım; sadece seçimi saklayalım
        expireAt = null;
        expiryType = _expiryType;
      }

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
        'author': _authorCtrl.text.trim().isEmpty ? 'TaktikAI' : _authorCtrl.text.trim(),
        'readTime': readTime,
        'targetExams': targetArray,
        'expiryType': expiryType,
        'expireAt': publish ? (expireAt != null ? Timestamp.fromDate(expireAt) : null) : FieldValue.delete(),
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
        // Hedef kitle front-matter: target veya targetExams: all|yks|lgs|kpss
        final tgt = (kv['target'] ?? kv['targetExams']);
        if (tgt != null) {
          final v = tgt.toString().trim().toLowerCase();
          if (['all','yks','lgs','kpss'].contains(v)) {
            _targetExam = v;
          }
        }
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
      if (slug.isNotEmpty) {
        context.go('/blog/$slug');
        return;
      }
    }
    context.go('/blog');
  }

  Future<void> _pickAndUploadCoverImage() async {
    try {
      setState(() => _isUploadingCover = true);

      // Auth token’ı (custom claims dahil) yenile ki Storage kurallarındaki admin kontrolü hemen geçerli olsun
      try { await FirebaseAuth.instance.currentUser?.getIdToken(true); } catch (_) {}

      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) return;

      String name = (f.name.isNotEmpty ? f.name : 'cover');
      String ext = '';
      final dot = name.lastIndexOf('.');
      if (dot != -1 && dot < name.length - 1) {
        ext = name.substring(dot + 1).toLowerCase();
      }
      if (!['jpg','jpeg','png','webp'].contains(ext)) {
        ext = 'jpg';
      }
      String contentType = 'image/jpeg';
      if (ext == 'png') contentType = 'image/png';
      if (ext == 'webp') contentType = 'image/webp';

      final title = _titleCtrl.text.trim();
      final slug = (_slugCtrl.text.trim().isEmpty
          ? (_toSlug(title).isEmpty ? 'post' : _toSlug(title))
          : _slugCtrl.text.trim());
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'blog_covers/$slug/$ts.$ext';

      final ref = FirebaseStorage.instance.ref(path);
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await task.ref.getDownloadURL();
      _coverUrlCtrl.text = url;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel yüklendi ve URL alanına eklendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görsel yüklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<bool> _pickTargetExamSheet() async {
    String temp = _targetExam;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: StatefulBuilder(
              builder: (c, setStateSheet) {
                Widget option(String value, String label, IconData icon) {
                  final selected = temp == value;
                  return Card(
                    color: selected ? AppTheme.lightSurfaceColor.withValues(alpha: .18) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? AppTheme.secondaryColor : AppTheme.lightSurfaceColor.withValues(alpha: .4))),
                    child: ListTile(
                      leading: Icon(icon, color: selected ? AppTheme.secondaryColor : AppTheme.secondaryTextColor),
                      title: Text(label),
                      trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryColor) : null,
                      onTap: () => setStateSheet(() => temp = value),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppTheme.lightSurfaceColor.withValues(alpha: .6), borderRadius: BorderRadius.circular(2)))),
                    Text('Hangi gruba göndermek istersiniz?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Seçiminize göre yazı ilgili öğrencilerin akışına düşer.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
                    const SizedBox(height: 12),
                    option('all', 'Hepsi', Icons.public_rounded),
                    option('yks', 'YKS', Icons.school_rounded),
                    option('lgs', 'LGS', Icons.auto_stories_rounded),
                    option('kpss', 'KPSS', Icons.workspace_premium_rounded),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(c).pop(temp),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Onayla ve Yayınla'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    if (result == null) return false;
    setState(() => _targetExam = result);
    return true;
  }

  void _wrapSelection({String before = '', String after = ''}) {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final selected = start <= end ? text.substring(start, end) : '';
    final newText = text.replaceRange(start, end, '$before$selected$after');
    final newPos = start + before.length + selected.length + after.length;
    _contentCtrl.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newPos));
    setState(() {});
  }

  void _insertLinePrefix(String prefix) {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    final pos = (sel.start < 0 ? text.length : sel.start).clamp(0, text.length);
    int lineStart = text.lastIndexOf('\n', pos - 1);
    if (lineStart == -1) lineStart = 0; else lineStart += 1;
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    _contentCtrl.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: pos + prefix.length));
    setState(() {});
  }

  Widget _buildFormatToolbar() {
    final btnStyle = IconButton.styleFrom(visualDensity: VisualDensity.compact);
    return Wrap(
      spacing: 4,
      runSpacing: -8,
      children: [
        IconButton(tooltip: 'Başlık 1', style: btnStyle, onPressed: () => _insertLinePrefix('# '), icon: const Icon(Icons.title_rounded)),
        IconButton(tooltip: 'Başlık 2', style: btnStyle, onPressed: () => _insertLinePrefix('## '), icon: const Icon(Icons.text_fields_rounded)),
        IconButton(tooltip: 'Kalın', style: btnStyle, onPressed: () => _wrapSelection(before: '**', after: '**'), icon: const Icon(Icons.format_bold_rounded)),
        IconButton(tooltip: 'İtalik', style: btnStyle, onPressed: () => _wrapSelection(before: '*', after: '*'), icon: const Icon(Icons.format_italic_rounded)),
        IconButton(tooltip: 'Bağlantı', style: btnStyle, onPressed: () => _wrapSelection(before: '[', after: '](https://)'), icon: const Icon(Icons.link_rounded)),
        IconButton(tooltip: 'Liste', style: btnStyle, onPressed: () => _insertLinePrefix('- '), icon: const Icon(Icons.format_list_bulleted_rounded)),
        IconButton(tooltip: 'Alıntı', style: btnStyle, onPressed: () => _insertLinePrefix('> '), icon: const Icon(Icons.format_quote_rounded)),
        IconButton(tooltip: 'Kod', style: btnStyle, onPressed: () => _wrapSelection(before: '`', after: '`'), icon: const Icon(Icons.code_rounded)),
        // Hızlı: Markdown dosyası içe aktar
        IconButton(tooltip: 'MD Dosyası İçe Aktar', style: btnStyle, onPressed: _importFromMarkdownFile, icon: const Icon(Icons.upload_rounded)),
      ],
    );
  }

  Widget _buildPreview() {
    final title = _titleCtrl.text.trim();
    final cover = _coverUrlCtrl.text.trim();
    final tags = _splitTagsToList(_tagsCtrl.text);
    final readTime = _estimateReadTime(_contentCtrl.text);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16/9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.lightSurfaceColor.withValues(alpha: .2), child: const Center(child: Icon(Icons.image_not_supported_rounded))))
                  ),
                ),
              const SizedBox(height: 12),
              Text(title.isEmpty ? 'Başlık (önizleme)' : title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.secondaryTextColor),
                const SizedBox(width: 6),
                Text(_authorCtrl.text.trim().isEmpty ? 'TaktikAI' : _authorCtrl.text.trim(), style: TextStyle(color: AppTheme.secondaryTextColor)),
                const SizedBox(width: 12),
                const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.secondaryTextColor),
                const SizedBox(width: 6),
                Text('$readTime dk', style: TextStyle(color: AppTheme.secondaryTextColor)),
              ]),
              const SizedBox(height: 10),
              if (tags.isNotEmpty)
                Wrap(spacing: 8, runSpacing: -6, children: tags.map((t) => Chip(label: Text(t), backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: .25))).toList()),
              const SizedBox(height: 12),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 96),
            child: MarkdownBody(
              data: _contentCtrl.text,
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.montserrat(fontSize: 16, height: 1.65, letterSpacing: .05, color: AppTheme.textColor),
                h1: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, height: 1.25),
                h2: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
                h3: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, height: 1.35),
                h4: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
                h1Padding: const EdgeInsets.only(top: 18, bottom: 8),
                h2Padding: const EdgeInsets.only(top: 16, bottom: 8),
                h3Padding: const EdgeInsets.only(top: 14, bottom: 6),
                h4Padding: const EdgeInsets.only(top: 12, bottom: 6),
                code: GoogleFonts.robotoMono(fontSize: 13.5, height: 1.5, color: AppTheme.textColor),
                codeblockPadding: const EdgeInsets.all(12),
                codeblockDecoration: BoxDecoration(
                  color: AppTheme.lightSurfaceColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .3)),
                ),
                blockquote: GoogleFonts.montserrat(fontStyle: FontStyle.italic, color: AppTheme.secondaryTextColor),
                blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                blockquoteDecoration: BoxDecoration(
                  color: AppTheme.lightSurfaceColor.withValues(alpha: .08),
                  border: Border(left: BorderSide(color: AppTheme.secondaryColor, width: 3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                listBullet: TextStyle(color: AppTheme.secondaryColor),
                a: const TextStyle(color: Color(0xFF55C1FF), fontWeight: FontWeight.w600),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .6), width: 1)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(adminClaimProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _goBack();
        }
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
          actions: [
            IconButton(
              tooltip: 'İçe aktar',
              icon: const Icon(Icons.file_open_rounded),
              onPressed: _showImportSheet,
            ),
            IconButton(
              tooltip: _previewMode ? 'Düzenlemeye geç' : 'Önizleme',
              icon: Icon(_previewMode ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => setState(() => _previewMode = !_previewMode),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .4))),
            ),
            child: Row(
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
                    onPressed: _isSaving ? null : () async {
                      final ok = await _pickTargetExamSheet();
                      if (!ok) return;
                      await _save(publish: true);
                    },
                    child: Text(_isEditing ? 'Güncellemeyi Yayınla' : 'Hemen Yayınla'),
                  ),
                ),
              ],
            ),
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
            if (_previewMode) {
              return _buildPreview();
            }
            return AbsorbPointer(
              absorbing: _isSaving,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Başlık ve Kapak', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(labelText: 'Başlık', hintText: 'Örn: Motivasyonu Nasıl Korurum?'),
                        onChanged: (v) {
                          if (_slugCtrl.text.trim().isEmpty) {
                            _slugCtrl.text = _toSlug(v);
                          }
                          setState(() {});
                        },
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                        maxLength: 120,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _slugCtrl,
                        decoration: const InputDecoration(labelText: 'Slug (url-dostu)', hintText: 'otomatik oluşur, gerekirse düzenleyin'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _excerptCtrl,
                        decoration: const InputDecoration(labelText: 'Özet (excerpt)', hintText: 'Liste ve paylaşımlarda görünecek kısa açıklama'),
                        maxLines: 2,
                        maxLength: 220,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _coverUrlCtrl,
                        decoration: const InputDecoration(labelText: 'Kapak Görseli URL (opsiyonel)'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isUploadingCover ? null : _pickAndUploadCoverImage,
                            icon: const Icon(Icons.image_rounded),
                            label: const Text('Fotoğraf Yükle'),
                          ),
                          const SizedBox(width: 12),
                          if (_isUploadingCover) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_coverUrlCtrl.text.trim().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _coverUrlCtrl.text.trim(),
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(height: 140, child: Center(child: Text('Önizleme yüklenemedi'))),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text('Etiketler ve Dil', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _tagsCtrl,
                        decoration: const InputDecoration(labelText: 'Etiketler (virgülle)', hintText: 'Örn: motivasyon, planlama, strateji'),
                      ),
                      const SizedBox(height: 8),
                      if (_tagsCtrl.text.trim().isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children: _splitTagsToList(_tagsCtrl.text).map((t) => Chip(label: Text(t), visualDensity: VisualDensity.compact)).toList(),
                        ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _safeLocale,
                        items: const [
                          DropdownMenuItem(value: 'tr', child: Text('Türkçe (tr)')),
                          DropdownMenuItem(value: 'en', child: Text('English (en)')),
                        ],
                        onChanged: (v) => setState(() => _locale = (v ?? 'tr')),
                        decoration: const InputDecoration(labelText: 'Dil'),
                      ),
                      const SizedBox(height: 16),
                      Text('Yayın Süresi', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _expiryType,
                        items: const [
                          DropdownMenuItem(value: 'forever', child: Text('Süresiz')),
                          DropdownMenuItem(value: '1d', child: Text('1 Gün')),
                          DropdownMenuItem(value: '7d', child: Text('1 Hafta')),
                          DropdownMenuItem(value: '30d', child: Text('1 Ay')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _expiryType = v ?? 'forever';
                            _expireAt = _calcExpireAt(DateTime.now(), _expiryType);
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Süre'),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final info = _expiryType == 'forever'
                              ? 'Bu yazı süresiz yayında kalır.'
                              : 'Tahmini bitiş: ${_calcExpireAt(DateTime.now(), _expiryType)?.toLocal()}';
                          return Row(children: [
                            const Icon(Icons.info_outline_rounded, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(info, style: TextStyle(color: AppTheme.secondaryTextColor))),
                          ]);
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('İçerik', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      _buildFormatToolbar(),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _contentCtrl,
                        decoration: const InputDecoration(labelText: 'İçerik (Markdown)', hintText: 'Markdown destekli içerik'),
                        minLines: 10,
                        maxLines: 24,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.secondaryTextColor),
                          const SizedBox(width: 6),
                          Text('Tahmini okuma süresi: ${_estimateReadTime(_contentCtrl.text)} dk'),
                        ],
                      ),
                      const SizedBox(height: 120), // alt çubuk için boşluk
                      // Kaldırıldı: Eski butonlar (artık alt eylem çubuğunda)
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
