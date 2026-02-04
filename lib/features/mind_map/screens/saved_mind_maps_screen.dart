// lib/features/mind_map/screens/saved_mind_maps_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/mind_map/screens/mind_map_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class SavedMindMapsScreen extends ConsumerWidget {
  const SavedMindMapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kaydedilmiş Zihin Haritaları')),
        body: const Center(child: Text('Kullanıcı bulunamadı')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text('Kaydedilmiş Zihin Haritaları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ref.read(firestoreServiceProvider).getSavedMindMaps(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Hata: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final mindMaps = snapshot.data ?? [];

          if (mindMaps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hub_outlined, size: 80, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz kayıtlı zihin haritası yok',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Zihin Haritası Oluştur'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
                color: const Color(0xFF1A1D21),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.hub, color: Colors.amber),
                  ),
                  title: Text(
                    topic,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subject.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subject,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF2A2D31),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1D21),
                            title: const Text(
                              'Sil',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: Text(
                              '$topic zihin haritasını silmek istediğinize emin misiniz?',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
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
                              const SnackBar(
                                content: Text('Zihin haritası silindi'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Sil', style: TextStyle(color: Colors.white)),
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
    try {
      final data = mindMapData['mindMapData'] as Map<String, dynamic>?;
      if (data == null) return;

      // JSON'dan MindMapNode oluştur
      final rootNode = MindMapNode.fromJson(data, NodeType.root);

      // Layout hesapla
      _calculateLayout(rootNode);

      // Provider'a set et
      ref.read(mindMapNodeProvider.notifier).state = rootNode;

      // Geri dön
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yükleme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _calculateLayout(MindMapNode root) {
    const center = Offset(2000, 2000);
    const level1Distance = 250.0;
    const level2Distance = 200.0;

    root.position = center;
    root.color = Colors.amber;

    final mainBranches = root.children;
    final angleStep = (2 * 3.14159265359) / (mainBranches.isEmpty ? 1 : mainBranches.length);

    final colors = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.tealAccent
    ];

    for (int i = 0; i < mainBranches.length; i++) {
      final angle = i * angleStep;
      final node = mainBranches[i];

      node.position = Offset(
        center.dx + level1Distance * math.cos(angle),
        center.dy + level1Distance * math.sin(angle),
      );
      node.color = colors[i % colors.length];

      _layoutChildren(node, angle, level2Distance);
    }
  }

  void _layoutChildren(MindMapNode parent, double parentAngle, double distance) {
    if (parent.children.isEmpty) return;

    final childCount = parent.children.length;
    const wedgeSize = 3.14159265359 / 2.0;
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

