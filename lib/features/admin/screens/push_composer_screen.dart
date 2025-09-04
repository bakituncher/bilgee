import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PushComposerScreen extends StatefulWidget {
  const PushComposerScreen({super.key});

  @override
  State<PushComposerScreen> createState() => _PushComposerScreenState();
}

class _PushComposerScreenState extends State<PushComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _routeCtrl = TextEditingController(text: '/home');
  final _uidsCtrl = TextEditingController();
  final _inactiveHoursCtrl = TextEditingController(text: '24');

  // Basit mod: sadece formu göster (önizleme + geçmiş gizli)
  bool _simpleMode = true;

  String _audience = 'all'; // all | exam | uids | inactive
  String? _examType; // e.g., YKS, LGS, KPSS
  // Çoklu sınav seçimi
  final List<String> _examOptions = const ['YKS','KPSS','LGS'];
  final Set<String> _selectedExams = {};
  String? _imageUrl;
  bool _sending = false;
  double _uploadProgress = 0;

  bool _scheduleEnabled = false;
  DateTime? _scheduledAt;

  int? _estimateUsers;
  int? _estimateTokenHolders;

  // Bildirim şablonları
  final List<Map<String, String>> _templates = const [
    {
      'name': 'Geri Dönüş',
      'title': 'Geri dön ve hızını yakala! 💪',
      'body': 'Bugün 10 dakikalık mini görevle açılış yapmaya ne dersin? 🎯',
      'route': '/home/quests',
    },
    {
      'name': 'Yeni Özellik',
      'title': 'Yepyeni özellik yayında! ✨',
      'body': 'Senin için tasarladık. Hemen keşfet ve ilk deneyenlerden ol!',
      'route': '/premium',
    },
    {
      'name': 'Hatırlatma',
      'title': 'Hedefine bir adım daha! ⚡',
      'body': 'Kısa bir pratikle ivme yakala. Bugünü verimli kapat! 🚀',
      'route': '/home/add-test',
    },
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _routeCtrl.dispose();
    _uidsCtrl.dispose();
    _inactiveHoursCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Global setState listener kullanmayalım; önizleme için lokal dinleyiciler kullanılacak
  }

  Future<void> _pickAndUploadImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;
    final file = File(path);
    final now = DateTime.now();
    final y = DateFormat('yyyy').format(now);
    final m = DateFormat('MM').format(now);
    final name = '${now.millisecondsSinceEpoch}_${res.files.first.name}';
    final ref = FirebaseStorage.instance.ref('push_banners/$y/$m/$name');
    setState(() { _uploadProgress = 0; });
    final task = ref.putFile(file, SettableMetadata(contentType: _guessContentType(name)));
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) {
        setState(() { _uploadProgress = s.bytesTransferred / s.totalBytes; });
      }
    });
    final snap = await task.whenComplete(() {});
    final url = await snap.ref.getDownloadURL();
    setState(() { _imageUrl = url; _uploadProgress = 1; });
  }

  String _guessContentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Map<String, dynamic> _buildAudience() {
    if (_audience == 'exam') {
      // Çoklu seçim varsa 'exams' gönder; yoksa tekli fallback
      if (_selectedExams.isNotEmpty) {
        return {'type': 'exams', 'exams': _selectedExams.toList()};
      }
      return {'type': 'exam', 'examType': _examType ?? 'YKS'};
    }
    if (_audience == 'uids') {
      final raw = _uidsCtrl.text.trim();
      final ids = raw.split(RegExp(r'[\s,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      return {'type': 'uids', 'uids': ids};
    }
    if (_audience == 'inactive') {
      final hrs = int.tryParse(_inactiveHoursCtrl.text.trim());
      return {'type': 'inactive', 'hours': (hrs == null || hrs < 1) ? 24 : hrs};
    }
    return {'type': 'all'};
  }

  Future<void> _estimate() async {
    setState(() { _estimateUsers = null; _estimateTokenHolders = null; });
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('adminEstimateAudience');
      final res = await callable.call({'audience': _buildAudience()});
      final m = (res.data as Map?) ?? {};
      setState(() {
        _estimateUsers = (m['users'] as num?)?.toInt();
        _estimateTokenHolders = (m['tokenHolders'] as num?)?.toInt();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tahmin hatası: $e')));
    }
  }

  Future<void> _send({bool testToSelf = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _sending = true; });
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('adminSendPush');
      Map<String, dynamic> audience = _buildAudience();
      if (testToSelf) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) audience = {'type': 'uids', 'uids': [uid]};
      }
      final data = {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'route': _routeCtrl.text.trim().isEmpty ? '/home' : _routeCtrl.text.trim(),
        if (_imageUrl != null) 'imageUrl': _imageUrl,
        'audience': audience,
        if (_scheduleEnabled && _scheduledAt != null) 'scheduledAt': _scheduledAt!.millisecondsSinceEpoch,
      };
      final res = await callable.call(data);
      if (!mounted) return;
      final m = res.data as Map? ?? {};
      final scheduled = m['scheduled'] == true;
      final total = m['totalUsers'];
      final sent = m['totalSent'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(scheduled ? 'Planlandı' : 'Gönderildi: ${sent ?? '-'} / ${total ?? '-'}'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() { _sending = false; });
    }
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = _templates[i];
              return ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text(t['name'] ?? 'Şablon'),
                subtitle: Text('${t['title']}\n${t['body']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _titleCtrl.text = t['title'] ?? _titleCtrl.text;
                    _bodyCtrl.text = t['body'] ?? _bodyCtrl.text;
                    _routeCtrl.text = t['route'] ?? _routeCtrl.text;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = adminClaimProvider;
    return Consumer(
      builder: (context, ref, _) {
        final isAdmin = ref.watch(isAdminAsync).value ?? false;
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Bildirim Gönder')),
            body: const Center(child: Text('Bu sayfayı görüntülemek için yetkiniz yok.')),
          );
        }
        final width = MediaQuery.of(context).size.width;
        final isWide = width >= 900;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        // Adım bazlı içerik
        final stepContent = _buildStepContent();

        final content = isWide && !_simpleMode
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: stepContent),
                  const SizedBox(width: 16),
                  SizedBox(width: 380, child: _buildRightColumn(isWide: true)),
                ],
              )
            : SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 24 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mobil ve basit mod: son adımda önizlemeyi ayrıca göster
                    if (_currentStep == _lastStep) _inlinePreview(),
                    if (_currentStep == _lastStep) const SizedBox(height: 16),
                    stepContent,
                  ],
                ),
              );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bildirim Gönder'),
            actions: [
              IconButton(
                tooltip: _simpleMode ? 'Detaylı görünüm' : 'Basit görünüm',
                onPressed: () => setState(() => _simpleMode = !_simpleMode),
                icon: Icon(_simpleMode ? Icons.dashboard_customize_rounded : Icons.view_agenda_rounded),
              ),
            ],
          ),
          resizeToAvoidBottomInset: true,
          floatingActionButton: null,
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: content,
              ),
            ),
          ),
          bottomNavigationBar: _bottomActionBar(),
        );
      },
    );
  }

  // Adım akışı
  int _currentStep = 0;
  int get _lastStep => 5;

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _stepCard(title: 'Başlık', icon: Icons.title_rounded, child: _titleField(autofocus: true));
      case 1:
        return _stepCard(title: 'Açıklama', icon: Icons.notes_rounded, child: _bodyField(autofocus: true));
      case 2:
        return _stepCard(
          title: 'Hedef & Görsel',
          icon: Icons.link_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _routeField(),
              const SizedBox(height: 8),
              _quickRouteChips(),
              const SizedBox(height: 12),
              _imagePickerRow(),
              if (_uploadProgress > 0 && _uploadProgress < 1)
                Padding(padding: const EdgeInsets.only(top: 8.0), child: LinearProgressIndicator(value: _uploadProgress)),
            ],
          ),
        );
      case 3:
        return _stepCard(
          title: 'Kitle',
          icon: Icons.groups_3_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _audienceSection(),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _sending ? null : _estimate,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Kitleyi Tahmin Et'),
              ),
              if (_estimateUsers != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Tahmini kullanıcı: ${_estimateUsers ?? '-'} • Token sahibi: ${_estimateTokenHolders ?? '-'}'),
                ),
            ],
          ),
        );
      case 4:
        return _stepCard(title: 'Zamanlama', icon: Icons.schedule_rounded, child: _scheduleSection());
      default:
        return _stepCard(
          title: 'Önizleme',
          icon: Icons.remove_red_eye_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _inlinePreview(),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.groups_rounded, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(_audienceSummary())),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(_scheduleEnabled && _scheduledAt != null
                    ? 'Planlı: ${DateFormat('dd.MM.yyyy HH:mm').format(_scheduledAt!)}'
                    : 'Anında gönderim')),
              ]),
            ],
          ),
        );
    }
  }

  Widget _stepCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700))]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _titleField({bool autofocus = false}) {
    return TextFormField(
      controller: _titleCtrl,
      autofocus: autofocus,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Başlık',
        helperText: 'Kısa ve net bir çağrı (≤ 60 karakter).',
        counterText: '',
        prefixIcon: const Icon(Icons.title_rounded),
        suffixIcon: _titleCtrl.text.isEmpty
            ? IconButton(tooltip: 'Şablonlar', icon: const Icon(Icons.auto_awesome_rounded), onPressed: _showTemplatePicker)
            : IconButton(tooltip: 'Temizle', icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _titleCtrl.clear())),
      ),
      maxLength: 60,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Başlık gerekli' : null,
    );
  }

  Widget _bodyField({bool autofocus = false}) {
    return TextFormField(
      controller: _bodyCtrl,
      autofocus: autofocus,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: 'Açıklama',
        helperText: 'Kısa fayda + eylem çağrısı (≤ 160 karakter).',
        counterText: '',
        prefixIcon: const Icon(Icons.notes_rounded),
        suffixIcon: _bodyCtrl.text.isEmpty
            ? IconButton(tooltip: 'Şablonlar', icon: const Icon(Icons.auto_awesome_rounded), onPressed: _showTemplatePicker)
            : IconButton(tooltip: 'Temizle', icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _bodyCtrl.clear())),
      ),
      maxLength: 160,
      maxLines: 3,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Açıklama gerekli' : null,
    );
  }

  String _audienceSummary() {
    switch (_audience) {
      case 'exam':
        if (_selectedExams.isNotEmpty) return 'Kitle: ${_selectedExams.join(', ')}';
        return 'Kitle: ${_examType ?? 'YKS'}';
      case 'uids':
        final n = _uidsCtrl.text.trim().split(RegExp(r'[\s,;]+')).where((e) => e.isNotEmpty).length;
        return 'Kitle: UID listesi (${n})';
      case 'inactive':
        final hrs = int.tryParse(_inactiveHoursCtrl.text.trim()) ?? 24;
        return 'Kitle: Son ${hrs} saattir inaktif';
      default:
        return 'Kitle: Tümü';
    }
  }

  bool _validateStep(int s) {
    if (s == 0) return _titleCtrl.text.trim().isNotEmpty;
    if (s == 1) return _bodyCtrl.text.trim().isNotEmpty;
    if (s == 2) return _routeCtrl.text.trim().isNotEmpty;
    if (s == 3) {
      if (_audience == 'uids' && _uidsCtrl.text.trim().isEmpty) return false;
      if (_audience == 'inactive' && int.tryParse(_inactiveHoursCtrl.text.trim()) == null) return false;
      return true;
    }
    return true;
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) { setState(() {}); return; }
    if (_currentStep < _lastStep) setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // Alt eylem çubuğu – adım kontrollü
  @override
  Widget _bottomActionBar() {
    final uploading = _uploadProgress > 0 && _uploadProgress < 1;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isLast = _currentStep == _lastStep;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        elevation: 6,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 420;
                final mainAction = FilledButton.icon(
                  onPressed: (_sending || uploading)
                      ? null
                      : () {
                          if (!isLast) { _nextStep(); return; }
                          if (!_formKey.currentState!.validate()) return;
                          _send();
                        },
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(isLast ? (_scheduleEnabled ? Icons.event_available_rounded : Icons.send_rounded) : Icons.arrow_forward_rounded),
                  label: Text(isLast ? (_scheduleEnabled ? 'Planla' : 'Gönder') : 'Devam'),
                );

                final children = <Widget>[
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: (_sending || uploading) ? null : _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Geri'),
                    ),
                  if (_currentStep > 0 && !narrow) const SizedBox(width: 8),
                  const Spacer(),
                  if (isLast)
                    TextButton.icon(
                      onPressed: (_sending || uploading) ? null : () => _send(testToSelf: true),
                      icon: const Icon(Icons.person_outline_rounded),
                      label: const Text('Kendime Test'),
                    ),
                  if (!narrow) const SizedBox(width: 8),
                  mainAction,
                ];

                if (narrow) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_currentStep > 0)
                        OutlinedButton.icon(
                          onPressed: (_sending || uploading) ? null : _prevStep,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Geri'),
                        ),
                      if (isLast)
                        TextButton.icon(
                          onPressed: (_sending || uploading) ? null : () => _send(testToSelf: true),
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('Kendime Test'),
                        ),
                      mainAction,
                    ],
                  );
                }
                return Row(children: children);
              },
            ),
          ),
        ),
      ),
    );
  }

  // Inline önizleme kartı (basit mod için)
  Widget _inlinePreview() {
    final listenable = Listenable.merge([_titleCtrl, _bodyCtrl, _routeCtrl]);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final title = _titleCtrl.text.isEmpty ? 'Önizleme Başlık' : _titleCtrl.text;
          final body = _bodyCtrl.text.isEmpty ? 'Önizleme metni burada görünecek.' : _bodyCtrl.text;
          final route = _routeCtrl.text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_imageUrl != null)
                AspectRatio(aspectRatio: 16/9, child: Image.network(_imageUrl!, fit: BoxFit.cover)),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(body),
                    const SizedBox(height: 8),
                    Row(children: [const Icon(Icons.link_rounded, size: 16), const SizedBox(width: 6), Flexible(child: Text(route))]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Yardımcı alanlar
  Widget _routeField() {
    final routes = <String>['/home','/home/quests','/home/pomodoro','/home/add-test','/stats/overview','/premium','/blog'];
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _routeCtrl,
            decoration: const InputDecoration(labelText: 'Hedef Rota', prefixIcon: Icon(Icons.link_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Rota gerekli' : null,
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'Öneriler',
          onSelected: (r) => setState(() => _routeCtrl.text = r),
          itemBuilder: (c) => routes.map((r) => PopupMenuItem(value: r, child: Text(r))).toList(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Icon(Icons.list_alt_rounded),
          ),
        ),
      ],
    );
  }

  Widget _quickRouteChips() {
    final routes = <Map<String, String>>[
      {'label': 'Ana Sayfa', 'path': '/home'},
      {'label': 'Görevler', 'path': '/home/quests'},
      {'label': 'Pomodoro', 'path': '/home/pomodoro'},
      {'label': 'Deneme Ekle', 'path': '/home/add-test'},
      {'label': 'İstatistik', 'path': '/stats/overview'},
      {'label': 'Premium', 'path': '/premium'},
      {'label': 'Blog', 'path': '/blog'},
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in routes)
          ActionChip(
            label: Text(r['label']!),
            onPressed: () => setState(() => _routeCtrl.text = r['path']!),
          ),
      ],
    );
  }

  // Görsel satırını Wrap ile responsive yap
  Widget _imagePickerRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _imageUrl == null ? 'Görsel ekle (opsiyonel)' : 'Görsel yüklendi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
        OutlinedButton.icon(
          onPressed: _sending ? null : _pickAndUploadImage,
          icon: const Icon(Icons.image_rounded),
          label: const Text('Görsel Seç & Yükle'),
        ),
        if (_imageUrl != null)
          TextButton.icon(
            onPressed: _sending ? null : () => setState(() => _imageUrl = null),
            icon: const Icon(Icons.clear_rounded),
            label: const Text('Kaldır'),
          ),
      ],
    );
  }

  Widget _audienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(label: const Text('Tümü'), selected: _audience == 'all', onSelected: (_) => setState(() => _audience = 'all')),
            ChoiceChip(label: const Text('Sınava göre'), selected: _audience == 'exam', onSelected: (_) => setState(() => _audience = 'exam')),
            ChoiceChip(label: const Text('UID listesi'), selected: _audience == 'uids', onSelected: (_) => setState(() => _audience = 'uids')),
            ChoiceChip(label: const Text('İnaktif (saat)'), selected: _audience == 'inactive', onSelected: (_) => setState(() => _audience = 'inactive')),
          ],
        ),
        const SizedBox(height: 8),
        if (_audience == 'exam')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sınavlar (birden çok seçilebilir)'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ex in _examOptions)
                    FilterChip(
                      label: Text(ex),
                      selected: _selectedExams.contains(ex),
                      onSelected: (val) {
                        setState(() {
                          if (val) { _selectedExams.add(ex); } else { _selectedExams.remove(ex); }
                          if (_selectedExams.isEmpty && _examType == null) { _examType = 'YKS'; }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() { _selectedExams
                      ..clear()
                      ..addAll(_examOptions); }),
                    child: const Text('Hepsini Seç'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() { _selectedExams.clear(); }),
                    child: const Text('Temizle'),
                  ),
                ],
              ),
            ],
          ),
        if (_audience == 'uids')
          TextFormField(
            controller: _uidsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı UID’leri (virgül veya boşluk ile ayırın)',
              prefixIcon: Icon(Icons.group_rounded),
            ),
            validator: (v) {
              if (_audience != 'uids') return null;
              final raw = v?.trim() ?? '';
              if (raw.isEmpty) return 'En az 1 UID giriniz';
              return null;
            },
          ),
        if (_audience == 'inactive')
          TextFormField(
            controller: _inactiveHoursCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Son kaç saattir inaktif? (örn. 24)'),
            validator: (v) {
              if (_audience != 'inactive') return null;
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1) return 'Geçerli saat değeri giriniz';
              return null;
            },
          ),
      ],
    );
  }

  // Tarih & saat seçimini Wrap + LayoutBuilder ile responsive hale getir
  Widget _scheduleSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final label = _scheduleEnabled && _scheduledAt != null
            ? DateFormat(isNarrow ? 'dd.MM HH:mm' : 'dd.MM.yyyy HH:mm').format(_scheduledAt!)
            : 'Tarih & saat seç';
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Switch(
              value: _scheduleEnabled,
              onChanged: (v) => setState(() { _scheduleEnabled = v; if (!v) _scheduledAt = null; }),
            ),
            const Text('Planlı gönder'),
            if (_scheduleEnabled)
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now().add(const Duration(minutes: 5));
                  final date = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: now.hour, minute: now.minute));
                  if (time == null) return;
                  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  setState(() { _scheduledAt = dt; });
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRightColumn({required bool isWide}) {
    final listenable = Listenable.merge([_titleCtrl, _bodyCtrl, _routeCtrl]);
    return Column(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: listenable,
            builder: (context, _) {
              final title = _titleCtrl.text.isEmpty ? 'Önizleme Başlık' : _titleCtrl.text;
              final body = _bodyCtrl.text.isEmpty ? 'Önizleme metni burada görünecek.' : _bodyCtrl.text;
              final route = _routeCtrl.text;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_imageUrl != null)
                    AspectRatio(aspectRatio: 16/9, child: Image.network(_imageUrl!, fit: BoxFit.cover)),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(body),
                        const SizedBox(height: 8),
                        Row(children: [const Icon(Icons.link_rounded, size: 16), const SizedBox(width: 6), Flexible(child: Text(route))]),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Son kampanyalar: geniş ekranda Expanded, dar ekranda sabit yüksekliğe sığdır
        if (isWide)
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(title: Text('Son Kampanyalar')),
                  const Divider(height: 1),
                  Expanded(child: _campaignHistory()),
                ],
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(title: Text('Son Kampanyalar')),
                  const Divider(height: 1),
                  Expanded(child: _campaignHistory()),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _campaignHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('push_campaigns')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('Kayıt yok'));
        }
        final docs = snap.data!.docs;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final status = (d['status'] ?? '').toString();
            final title = (d['title'] ?? '').toString();
            final createdAt = (d['createdAt'] as Timestamp?);
            final info = (d['totalSent'] != null && d['totalUsers'] != null)
                ? ' ${d['totalSent']}/${d['totalUsers']}'
                : '';
            return ListTile(
              dense: true,
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${createdAt != null ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate()) : ''} • $status$info'),
            );
          },
        );
      },
    );
  }
}
