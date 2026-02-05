// lib/features/mind_map/screens/saved_mind_maps_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/mind_map/screens/mind_map_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:convert';

class SavedMindMapsScreen extends ConsumerWidget {
  const SavedMindMapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zihin Haritalarım')),
        body: const Center(child: Text('Kullanıcı bulunamadı')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Zihin Haritalarım'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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

      // Layout hesapla
      _calculateLayout(rootNode);

      // Hash hesapla ve provider'a kaydet
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

