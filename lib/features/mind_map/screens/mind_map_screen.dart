// lib/features/mind_map/screens/mind_map_screen.dart
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/core/utils/exam_utils.dart';
import 'package:taktik/features/mind_map/screens/saved_mind_maps_screen.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/shared/widgets/custom_back_button.dart';

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
final savedMapHashProvider = StateProvider.autoDispose<String?>((ref) => null);
final isPreMadeMapProvider = StateProvider.autoDispose<bool>((ref) => false); // Hazır harita mı?

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

// Hazır haritaları yükleyen provider - keepAlive ile cache'leniyor
final preMadeMapsProvider = FutureProvider<List<PreMadeMindMap>>((ref) async {
  // Provider'ı canlı tut, dispose olmasın
  ref.keepAlive();

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
// HELPER FUNCTIONS
// -----------------------------------------------------------------------------

/// LaTeX ifadelerini basit metne çevirir (önizleme veya math render edilemeyen durumlar için)
String _stripLatex(String text) {
  // Display math: $$...$$
  text = text.replaceAll(RegExp(r'\$\$([^\$]+)\$\$'), r'\1');
  // Inline math: $...$
  text = text.replaceAll(RegExp(r'\$([^\$]+)\$'), r'\1');

  // LaTeX komutlarını temizle
  text = text.replaceAll(r'\lim', 'lim');
  text = text.replaceAll(r'\infty', '∞');
  text = text.replaceAll(r'\neq', '≠');
  text = text.replaceAll(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), r'\1/\2');
  text = text.replaceAll(RegExp(r'\\sqrt\[([^\]]+)\]\{([^}]+)\}'), r'ⁿ√\2');
  text = text.replaceAll(RegExp(r'\\sqrt\{([^}]+)\}'), r'√\1');
  text = text.replaceAll(r'\cdot', '·');
  text = text.replaceAll(r'\times', '×');
  text = text.replaceAll(r'\pm', '±');
  text = text.replaceAll(r'\to', '→');
  text = text.replaceAll(RegExp(r'\\_'), '_');
  text = text.replaceAll(RegExp(r'\\'), '');
  text = text.replaceAll(RegExp(r'[{}]'), '');

  return text.trim();
}

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
  bool _scrollingForward = true; // true = sağa, false = sola

  Map<String, List<String>> _topicsBySubject = {};
  String? _selectedSubject;
  String? _selectedTopic;
  String _searchQuery = '';

  static const double _level1Distance = 350.0;

  static const Size _canvasSize = Size(6000, 6000);
  static const Offset _center = Offset(3000, 3000);

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

      // Sona geldiysek yönü değiştir
      if (_scrollingForward && currentScroll >= maxScroll) {
        _scrollingForward = false;
      }
      // Başa geldiysek yönü değiştir
      else if (!_scrollingForward && currentScroll <= 0) {
        _scrollingForward = true;
      }

      // Yön bazında hareket et
      double nextPosition;
      if (_scrollingForward) {
        nextPosition = (currentScroll + 0.8).clamp(0.0, maxScroll);
      } else {
        nextPosition = (currentScroll - 0.8).clamp(0.0, maxScroll);
      }

      _cardsScrollController.jumpTo(nextPosition);
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

  // JSON Temizleme (Fix Applied)
  String _cleanJson(String text) {
    // 1. Markdown bloklarını temizle
    text = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();

    // Bazı durumlarda sadece "json" kelimesiyle başlıyorsa temizle
    if (text.startsWith('json')) text = text.substring(4).trim();

    // 2. KRİTİK DÜZELTME: LaTeX Backslash Yönetimi
    // Sorun: AI cevabında hem normal JSON kaçışı (\") hem de LaTeX (\frac) olabilir.

    // A. Önce JSON içinde yasal olan kaçışlı tırnakları ( \" ) korumaya al.
    text = text.replaceAll('\\"', '<<<ESCAPED_QUOTE>>>');

    // B. Zaten düzgün olan çift backslashleri ( \\ ) korumaya al.
    text = text.replaceAll('\\\\', '<<<ESCAPED_BACKSLASH>>>');

    // C. Şimdi kalan TEK backslashleri (LaTeX komutları örn: \frac -> \\frac) çiftle.
    text = text.replaceAll('\\', '\\\\');

    // D. Korumaya aldığımız tokenları gerçek değerlerine geri döndür.
    text = text.replaceAll('<<<ESCAPED_BACKSLASH>>>', '\\\\');
    text = text.replaceAll('<<<ESCAPED_QUOTE>>>', '\\"');

    return text.trim();
  }

  // Zihin haritasının hash'ini hesapla
  String _calculateMapHash(MindMapNode node) {
    final json = jsonEncode(node.toJson());
    return json.hashCode.toString();
  }

  // Global pozisyon listesi
  final List<Offset> _allNodePositions = [];

  // ---------------------------------------------------------------------------
  // YENİ LAYOUT ALGORİTMASI (Üst üste binmeyi engeller)
  // ---------------------------------------------------------------------------

  /// Bir düğümün altındaki toplam "yaprak" sayısını (genişliğini) hesaplar.
  int _calculateNodeWeight(MindMapNode node) {
    if (node.children.isEmpty) return 1;
    int weight = 0;
    for (var child in node.children) {
      weight += _calculateNodeWeight(child);
    }
    return weight;
  }

  /// Ana Layout Fonksiyonu
  void _calculateLayout(MindMapNode root) {
    // Pozisyon listesini temizle
    _allNodePositions.clear();

    // Kökü merkeze koy
    root.position = _center;
    root.color = const Color(0xFF6366F1); // Indigo
    _allNodePositions.add(root.position);

    if (root.children.isEmpty) return;

    final mainBranches = root.children;

    // Renk paleti
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

    // 1. Toplam ağırlığı bul
    int totalWeight = 0;
    for (var child in mainBranches) {
      totalWeight += _calculateNodeWeight(child);
    }

    // Başlangıç açısı (Yukarıdan başlasın: -90 derece)
    double currentAngle = -math.pi / 2;

    for (int i = 0; i < mainBranches.length; i++) {
      final node = mainBranches[i];
      node.color = colors[i % colors.length];

      // Düğümün ağırlığına göre pastadan pay (sweep angle) ver
      int weight = _calculateNodeWeight(node);
      // Toplam pasta 360 derece (2 * pi)
      double sweepAngle = (weight / totalWeight) * 2 * math.pi;

      // Bu dalı, kendisine ayrılan açının tam ortasından geçirerek yerleştir
      _layoutRecursive(
          node,
          currentAngle,
          sweepAngle,
          _level1Distance // İlk seviye mesafesi
      );

      // Bir sonraki dal için açıyı kaydır
      currentAngle += sweepAngle;
    }
  }

  /// Özyinelemeli (Recursive) Yerleştirme
  void _layoutRecursive(
      MindMapNode node,
      double startAngle,
      double sweep,
      double distanceCtx
      ) {
    // 1. Düğümü kendisine ayrılan açının (sweep) merkezine yerleştir
    double midAngle = startAngle + (sweep / 2);

    // Konumu MERKEZE göre hesapla (Ray Layout)
    node.position = Offset(
        _center.dx + distanceCtx * math.cos(midAngle),
        _center.dy + distanceCtx * math.sin(midAngle)
    );
    _allNodePositions.add(node.position);

    if (node.children.isEmpty) return;

    // 2. Çocukları yerleştirmek için hazırlık
    int childTotalWeight = 0;
    for (var child in node.children) {
      childTotalWeight += _calculateNodeWeight(child);
    }

    // 3. Mesafeyi (Radius) Hesapla - Çakışmayı Önleyen Kısım
    // Kart yüksekliği ~100px. Yay uzunluğu = r * açı. => r = 100 / açı.
    double minArcLengthPerChild = 140.0; // Kartın dikeyde kapladığı minimum alan + boşluk
    double calculatedDistance = distanceCtx + 220.0; // Standart artış

    // Eğer açı çok küçükse (kalabalık dal) mesafeyi artır
    if (childTotalWeight > 0) {
      // Ortalama çocuk başına düşen açı
      double avgAnglePerChild = sweep / node.children.length;

      // Sıfıra bölünmeyi önle
      if (avgAnglePerChild > 0.01) {
        double requiredDistance = minArcLengthPerChild / avgAnglePerChild;

        // Çok aşırı uzamaması için bir limit koy ama gerekirse uzat
        if (requiredDistance > calculatedDistance) {
          // Örneğin max 2000px ekstra uzasın
          calculatedDistance = math.min(requiredDistance, distanceCtx + 1200);
        }
      }
    }

    double currentChildAngle = startAngle;

    for (var child in node.children) {
      child.color = node.color; // Rengi miras al

      int weight = _calculateNodeWeight(child);
      // Ebeveynin açısını, çocuğun ağırlığına göre paylaştır
      double childSweep = (weight / childTotalWeight) * sweep;

      _layoutRecursive(child, currentChildAngle, childSweep, calculatedDistance);

      currentChildAngle += childSweep;
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
      
      ÖNEMLİ: Matematiksel ifadeleri mutlaka LaTeX formatında yaz:
      - Inline formüller için: \$formül\$ (Örn: \$x^2 + 5x = 0\$)
      - Display formüller için: \$\$formül\$\$ (Örn: \$\$\\frac{a}{b}\$\$)
      - Yunan harfleri: \$\\alpha, \\beta, \\pi\$ gibi
      - Üst simge: \$x^2\$, Alt simge: \$x_n\$
      - Kesir: \$\\frac{a}{b}\$
      
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

      // Bu AI tarafından oluşturulmuş bir harita, kaydedilebilir
      ref.read(isPreMadeMapProvider.notifier).state = false;

      // Firestore'da aynı topic ve subject ile kayıt var mı kontrol et
      if (user != null) {
        final firestoreService = ref.read(firestoreServiceProvider);
        final existingMaps = await firestoreService.getSavedMindMaps(user.id).first;

        // Aynı topic ve subject'e sahip kayıt var mı?
        final matchingMap = existingMaps.where((savedMap) {
          return savedMap['topic'] == topic && savedMap['subject'] == (_selectedSubject ?? 'Genel');
        }).toList();

        if (matchingMap.isNotEmpty) {
          // Kayıtlı harita var, hash'ini hesapla ve kaydet
          final hash = _calculateMapHash(rootNode);
          ref.read(savedMapHashProvider.notifier).state = hash;
        } else {
          // Kayıtlı harita yok, hash'i sıfırla
          ref.read(savedMapHashProvider.notifier).state = null;
        }
      } else {
        // Kullanıcı yoksa hash'i sıfırla
        ref.read(savedMapHashProvider.notifier).state = null;
      }

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

      // Hash'i hesapla
      final currentHash = _calculateMapHash(rootNode);

      await firestoreService.saveMindMap(
        userId: user.id,
        topic: _selectedTopic ?? rootNode.label,
        subject: _selectedSubject ?? 'Genel',
        mindMapData: mindMapJson,
      );

      // Kayıt başarılı, hash'i provider'a kaydet
      ref.read(savedMapHashProvider.notifier).state = currentHash;

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
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const SavedMindMapsScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: node.color, width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: node.label,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: node.color,
                ),
              ),
              builders: {
                'latex': LatexElementBuilder(
                  textStyle: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: node.color,
                  ),
                ),
              },
              extensionSet: md.ExtensionSet(
                [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
              ),
            ),
            const SizedBox(height: 8),
            MarkdownBody(
              data: node.description.isEmpty ? "Ek açıklama yok." : node.description,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              builders: {
                'latex': LatexElementBuilder(
                  textStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              },
              extensionSet: md.ExtensionSet(
                [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPremiumDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.15),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_tree_rounded,
                size: 56,
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sınırsız Zihin Haritası',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Daha fazla zihin haritası oluştur, öğrenmeyi görselleştir.\nTaktik Pro ile limitsiz öğren!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Daha Sonra',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/premium');
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Pro\'ya Geç',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTopicSelectionSheet() {
    // Premium kontrolü
    final isPremium = ref.read(premiumStatusProvider);

    if (!isPremium) {
      _showPremiumDialog();
      return;
    }

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
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 8),
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
                            vertical: 10,
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
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredTopics.length,
                    itemBuilder: (context, index) {
                      final subject = filteredTopics.keys.elementAt(index);
                      final topics = filteredTopics[subject]!;

                      return Card(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          height: 250, // YÜKSEKLİK ARTIRILDI (225 -> 250)
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
        padding: EdgeInsets.all(12.0),
        child: CircularProgressIndicator(),
      )),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  void _loadPreMadeMap(PreMadeMindMap map) async {
    try {
      final rootNode = MindMapNode.fromJson(map.data, NodeType.root);
      _calculateLayout(rootNode);
      ref.read(mindMapNodeProvider.notifier).state = rootNode;
      _centerCanvas();

      // Bu hazır bir harita
      ref.read(isPreMadeMapProvider.notifier).state = true;

      // Hazır haritalar kaydedilemez, hash'i sıfırla
      ref.read(savedMapHashProvider.notifier).state = null;
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
    final savedHash = ref.watch(savedMapHashProvider);
    final isPreMadeMap = ref.watch(isPreMadeMapProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Mevcut haritanın hash'i
    final currentHash = rootNode != null ? _calculateMapHash(rootNode) : null;

    return PopScope(
      canPop: rootNode == null, // Harita yoksa normal geri gidebilir
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && rootNode != null) {
          // Harita varsa ve geri gidemediyse, haritayı temizle
          ref.read(mindMapNodeProvider.notifier).state = null;
          // Scroll'u otomatik başlat
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_userIsInteracting) {
              _startAutoScroll();
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Zihin Haritası"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: CustomBackButton(
            onPressed: () {
              if (rootNode != null) {
                // Harita gösteriliyorsa, haritayı temizle ve konu seçim ekranına dön
                ref.read(mindMapNodeProvider.notifier).state = null;
                // Scroll'u otomatik başlat
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && !_userIsInteracting) {
                    _startAutoScroll();
                  }
                });
              } else {
                // Harita yoksa normal geri git
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/home');
                }
              }
            },
          ),
          actions: [
            if (rootNode == null)
              IconButton(
                icon: const Icon(Icons.folder_outlined),
                tooltip: 'Kaydedilenler',
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const SavedMindMapsScreen(),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
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
                            const SizedBox(height: 16),
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
        bottomNavigationBar: (rootNode != null && !isGenerating && !isPreMadeMap && currentHash != savedHash)
            ? Container(
          padding: const EdgeInsets.all(12),
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
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saveMindMap,
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Zihin Haritasını Kaydet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
      ), // Scaffold kapanışı
    ); // PopScope kapanışı
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
            const SizedBox(height: 32), // Üst boşluk

            // 1. Tanıtım Alanı (En üstte)
            Lottie.asset(
              'assets/lotties/Brain.json',
              width: 110,
              height: 110,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Text(
                "Karmaşık konuları görselleştir. Listeden bir konu seç, Taktik senin için dallara ayırsın.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Hazır Haritalar Listesi (Önce bu gösterilecek)
            _buildPreMadeMapsHorizontalList(theme, colorScheme),

            // Modern Ayırıcı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 44.0, vertical: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _showTopicSelectionSheet,
                    icon: const Icon(Icons.school_rounded),
                    label: const Text(
                      'Yeni Zihin Haritası Oluştur',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 3,
                      shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              )
            else
              CircularProgressIndicator(color: colorScheme.primary),


            const SizedBox(height: 24), // Alt boşluk
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
        left: node.position.dx, // Merkez noktası
        top: node.position.dy,  // Merkez noktası
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

class _NodeWidget extends StatefulWidget {
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
  State<_NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<_NodeWidget> {
  final GlobalKey _key = GlobalKey();
  late Offset _offset;

  @override
  void initState() {
    super.initState();
    // Başlangıç offseti - minimum boyuta göre merkez
    _offset = Offset(-widget.width / 2, -widget.height / 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOffset();
    });
  }

  void _updateOffset() {
    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      final size = renderBox.size;
      setState(() {
        // Gerçek boyuta göre merkezi hesapla
        _offset = Offset(-size.width / 2, -size.height / 2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final isRoot = widget.node.type == NodeType.root;

    return Transform.translate(
      offset: _offset,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ConstrainedBox(
          key: _key,
          constraints: BoxConstraints(
            minWidth: widget.width,
            maxWidth: widget.width * 2.5, // İçerik çok uzunsa 2.5 katına kadar genişleyebilir
            minHeight: widget.height,
            maxHeight: widget.height * 3, // İçerik çok uzunsa 3 katına kadar uzayabilir
          ),
          child: IntrinsicWidth(
            child: IntrinsicHeight(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(isRoot ? 35 : 12),
                  border: Border.all(
                    color: widget.node.color,
                    width: isRoot ? 3 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.node.color.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 0,
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: MarkdownBody(
                  data: widget.node.label,
                  selectable: false,
                  shrinkWrap: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                      fontSize: isRoot ? 13 : 10.5,
                      fontWeight: isRoot ? FontWeight.bold : FontWeight.w600,
                    ),
                    textAlign: WrapAlignment.center,
                    h1Align: WrapAlignment.center,
                    blockSpacing: 0,
                    pPadding: EdgeInsets.zero,
                  ),
                  builders: {
                    'latex': LatexElementBuilder(
                      textStyle: TextStyle(
                        fontSize: isRoot ? 13 : 10.5,
                        color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                        fontWeight: isRoot ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  },
                  extensionSet: md.ExtensionSet(
                    [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                    [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
                  ),
                ),
              ),
            ),
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

  _PreMadeMapCard({
    required this.map,
    required this.theme,
    required this.colorScheme,
    required this.onTap,
  });

  List<Widget> _buildPreviewNodeWidgets(MindMapNode node, double scale) {
    List<Widget> widgets = [];

    // --- ÖNEMLİ: Boyutlar (Ana ekranla aynı) ---
    double baseW = node.type == NodeType.root ? 140 : 110;
    double baseH = node.type == NodeType.root ? 70 : 55;

    double w = baseW * scale;
    double h = baseH * scale;

    const canvasCenter = 3000.0; // 6000x6000 canvas merkezi
    const previewCenterX = 160.0;
    const previewCenterY = 90.0;

    final scaledX = (node.position.dx - canvasCenter) * scale + previewCenterX;
    final scaledY = (node.position.dy - canvasCenter) * scale + previewCenterY;

    widgets.add(
      Positioned(
        left: scaledX,
        top: scaledY,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: w,
              maxWidth: w * 2.5,
              minHeight: h,
              maxHeight: h * 3,
            ),
            child: IntrinsicWidth(
              child: IntrinsicHeight(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(node.type == NodeType.root ? 35 * scale : 12 * scale),
                    border: Border.all(
                      color: node.color,
                      width: (node.type == NodeType.root ? 3 : 1.5) * scale,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: node.color.withValues(alpha: 0.4),
                        blurRadius: 16 * scale,
                        spreadRadius: 0,
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _stripLatex(node.label),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: (node.type == NodeType.root ? 13 : 10.5) * scale,
                      fontWeight: node.type == NodeType.root ? FontWeight.bold : FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
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

    // Scale oranı (Zoom etkisi)
    const double previewScale = 0.20;
    const double previewHeight = 180.0;

    MindMapNode? previewNode;
    try {
      previewNode = MindMapNode.fromJson(map.data, NodeType.root);
      _calculateRealLayout(previewNode);
    } catch (e) {
      debugPrint('Preview node oluşturulamadı: $e');
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Önizleme Alanı ---
            SizedBox(
              height: previewHeight,
              child: Stack(
                children: [
                  // 1. Arka Plan
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E2C)
                          : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),
                  // Grid Deseni
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.3,
                      child: CustomPaint(
                        painter: GridPainter(isDark: isDark),
                      ),
                    ),
                  ),

                  // 2. İçerik
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: previewNode != null
                        ? Stack(
                      children: [
                        // Bağlantı Çizgileri
                        CustomPaint(
                          painter: _ScaledConnectionPainter(
                            rootNode: previewNode,
                            scale: previewScale,
                            offsetX: 160,
                            offsetY: 90,
                          ),
                          size: const Size(360, previewHeight),
                        ),
                        // Düğümler
                        ..._buildPreviewNodeWidgets(previewNode, previewScale),

                        // Vignette (Kenar gölgelendirmesi)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1),
                                ],
                                stops: const [0.0, 0.7, 1.0],
                                radius: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        : Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Başlık Alanı (Sadeleştirildi) ---
            Container(
              // DİKEY PADDING 14 -> 12 OLARAK AZALTILDI
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      map.topic, // Sadece konu başlığı
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Ok ikonu
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  // Önizleme için lokal pozisyon listesi
  final List<Offset> _previewNodePositions = [];

  /// Bir düğümün altındaki toplam "yaprak" sayısını (genişliğini) hesaplar.
  int _calculateNodeWeightForPreview(MindMapNode node) {
    if (node.children.isEmpty) return 1;
    int weight = 0;
    for (var child in node.children) {
      weight += _calculateNodeWeightForPreview(child);
    }
    return weight;
  }

  void _calculateRealLayout(MindMapNode root) {
    // Pozisyon listesini temizle
    _previewNodePositions.clear();

    // GERÇEK layout - ana ekrandaki ile TAM AYNI (YENİ ALGORİTMA)
    const center = Offset(3000, 3000); // 6000x6000 canvas merkezi
    const level1Distance = 350.0;

    // Kökü merkeze koy
    root.position = center;
    root.color = const Color(0xFF6366F1);
    _previewNodePositions.add(root.position);

    if (root.children.isEmpty) return;

    final mainBranches = root.children;

    // Renk paleti
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

    // 1. Toplam ağırlığı bul
    int totalWeight = 0;
    for (var child in mainBranches) {
      totalWeight += _calculateNodeWeightForPreview(child);
    }

    // Başlangıç açısı (Yukarıdan başlasın: -90 derece)
    double currentAngle = -math.pi / 2;

    for (int i = 0; i < mainBranches.length; i++) {
      final node = mainBranches[i];
      node.color = colors[i % colors.length];

      // Düğümün ağırlığına göre pastadan pay (sweep angle) ver
      int weight = _calculateNodeWeightForPreview(node);
      // Toplam pasta 360 derece (2 * pi)
      double sweepAngle = (weight / totalWeight) * 2 * math.pi;

      // Bu dalı, kendisine ayrılan açının tam ortasından geçirerek yerleştir
      _layoutRecursiveForPreview(
          node,
          currentAngle,
          sweepAngle,
          level1Distance, // İlk seviye mesafesi
          center
      );

      // Bir sonraki dal için açıyı kaydır
      currentAngle += sweepAngle;
    }
  }

  /// Özyinelemeli (Recursive) Yerleştirme - Önizleme için
  void _layoutRecursiveForPreview(
      MindMapNode node,
      double startAngle,
      double sweep,
      double distanceCtx,
      Offset center
      ) {
    // 1. Düğümü kendisine ayrılan açının (sweep) merkezine yerleştir
    double midAngle = startAngle + (sweep / 2);

    // Konumu MERKEZE göre hesapla (Ray Layout)
    node.position = Offset(
        center.dx + distanceCtx * math.cos(midAngle),
        center.dy + distanceCtx * math.sin(midAngle)
    );
    _previewNodePositions.add(node.position);

    if (node.children.isEmpty) return;

    // 2. Çocukları yerleştirmek için hazırlık
    int childTotalWeight = 0;
    for (var child in node.children) {
      childTotalWeight += _calculateNodeWeightForPreview(child);
    }

    // 3. Mesafeyi (Radius) Hesapla - Çakışmayı Önleyen Kısım
    double minArcLengthPerChild = 140.0; // Kartın dikeyde kapladığı minimum alan + boşluk
    double calculatedDistance = distanceCtx + 220.0; // Standart artış

    // Eğer açı çok küçükse (kalabalık dal) mesafeyi artır
    if (childTotalWeight > 0) {
      // Ortalama çocuk başına düşen açı
      double avgAnglePerChild = sweep / node.children.length;

      // Sıfıra bölünmeyi önle
      if (avgAnglePerChild > 0.01) {
        double requiredDistance = minArcLengthPerChild / avgAnglePerChild;

        // Çok aşırı uzamaması için bir limit koy ama gerekirse uzat
        if (requiredDistance > calculatedDistance) {
          // Örneğin max 2000px ekstra uzasın
          calculatedDistance = math.min(requiredDistance, distanceCtx + 1200);
        }
      }
    }

    double currentChildAngle = startAngle;

    for (var child in node.children) {
      child.color = node.color; // Rengi miras al

      int weight = _calculateNodeWeightForPreview(child);
      // Ebeveynin açısını, çocuğun ağırlığına göre paylaştır
      double childSweep = (weight / childTotalWeight) * sweep;

      _layoutRecursiveForPreview(child, currentChildAngle, childSweep, calculatedDistance, center);

      currentChildAngle += childSweep;
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
      // Gerçek ekranla aynı değerler
      paint.color = child.color.withValues(alpha: 0.6);
      paint.strokeWidth = (node.type == NodeType.root ? 3.0 : 1.5) * scale;

      final p1 = Offset(
        (node.position.dx - 3000) * scale + offsetX,
        (node.position.dy - 3000) * scale + offsetY,
      );
      final p2 = Offset(
        (child.position.dx - 3000) * scale + offsetX,
        (child.position.dy - 3000) * scale + offsetY,
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
// LaTeX Syntax Sınıfları (Question Solver'daki gibi)
// -----------------------------------------------------------------------------

class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[^$]*\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final match0 = match.group(0)!;
    final isDisplay = match0.startsWith(r'$$');
    final raw = isDisplay
        ? match0.substring(2, match0.length - 2)
        : match0.substring(1, match0.length - 1);
    final el = md.Element.text('latex', raw);
    el.attributes['mathStyle'] = isDisplay ? 'display' : 'text';
    parser.addNode(el);
    return true;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;
  LatexElementBuilder({this.textStyle});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final bool isDisplay = element.attributes['mathStyle'] == 'display';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: isDisplay ? Alignment.center : Alignment.centerLeft,
      child: Math.tex(
        element.textContent,
        textStyle: textStyle ?? preferredStyle,
        mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
        onErrorFallback: (err) => Text(
          element.textContent,
          style: (textStyle ?? preferredStyle)?.copyWith(color: Colors.red),
        ),
      ),
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