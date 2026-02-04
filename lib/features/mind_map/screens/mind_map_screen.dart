// lib/features/mind_map/screens/mind_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Zihin haritası adımları
enum MindMapStep {
  input,      // Kullanıcıdan konu ve detay alma
  generating, // AI ile zihin haritası oluşturma
  result,     // Sonucu gösterme
}

// Zihin haritası state'i
final mindMapStepProvider = StateProvider<MindMapStep>((ref) => MindMapStep.input);
final mindMapTopicProvider = StateProvider<String>((ref) => '');
final mindMapDetailsProvider = StateProvider<String>((ref) => '');
final mindMapResultProvider = StateProvider<MindMapResult?>((ref) => null);

// Zihin haritası sonuç modeli
class MindMapResult {
  final String topic;
  final String mainConcept;
  final List<MindMapBranch> branches;

  MindMapResult({
    required this.topic,
    required this.mainConcept,
    required this.branches,
  });

  factory MindMapResult.fromJson(Map<String, dynamic> json) {
    return MindMapResult(
      topic: json['topic'] ?? '',
      mainConcept: json['mainConcept'] ?? '',
      branches: (json['branches'] as List?)
          ?.map((b) => MindMapBranch.fromJson(b))
          .toList() ?? [],
    );
  }
}

class MindMapBranch {
  final String title;
  final String description;
  final List<String> subTopics;
  final List<String> keyPoints;

  MindMapBranch({
    required this.title,
    required this.description,
    required this.subTopics,
    required this.keyPoints,
  });

  factory MindMapBranch.fromJson(Map<String, dynamic> json) {
    return MindMapBranch(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subTopics: List<String>.from(json['subTopics'] ?? []),
      keyPoints: List<String>.from(json['keyPoints'] ?? []),
    );
  }
}

class MindMapScreen extends ConsumerStatefulWidget {
  const MindMapScreen({super.key});

