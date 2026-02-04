// lib/features/mind_map/screens/mind_map_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/core/utils/exam_utils.dart';
import 'package:taktik/features/mind_map/screens/saved_mind_maps_screen.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------

enum NodeType { root, mainBranch, subBranch, leaf }

class MindMapNode {
  final String id;
  final String label;
  final String description;
  final NodeType type;
  final List<MindMapNode> children;

  // UI State (Layout sonrası hesaplanır)
  Offset position;
  Color color;

  MindMapNode({
    required this.id,
    required this.label,
    required this.description,
    required this.type,
    this.children = const [],
    this.position = Offset.zero,
    this.color = Colors.blue,
  });

  factory MindMapNode.fromJson(Map<String, dynamic> json, [NodeType type = NodeType.root]) {
    final childrenJson = json['children'];
    List<MindMapNode> parsedChildren = [];

    NodeType childType;
    if (type == NodeType.root) childType = NodeType.mainBranch;
    else if (type == NodeType.mainBranch) childType = NodeType.subBranch;
    else childType = NodeType.leaf;

    if (childrenJson is List) {
      parsedChildren = childrenJson.map((c) => MindMapNode.fromJson(c, childType)).toList();
    }

    return MindMapNode(
      id: DateTime.now().microsecondsSinceEpoch.toString() + (math.Random().nextInt(1000).toString()),
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: type,
      children: parsedChildren,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'description': description,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }
}

// -----------------------------------------------------------------------------
// PROVIDERS
// -----------------------------------------------------------------------------

final mindMapNodeProvider = StateProvider<MindMapNode?>((ref) => null);
final isGeneratingProvider = StateProvider<bool>((ref) => false);

// -----------------------------------------------------------------------------
// PAINTERS (Çizim Motoru)
// -----------------------------------------------------------------------------

class ConnectionPainter extends CustomPainter {
  final MindMapNode rootNode;
  final double scale;

