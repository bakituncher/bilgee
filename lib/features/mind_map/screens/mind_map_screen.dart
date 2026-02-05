// lib/features/mind_map/screens/mind_map_screen.dart
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
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

final mindMapNodeProvider = StateProvider.autoDispose<MindMapNode?>((ref) => null);
final isGeneratingProvider = StateProvider.autoDispose<bool>((ref) => false);

// Hazır zihin haritaları için model
class PreMadeMindMap {
  final String id;
  final String topic;
  final String subject;
  final Map<String, dynamic> data;

  PreMadeMindMap({
    required this.id,
    required this.topic,
    required this.subject,
    required this.data,
  });

  factory PreMadeMindMap.fromJson(Map<String, dynamic> json) {
    return PreMadeMindMap(
      id: json['id'],
      topic: json['topic'],
      subject: json['subject'],
      data: json,
    );
  }
}

// Hazır haritaları yükleyen provider
final preMadeMapsProvider = FutureProvider.autoDispose<List<PreMadeMindMap>>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  if (user?.selectedExam == null) return [];

  final examType = user!.selectedExam!.toLowerCase();

  // KPSS türleri için ortak dosya
  String assetPath;
  if (examType.contains('kpss')) {
    assetPath = 'assets/data/mind_maps_kpss.json';
  } else {
    assetPath = 'assets/data/mind_maps_$examType.json';
  }

  try {
    final jsonString = await rootBundle.loadString(assetPath);
    final jsonData = jsonDecode(jsonString);
    final maps = (jsonData['maps'] as List)
        .map((m) => PreMadeMindMap.fromJson(m))
        .toList();
    return maps;
  } catch (e) {
    debugPrint('Hazır haritalar yüklenemedi: $e');
    return [];
  }
});

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
  final ScrollController _cardsScrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _userIsInteracting = false;

  Map<String, List<String>> _topicsBySubject = {};
  String? _selectedSubject;
  String? _selectedTopic;
  String _searchQuery = '';

  static const double _level1Distance = 250.0;
  static const double _level2Distance = 200.0;

  static const Size _canvasSize = Size(4000, 4000);
  static const Offset _center = Offset(2000, 2000);

  @override
  void initState() {
    super.initState();
    // Ekran açıldığında önceki haritayı temizle
    ref.read(mindMapNodeProvider.notifier).state = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvas();
      _loadTopics();
      // Otomatik kaydırmayı biraz daha geç başlat
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startAutoScroll();
        }
      });
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();

    if (!mounted) return;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted || !_cardsScrollController.hasClients) {
        timer.cancel();
        return;
      }

      // Kullanıcı etkileşim halindeyse hiçbir şey yapma
      if (_userIsInteracting) {
        return;
      }

      final position = _cardsScrollController.position;
      final maxScroll = position.maxScrollExtent;
      final currentScroll = position.pixels;

      if (maxScroll <= 0) return;

      if (currentScroll >= maxScroll) {
        // Sonuna geldik, başa dön
        _cardsScrollController.jumpTo(0);
      } else {
        // Daha hızlı ilerle
        final nextPosition = currentScroll + 0.8;
        if (nextPosition <= maxScroll) {
          _cardsScrollController.jumpTo(nextPosition);
        }
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _cardsScrollController.dispose();
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

  // JSON Temizleme
  String _cleanJson(String text) {
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();
    if (text.startsWith('json')) text = text.substring(4).trim();
    return text;
  }

  void _calculateLayout(MindMapNode root) {
    root.position = _center;
    root.color = const Color(0xFF6366F1); // Indigo

    final mainBranches = root.children;
    final angleStep = (2 * math.pi) / (mainBranches.isEmpty ? 1 : mainBranches.length);

    // Ana dallar için canlı renkler
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFF10B981), // Green
      const Color(0xFFA855F7), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFEC4899), // Pink
      const Color(0xFF6366F1), // Indigo
    ];

    for (int i = 0; i < mainBranches.length; i++) {
      final angle = i * angleStep;
      final node = mainBranches[i];

      node.position = Offset(
        _center.dx + _level1Distance * math.cos(angle),
        _center.dy + _level1Distance * math.sin(angle),
      );
      // Her ana dala farklı renk ata
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
        'requestType': 'mind_map',
        'maxOutputTokens': 4000,
        'temperature': 0.7,
      });

      final rawText = result.data['raw'] as String;
      final cleanText = _cleanJson(rawText);

      final jsonMap = jsonDecode(cleanText);
      final rootNode = MindMapNode.fromJson(jsonMap, NodeType.root);

      _calculateLayout(rootNode);

      ref.read(mindMapNodeProvider.notifier).state = rootNode;
      _centerCanvas();

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

      final mindMapJson = rootNode.toJson();

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
                        elevation: 0,
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

  Widget _buildPreMadeMapsHorizontalList(ThemeData theme, ColorScheme colorScheme) {
    final preMadeMapsAsync = ref.watch(preMadeMapsProvider);

    return preMadeMapsAsync.when(
      data: (maps) {
        if (maps.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 240,
          margin: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onPanDown: (_) {
              // Kullanıcı dokundu
              _userIsInteracting = true;
              _autoScrollTimer?.cancel();
            },
            onPanEnd: (_) {
              // Kullanıcı bıraktı
              _userIsInteracting = false;
              // 2 saniye sonra tekrar başlat
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted && !_userIsInteracting) {
                  _startAutoScroll();
                }
              });
            },
            onPanCancel: () {
              // Kullanıcı iptal etti
              _userIsInteracting = false;
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted && !_userIsInteracting) {
                  _startAutoScroll();
                }
              });
            },
            child: ListView.builder(
              controller: _cardsScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: maps.length,
              itemBuilder: (context, index) {
                final map = maps[index];
                return _PreMadeMapCard(
                  map: map,
                  theme: theme,
                  colorScheme: colorScheme,
                  onTap: () {
                    _autoScrollTimer?.cancel();
                    _userIsInteracting = true;
                    setState(() {
                      _selectedTopic = map.topic;
                      _selectedSubject = map.subject;
                    });
                    _loadPreMadeMap(map);
                  },
                );
              },
            ),
          ),
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      )),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  void _loadPreMadeMap(PreMadeMindMap map) {
    try {
      final rootNode = MindMapNode.fromJson(map.data, NodeType.root);
      _calculateLayout(rootNode);
      ref.read(mindMapNodeProvider.notifier).state = rootNode;
      _centerCanvas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Harita yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      appBar: AppBar(
        title: const Text("Zihin Haritası"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (rootNode == null)
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
      body: Column(
        children: [
          // Ana içerik
          Expanded(
            child: Stack(
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48), // Üst boşluk

            // 1. Tanıtım Alanı (En üstte)
            Lottie.asset(
              'assets/lotties/Brain.json',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              "Zihin Haritası",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                "Karmaşık konuları görselleştir. Listeden bir konu seç, yapay zeka senin için dallara ayırsın.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 2. Hazır Haritalar Listesi (Önce bu gösterilecek)
            _buildPreMadeMapsHorizontalList(theme, colorScheme),

            // Modern Ayırıcı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            colorScheme.outline.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'veya',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.outline.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Konu Seçme Butonu (Sonra bu gösterilecek)
            if (_topicsBySubject.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _showTopicSelectionSheet,
                    icon: const Icon(Icons.school_rounded),
                    label: Text(
                      _selectedTopic ?? 'Yeni Zihin Haritası Oluştur',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 4,
                      shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              )
            else
              CircularProgressIndicator(color: colorScheme.primary),


            const SizedBox(height: 32), // Alt boşluk
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

class _PreMadeMapCard extends StatelessWidget {
  final PreMadeMindMap map;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _PreMadeMapCard({
    required this.map,
    required this.theme,
    required this.colorScheme,
    required this.onTap,
  });

  List<Widget> _buildPreviewNodeWidgets(MindMapNode node, double scale) {
    List<Widget> widgets = [];

    // Node boyutlarını scale'e göre ayarla
    double w = (node.type == NodeType.root ? 140 : 110) * scale;
    double h = (node.type == NodeType.root ? 70 : 55) * scale;

    // Canvas merkezi 2000,2000 - bunu 160,80'e dönüştürmek için offset gerekiyor
    const canvasCenter = 2000.0;
    const previewCenterX = 160.0;
    const previewCenterY = 80.0;

    // Node pozisyonunu scale'le ve offset'le
    final scaledX = (node.position.dx - canvasCenter) * scale + previewCenterX;
    final scaledY = (node.position.dy - canvasCenter) * scale + previewCenterY;

    widgets.add(
      Positioned(
        left: scaledX - (w / 2),
        top: scaledY - (h / 2),
        child: Container(
          width: w,
          height: h,
          padding: EdgeInsets.symmetric(horizontal: 2 * scale),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(node.type == NodeType.root ? 35 * scale : 12 * scale),
            border: Border.all(
              color: node.color,
              width: (node.type == NodeType.root ? 3 : 1.5) * scale,
            ),
            boxShadow: [
              BoxShadow(
                color: node.color.withValues(alpha: 0.3),
                blurRadius: 8 * scale,
                spreadRadius: 0,
              )
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            node.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: (node.type == NodeType.root ? 14 : 11) * scale,
              fontWeight: node.type == NodeType.root ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    for (var child in node.children) {
      widgets.addAll(_buildPreviewNodeWidgets(child, scale));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    // Zihin haritasını node'a çevir ve GERÇEK layout hesapla
    MindMapNode? previewNode;
    try {
      previewNode = MindMapNode.fromJson(map.data, NodeType.root);
      // Gerçek layout fonksiyonunu kullan - aynı _MindMapScreenState'teki gibi
      _calculateRealLayout(previewNode);
    } catch (e) {
      debugPrint('Preview node oluşturulamadı: $e');
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        height: 220, // Toplam yükseklik tanımlandı: 160 (önizleme) + 60 (başlık alanı)
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Önizleme alanı - GERÇEK zihin haritasının küçültülmüş hali
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.15),
                    colorScheme.secondaryContainer.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: previewNode != null
                  ? ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(
                  children: [
                    // Grid arka plan (çok ince)
                    CustomPaint(
                      painter: GridPainter(isDark: isDark),
                      size: const Size(320, 160),
                    ),
                    // Bağlantılar
                    CustomPaint(
                      painter: _ScaledConnectionPainter(
                        rootNode: previewNode,
                        scale: 0.12, // Daha büyük önizleme için scale artırıldı
                        offsetX: 160,
                        offsetY: 80,
                      ),
                      size: const Size(320, 160),
                    ),
                    // Node'lar - gerçek widget'lar ama küçültülmüş
                    ..._buildPreviewNodeWidgets(previewNode, 0.12),
                  ],
                ),
              )
                  : Center(
                child: Icon(
                  Icons.error_outline,
                  color: colorScheme.error.withValues(alpha: 0.5),
                  size: 32,
                ),
              ),
            ),

            // Konu başlığı
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    map.topic,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.2, duration: 400.ms);
  }

  void _calculateRealLayout(MindMapNode root) {
    // GERÇEK layout - ana ekrandaki ile aynı
    const center = Offset(2000, 2000); // 4000x4000 canvas merkezi
    root.position = center;
    root.color = const Color(0xFF6366F1);

    final mainBranches = root.children;
    final angleStep = (2 * math.pi) / (mainBranches.isEmpty ? 1 : mainBranches.length);

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
      const Color(0xFFA855F7),
      const Color(0xFFF59E0B),
      const Color(0xFF14B8A6),
      const Color(0xFFEC4899),
      const Color(0xFF6366F1),
    ];

    const level1Distance = 250.0;

    for (int i = 0; i < mainBranches.length; i++) {
      final angle = i * angleStep;
      final node = mainBranches[i];

      node.position = Offset(
        center.dx + level1Distance * math.cos(angle),
        center.dy + level1Distance * math.sin(angle),
      );
      node.color = colors[i % colors.length];

      _layoutRealChildren(node, angle, 200.0);
    }
  }

  void _layoutRealChildren(MindMapNode parent, double parentAngle, double distance) {
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
    }
  }
}

// Scaled connection painter - önizleme için
class _ScaledConnectionPainter extends CustomPainter {
  final MindMapNode rootNode;
  final double scale;
  final double offsetX;
  final double offsetY;

  _ScaledConnectionPainter({
    required this.rootNode,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

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
      paint.color = child.color.withValues(alpha: 0.4);
      paint.strokeWidth = (node.type == NodeType.root ? 3.0 : 1.5) * scale;

      final p1 = Offset(
        (node.position.dx - 2000) * scale + offsetX,
        (node.position.dy - 2000) * scale + offsetY,
      );
      final p2 = Offset(
        (child.position.dx - 2000) * scale + offsetX,
        (child.position.dy - 2000) * scale + offsetY,
      );

      final path = Path();
      path.moveTo(p1.dx, p1.dy);

      final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

      if (node.type == NodeType.root) {
        path.quadraticBezierTo(midPoint.dx, midPoint.dy, p2.dx, p2.dy);
      } else {
        path.cubicTo(
          p1.dx + (p2.dx - p1.dx) / 2, p1.dy,
          p1.dx + (p2.dx - p1.dx) / 2, p2.dy,
          p2.dx, p2.dy,
        );
      }

      canvas.drawPath(path, paint);
      _drawRecursive(canvas, child, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScaledConnectionPainter oldDelegate) => false;
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