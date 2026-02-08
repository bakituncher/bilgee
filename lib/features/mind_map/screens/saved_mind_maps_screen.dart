// lib/features/mind_map/screens/saved_mind_maps_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/mind_map/screens/mind_map_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class SavedMindMapsScreen extends ConsumerStatefulWidget {
  const SavedMindMapsScreen({super.key});

  @override
  ConsumerState<SavedMindMapsScreen> createState() => _SavedMindMapsScreenState();
}

class _SavedMindMapsScreenState extends ConsumerState<SavedMindMapsScreen> {
  // Global pozisyon listesi (Sadece referans için tutulur, yeni algoritmada çakışma kontrolü gerekmez)
  final List<Offset> _allNodePositions = [];

  // Layout sabitleri (Ana ekranla aynı olmalı)
  static const Offset _center = Offset(3000, 3000);
  static const double _level1Distance = 350.0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Zihin Haritalarım'),
          leading: const CustomBackButton(),
          scrolledUnderElevation: 0,
        ),
        body: const Center(child: Text('Kullanıcı bulunamadı')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Zihin Haritalarım'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomBackButton(),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ref.read(firestoreServiceProvider).getSavedMindMaps(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Hata: ${snapshot.error}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final mindMaps = snapshot.data ?? [];

          if (mindMaps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hub_outlined, size: 80, color: colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz kayıtlı zihin haritası yok',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Zihin Haritası Oluştur'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: mindMaps.length,
            itemBuilder: (context, index) {
              final mindMap = mindMaps[index];
              final topic = mindMap['topic'] as String? ?? 'İsimsiz';
              final subject = mindMap['subject'] as String? ?? '';
              final createdAt = mindMap['createdAt'];
              final dateStr = createdAt != null
                  ? DateFormat('dd MMM yyyy, HH:mm', 'tr').format(createdAt.toDate())
                  : '';

              return Card(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surface,
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isDark ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.hub, color: colorScheme.primary),
                  ),
                  title: Text(
                    topic,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subject.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subject,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                    color: isDark
                        ? colorScheme.surfaceContainerHigh
                        : colorScheme.surface,
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isDark
                                ? colorScheme.surfaceContainerHigh
                                : colorScheme.surface,
                            title: Text(
                              'Sil',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                            content: Text(
                              '$topic zihin haritasını silmek istediğinize emin misiniz?',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.error,
                                ),
                                child: const Text('Sil'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await ref
                              .read(firestoreServiceProvider)
                              .deleteMindMap(user.id, mindMap['id']);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Zihin haritası silindi'),
                                backgroundColor: colorScheme.primary,
                              ),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                            const SizedBox(width: 12),
                            Text('Sil', style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Zihin haritasını yükle ve göster
                    _loadAndShowMindMap(context, ref, mindMap);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _loadAndShowMindMap(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic> mindMapData,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    try {
      final data = mindMapData['mindMapData'] as Map<String, dynamic>?;
      if (data == null) return;

      // JSON'dan MindMapNode oluştur
      final rootNode = MindMapNode.fromJson(data, NodeType.root);

      // YENİ LAYOUT ALGORİTMASI İLE HESAPLA
      _calculateLayout(rootNode);

      // Bu kullanıcı tarafından kaydedilmiş bir harita, tekrar kaydedilebilir
      ref.read(isPreMadeMapProvider.notifier).state = false;

      // Hash hesapla ve provider'a kaydet
      // Bu harita Firestore'dan geldiği için zaten kaydedilmiş demektir
      final hash = _calculateMapHash(rootNode);
      ref.read(savedMapHashProvider.notifier).state = hash;

      // Provider'a set et
      ref.read(mindMapNodeProvider.notifier).state = rootNode;

      // Geri dön
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yükleme hatası: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  String _calculateMapHash(MindMapNode node) {
    final json = jsonEncode(node.toJson());
    return json.hashCode.toString();
  }

  // ---------------------------------------------------------------------------
  // YENİ LAYOUT ALGORİTMASI (MindMapScreen ile Birebir Aynı)
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
}