  ConnectionPainter({required this.rootNode, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    _drawRecursive(canvas, rootNode, paint);
  }

  void _drawRecursive(Canvas canvas, MindMapNode node, Paint paint) {
    for (var child in node.children) {
      paint.color = child.color.withValues(alpha: 0.6);
      paint.strokeWidth = (node.type == NodeType.root ? 3.0 : 1.5);

      final p1 = node.position;
      final p2 = child.position;

      final path = Path();
      path.moveTo(p1.dx, p1.dy);

      final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

      if (node.type == NodeType.root) {
        path.quadraticBezierTo(midPoint.dx, midPoint.dy, p2.dx, p2.dy);
      } else {
        path.cubicTo(
            p1.dx + (p2.dx - p1.dx) / 2, p1.dy,
            p1.dx + (p2.dx - p1.dx) / 2, p2.dy,
            p2.dx, p2.dy
        );
      }

      canvas.drawPath(path, paint);
      _drawRecursive(canvas, child, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  final bool isDark;

  GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const spacing = 40.0;
    // Basit bir grid
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => oldDelegate.isDark != isDark;
}

// -----------------------------------------------------------------------------
// MAIN SCREEN
// -----------------------------------------------------------------------------

class MindMapScreen extends ConsumerStatefulWidget {
  const MindMapScreen({super.key});

  @override
  ConsumerState<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends ConsumerState<MindMapScreen> with TickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();

  Map<String, List<String>> _topicsBySubject = {};
  String? _selectedSubject;
  String? _selectedTopic;
  String _searchQuery = '';

  static const double _level1Distance = 250.0; // Biraz daha açtık
  static const double _level2Distance = 200.0;

  static const Size _canvasSize = Size(4000, 4000);
  static const Offset _center = Offset(2000, 2000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvas();
      _loadTopics();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _centerCanvas() {
    if (!mounted) return;
    // Ekran boyutunu al
    final size = MediaQuery.of(context).size;
    final x = -_center.dx + size.width / 2;
    final y = -_center.dy + size.height / 2;

    _transformationController.value = Matrix4.identity()
      ..translateByVector3(Vector3(x, y, 0));
  }

  Future<void> _loadTopics() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    try {
      if (user.selectedExam == null) return;
      final ExamType examEnum = ExamType.values.byName(user.selectedExam!);
      final examData = await ExamData.getExamByType(examEnum);

      final Map<String, List<String>> topicsBySubject = {};

      // ExamUtils zaten doğru sırayı (Curriculum Order) döndürür
      final relevantSections = ExamUtils.getRelevantSectionsForUser(user, examData);

      for (var section in relevantSections) {
        section.subjects.forEach((subjectName, subjectDetails) {
          final topicNames = subjectDetails.topics.map((t) => t.name).toList();

          if (topicNames.isNotEmpty) {
            // Eğer aynı ders başka section'da da varsa birleştir
            if (topicsBySubject.containsKey(subjectName)) {
              final existingTopics = topicsBySubject[subjectName]!;
              final newTopics = topicNames.where((topic) => !existingTopics.contains(topic)).toList();
              topicsBySubject[subjectName] = [...existingTopics, ...newTopics];
            } else {
              // Map'e ekleme sırası korunur
              topicsBySubject[subjectName] = topicNames;
            }
          }
        });
      }

      if (mounted) {
        setState(() {
          _topicsBySubject = topicsBySubject;
        });
      }
    } catch (e) {
      debugPrint('Error loading topics: $e');
    }
  }

  Map<String, List<String>> _filterTopics(Map<String, List<String>> allTopics) {
    if (_searchQuery.isEmpty) {
      return allTopics;
    }

    final filtered = <String, List<String>>{};

    for (var entry in allTopics.entries) {
      final subject = entry.key;
      final topics = entry.value;

      // Ders adında arama
      final subjectMatches = subject.toLowerCase().contains(_searchQuery);

      // Konularda arama
      final matchingTopics = topics.where((topic) {
        return topic.toLowerCase().contains(_searchQuery);
      }).toList();

      if (subjectMatches) {
        // Ders adı eşleşiyorsa tüm konuları göster
        filtered[subject] = topics;
      } else if (matchingTopics.isNotEmpty) {
        // Sadece eşleşen konuları göster
        filtered[subject] = matchingTopics;
      }
    }

    return filtered;
  }

  // JSON Temizleme (Markdown vb. silme)
  String _cleanJson(String text) {
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();
    if (text.startsWith('json')) text = text.substring(4).trim();
    return text;
  }

  void _calculateLayout(MindMapNode root) {
    root.position = _center;
    root.color = Colors.amber;

    final mainBranches = root.children;
    final angleStep = (2 * math.pi) / (mainBranches.isEmpty ? 1 : mainBranches.length);

    final colors = [
      Colors.blueAccent, Colors.redAccent, Colors.greenAccent,
      Colors.purpleAccent, Colors.orangeAccent, Colors.tealAccent
    ];

    for (int i = 0; i < mainBranches.length; i++) {
      final angle = i * angleStep;
      final node = mainBranches[i];

      node.position = Offset(
        _center.dx + _level1Distance * math.cos(angle),
        _center.dy + _level1Distance * math.sin(angle),
      );
      node.color = colors[i % colors.length];

      _layoutChildren(node, angle, _level2Distance);
    }
  }

  void _layoutChildren(MindMapNode parent, double parentAngle, double distance) {
    if (parent.children.isEmpty) return;

    final childCount = parent.children.length;
    final wedgeSize = math.pi / 2.0;
    final startAngle = parentAngle - (wedgeSize / 2);
    final angleStep = wedgeSize / (childCount > 1 ? childCount - 1 : 1);

    for (int i = 0; i < childCount; i++) {
      final angle = childCount == 1 ? parentAngle : startAngle + (i * angleStep);
      final child = parent.children[i];

      child.position = Offset(
        parent.position.dx + distance * math.cos(angle),
        parent.position.dy + distance * math.sin(angle),
      );
      child.color = parent.color;

      // 3. seviye için recursive devam edilebilir, şimdilik 2 seviye yeterli
    }
  }

  Future<void> _generateMindMap() async {
    final topic = _selectedTopic;
    if (topic == null || topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen bir konu seçin"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ref.read(isGeneratingProvider.notifier).state = true;

    try {
      final user = ref.read(userProfileProvider).value;

      final prompt = '''
      Konu: "$topic". Sınav Seviyesi: ${user?.selectedExam ?? 'Genel'}.
      Bu konu için detaylı bir zihin haritası JSON çıktısı oluştur.
      
      Format:
      {
        "label": "$topic",
        "description": "Ana konu",
        "children": [
          {
            "label": "Alt Konu",
            "description": "Açıklama",
            "children": [
              { "label": "Detay", "description": "Detay açıklama" }
            ]
          }
        ]
      }
      En az 4 ana dal ve her dalın altında 2-3 detay olsun. JSON dışında hiçbir şey yazma.
      ''';

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('ai-generateGemini');

      final result = await callable.call({
        'prompt': prompt,
        'expectJson': true,
        'requestType': 'mind_map', // Backend için gerekli olabilir
        'maxOutputTokens': 4000,
        'temperature': 0.7,
      });

      final rawText = result.data['raw'] as String;
      final cleanText = _cleanJson(rawText); // JSON temizleme

      final jsonMap = jsonDecode(cleanText);
      final rootNode = MindMapNode.fromJson(jsonMap, NodeType.root);

      _calculateLayout(rootNode);

      ref.read(mindMapNodeProvider.notifier).state = rootNode;
      _centerCanvas(); // Yeni harita gelince ortala

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata oluştu: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      ref.read(isGeneratingProvider.notifier).state = false;
    }
  }

  void _saveMindMap() async {
    final rootNode = ref.read(mindMapNodeProvider);
    final user = ref.read(userProfileProvider).value;

    if (rootNode == null || user == null) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // MindMapNode'u JSON'a çevir
      final mindMapJson = rootNode.toJson();

      // Firestore'a kaydet
      await firestoreService.saveMindMap(
        userId: user.id,
        topic: _selectedTopic ?? rootNode.label,
        subject: _selectedSubject ?? 'Genel',
        mindMapData: mindMapJson,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${_selectedTopic ?? "Zihin haritası"} başarıyla kaydedildi!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Görüntüle',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SavedMindMapsScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showNodeDetails(MindMapNode node) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: node.color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              node.label,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: node.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              node.description.isEmpty ? "Ek açıklama yok." : node.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showTopicSelectionSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredTopics = _filterTopics(_topicsBySubject);
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Konu Seç',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Arama çubuğu
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Ders veya konu ara...',
                          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(color: colorScheme.onSurface),
                        onChanged: (value) {
                          setModalState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: filteredTopics.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'Konu bulunamadı'
                                : 'Arama sonucu bulunamadı',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTopics.length,
                          itemBuilder: (context, index) {
                            final subject = filteredTopics.keys.elementAt(index);
                            final topics = filteredTopics[subject]!;

                            return Card(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isDark ? 0 : 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Text(
                                  subject,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${topics.length} konu',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                iconColor: colorScheme.primary,
                                collapsedIconColor: colorScheme.onSurfaceVariant,
                                children: topics.map((topic) {
                                  final isSelected = _selectedTopic == topic;
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      topic,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    leading: Icon(
                                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedTopic = topic;
                                        _selectedSubject = subject;
                                      });
                                      Navigator.pop(context);
                                      _generateMindMap();
                                    },
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootNode = ref.watch(mindMapNodeProvider);
    final isGenerating = ref.watch(isGeneratingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // AppBar ekledik ki geri dönme sorunu yaşanmasın
      appBar: AppBar(
        title: const Text("Zihin Haritası"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Kaydedilenler',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedMindMapsScreen(),
                ),
              );
            },
          ),
          if (rootNode != null)
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              tooltip: 'Ortala',
              onPressed: _centerCanvas,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (rootNode != null)
            InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(2000),
              minScale: 0.1,
              maxScale: 3.0,
              constrained: false,
              child: SizedBox(
                width: _canvasSize.width,
                height: _canvasSize.height,
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: GridPainter(isDark: isDark))),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ConnectionPainter(rootNode: rootNode, scale: 1.0),
                      ),
                    ),
                    ..._buildNodeWidgets(rootNode),
                  ],
                ),
              ),
            )
          else
            _buildEmptyState(),

          if (isGenerating)
            Container(
              color: colorScheme.surface.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 20),
                    Text(
                      "Zihin haritası oluşturuluyor...",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (rootNode != null && !isGenerating)
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _saveMindMap,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(
                      'Zihin Haritasını Kaydet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub, size: 80, color: colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(
              "Zihin Haritası",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Karmaşık konuları görselleştir. Listeden bir konu seç, yapay zeka senin için dallara ayırsın.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Konu Seçme Butonu
            if (_topicsBySubject.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _showTopicSelectionSheet,
                  icon: const Icon(Icons.school_rounded),
                  label: Text(
                    _selectedTopic ?? 'Konu Seç',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              )
            else
              CircularProgressIndicator(color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNodeWidgets(MindMapNode node) {
    List<Widget> widgets = [];

    // Node'u tam merkezinden yerleştirmek için offset ayarı
    double w = node.type == NodeType.root ? 140 : 110;
    double h = node.type == NodeType.root ? 70 : 55;

    widgets.add(
      Positioned(
        left: node.position.dx - (w / 2),
        top: node.position.dy - (h / 2),
        child: _NodeWidget(
          node: node,
          width: w,
          height: h,
          onTap: () => _showNodeDetails(node),
        ),
      ),
    );

    for (var child in node.children) {
      widgets.addAll(_buildNodeWidgets(child));
    }
    return widgets;
  }
}

class _NodeWidget extends StatelessWidget {
  final MindMapNode node;
  final VoidCallback onTap;
  final double width;
  final double height;

  const _NodeWidget({
    required this.node,
    required this.onTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final isRoot = node.type == NodeType.root;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(isRoot ? 35 : 12),
          border: Border.all(
            color: node.color,
            width: isRoot ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: node.color.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 0,
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          node.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
            fontSize: isRoot ? 14 : 11,
            fontWeight: isRoot ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      )
          .animate()
          .scale(duration: 400.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 300.ms),
    );
  }
}

// -----------------------------------------------------------------------------
// LEGACY SUPPORT (Eski kodlar kırılmasın diye)
// -----------------------------------------------------------------------------

@deprecated
enum MindMapStep { input, generating, result }

@deprecated
class MindMapResult {
  final String topic;
  final String mainConcept;
  final List<dynamic> branches;
  MindMapResult({required this.topic, required this.mainConcept, required this.branches});
}