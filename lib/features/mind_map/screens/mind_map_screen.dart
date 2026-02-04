// lib/features/mind_map/screens/mind_map_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

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
      paint.color = child.color.withOpacity(0.6);
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
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  final _topicController = TextEditingController();

  static const double _rootRadius = 60.0;
  static const double _level1Distance = 250.0; // Biraz daha açtık
  static const double _level2Distance = 200.0;

  static const Size _canvasSize = Size(4000, 4000);
  static const Offset _center = Offset(2000, 2000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvas();
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
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
      ..translate(x, y);
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
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    FocusScope.of(context).unfocus();
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

  void _showNodeDetails(MindMapNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: node.color, width: 4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              node.label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: node.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              node.description.isEmpty ? "Ek açıklama yok." : node.description,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootNode = ref.watch(mindMapNodeProvider);
    final isGenerating = ref.watch(isGeneratingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      // AppBar ekledik ki geri dönme sorunu yaşanmasın
      appBar: AppBar(
        title: const Text("Zihin Haritası"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (rootNode != null)
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _centerCanvas,
            )
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
                    Positioned.fill(child: CustomPaint(painter: GridPainter())),
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
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 20),
                    Text("Zihin haritası oluşturuluyor...",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (rootNode != null && !isGenerating)
          ? Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16, right: 16, top: 16
        ),
        color: const Color(0xFF0F1115),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  hintText: 'Yeni konu...',
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _generateMindMap,
              backgroundColor: theme.primaryColor,
              mini: true,
              child: const Icon(Icons.auto_awesome),
            ),
          ],
        ),
      )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hub, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            const Text(
              "Zihin Haritası",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              "Karmaşık konuları görselleştir. Bir konu gir ve yapay zeka senin için dallara ayırsın.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                hintText: 'Örn: Fotosentez, Türev',
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _generateMindMap,
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Oluştur"),
              ),
            ),
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
    final isRoot = node.type == NodeType.root;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(isRoot ? 35 : 12),
          border: Border.all(
            color: node.color,
            width: isRoot ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: node.color.withOpacity(0.4),
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
            color: Colors.white,
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