  @override
  ConsumerState<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends ConsumerState<MindMapScreen> {
  final _topicController = TextEditingController();
  final _detailsController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _topicController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _generateMindMap() async {
    final topic = _topicController.text.trim();
    final details = _detailsController.text.trim();

    if (topic.isEmpty) {
      _showErrorSnackBar('Lütfen bir konu girin');
      return;
    }

    setState(() => _isGenerating = true);
    ref.read(mindMapStepProvider.notifier).state = MindMapStep.generating;

    try {
      final user = ref.read(userProfileProvider).value;
      if (user == null) throw Exception('Kullanıcı bilgisi bulunamadı');

      // AI prompt hazırlama
      final prompt = _buildMindMapPrompt(topic, details, user.selectedExam ?? 'YKS');

      // Firebase Functions ile AI çağrısı
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('ai-generateGemini');

      final result = await callable.call({
        'prompt': prompt,
        'expectJson': true,
        'requestType': 'mind_map',
        'maxOutputTokens': 10000,
        'temperature': 0.6,
      }).timeout(const Duration(seconds: 150));

      // Sonucu parse et
      final responseData = result.data;
      final rawText = responseData['raw'] as String;

      // JSON parse et
      final jsonData = jsonDecode(rawText);
      final mindMapResult = MindMapResult.fromJson(jsonData);

      // Sonucu kaydet
      ref.read(mindMapResultProvider.notifier).state = mindMapResult;
      ref.read(mindMapStepProvider.notifier).state = MindMapStep.result;

    } catch (e) {
      _showErrorSnackBar('Zihin haritası oluşturulamadı: ${e.toString()}');
      ref.read(mindMapStepProvider.notifier).state = MindMapStep.input;
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  String _buildMindMapPrompt(String topic, String details, String exam) {
    return '''
Sen bir eğitim asistanısın. Öğrencinin verdiği konu hakkında detaylı ve yapılandırılmış bir zihin haritası oluştur.

**Konu:** $topic
**Sınav:** $exam
${details.isNotEmpty ? '**Ek Detaylar:** $details' : ''}

**Görevin:**
1. Konuyu merkeze al ve ana kavramı belirle
2. 4-6 ana dal oluştur (her dal konunun bir yönünü temsil etmeli)
3. Her dalın altında:
   - Alt başlıklar (2-4 adet)
   - Anahtar noktalar (3-5 adet)
   - Kısa açıklama

**ÖNEMLİ:** Cevabını sadece JSON formatında ver, başka metin ekleme.

JSON Formatı:
{
  "topic": "Konu başlığı",
  "mainConcept": "Ana kavram açıklaması (1-2 cümle)",
  "branches": [
    {
      "title": "Dal başlığı",
      "description": "Dalın kısa açıklaması",
      "subTopics": ["Alt başlık 1", "Alt başlık 2", ...],
      "keyPoints": ["Anahtar nokta 1", "Anahtar nokta 2", ...]
    }
  ]
}
''';
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _resetMindMap() {
    ref.read(mindMapStepProvider.notifier).state = MindMapStep.input;
    ref.read(mindMapResultProvider.notifier).state = null;
    _topicController.clear();
    _detailsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(mindMapStepProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zihin Haritası'),
        centerTitle: true,
        actions: [
          if (step == MindMapStep.result)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _resetMindMap,
              tooltip: 'Yeni Harita',
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildStepContent(step),
      ),
    );
  }

  Widget _buildStepContent(MindMapStep step) {
    switch (step) {
      case MindMapStep.input:
        return _buildInputStep();
      case MindMapStep.generating:
        return _buildGeneratingStep();
      case MindMapStep.result:
        return _buildResultStep();
    }
  }

  Widget _buildInputStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_tree_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Zihin Haritası Oluştur',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Herhangi bir konuyu görselleştir ve daha iyi anla',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),

          const SizedBox(height: 32),

          // Konu girişi
          Text(
            'Konu',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _topicController,
            decoration: InputDecoration(
              hintText: 'Örn: Fotosentez, Newton Kanunları, Osmanlı Tarihi',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
            ),
            maxLength: 100,
          ).animate(delay: 100.ms).fadeIn().slideX(begin: -0.1, end: 0),

          const SizedBox(height: 24),

          // Ek detaylar (opsiyonel)
          Text(
            'Ek Detaylar (Opsiyonel)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsController,
            decoration: InputDecoration(
              hintText: 'Odaklanmak istediğin belirli yönler, sorular veya notlar...',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
            maxLines: 4,
            maxLength: 500,
          ).animate(delay: 200.ms).fadeIn().slideX(begin: -0.1, end: 0),

          const SizedBox(height: 32),

          // Oluştur butonu
          FilledButton.icon(
            onPressed: _isGenerating ? null : _generateMindMap,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_isGenerating ? 'Oluşturuluyor...' : 'Zihin Haritası Oluştur'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ).animate(delay: 300.ms).fadeIn().scale(),

          const SizedBox(height: 16),

          // Bilgilendirme
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Zihin haritası, konuyu ana dallarına ayırıp görsel olarak yapılandırır. Daha iyi anlama ve hatırlama sağlar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 400.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildGeneratingStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Lottie.asset(
              'assets/lotties/Data Analysis.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 2000.ms),
          const SizedBox(height: 24),
          Text(
            'Zihin Haritası Oluşturuluyor...',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 800.ms)
              .then()
              .fadeOut(duration: 800.ms),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Konunu analiz edip yapılandırılmış bir harita oluşturuyorum...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                color: colorScheme.secondary,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep() {
    final result = ref.watch(mindMapResultProvider);
    if (result == null) {
      return const Center(child: Text('Sonuç bulunamadı'));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık ve ana kavram
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_tree_rounded,
                  size: 40,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  result.topic,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  result.mainConcept,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn().scale(),

          const SizedBox(height: 24),

          // Dallar
          ...result.branches.asMap().entries.map((entry) {
            final index = entry.key;
            final branch = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildBranchCard(branch, index),
            ).animate(delay: (index * 100).ms).fadeIn().slideX(begin: -0.1, end: 0);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBranchCard(MindMapBranch branch, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Her dal için farklı renk
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
    ];
    final branchColor = colors[index % colors.length];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: branchColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: branchColor.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dal başlığı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: branchColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: branchColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: branchColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    branch.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: branchColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Açıklama
                Text(
                  branch.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                if (branch.subTopics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Alt Başlıklar',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: branchColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...branch.subTopics.map((subTopic) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.arrow_right_rounded,
                          color: branchColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subTopic,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],

                if (branch.keyPoints.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Anahtar Noktalar',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: branchColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...branch.keyPoints.map((keyPoint) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            keyPoint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

