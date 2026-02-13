// lib/features/blog/screens/blog_detail_screen.dart
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/features/blog/providers/blog_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class BlogDetailScreen extends ConsumerWidget {
  final String slug;
  const BlogDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(blogPostBySlugProvider(slug));
    final isAdminAsync = ref.watch(adminClaimProvider);
    final isAdmin = isAdminAsync.asData?.value ?? false;
    final postForActions = postAsync.asData?.value; // null olabilir
    final dateFmt = DateFormat('d MMM y', 'tr');

    Future<void> deletePost() async {
      final post = postForActions;
      if (post == null) return;

      // ÇÖZÜM 1: Dialog'u root navigator (en üst katman) üzerinde açıyoruz.
      // Böylece navigasyon barın üzerinde görünür.
      final ok = await showDialog<bool>(
        context: context,
        useRootNavigator: true, // <-- KRİTİK EKLEME
        builder: (c) => AlertDialog(
          title: const Text('Yazıyı sil'),
          content: Text('"${post.title}" kalıcı olarak silinsin mi?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Vazgeç')
            ),
            ElevatedButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Sil')
            ),
          ],
        ),
      );

      if (ok != true) return;

      try {
        await FirebaseFirestore.instance.collection('posts').doc(post.id).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yazı silindi.')));
          context.go('/blog');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
        }
      }
    }

    // Alt navigasyon çubuğu ve güvenli alan (iPhone home indicator vb.) yüksekliği
    // İçeriğin en altta kesilmemesi için kullanılır.
    final bottomPadding = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Blog', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: true,
        leading: CustomBackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/blog');
            }
          },
        ),
        actions: [
          if (isAdmin && postForActions != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 24),
              tooltip: 'Sil',
              onPressed: deletePost,
            ),
        ],
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Yazı yüklenemedi: $e')),
        data: (post) {
          if (post == null) {
            return const Center(child: Text('Yazı bulunamadı.'));
          }

          final chips = post.tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.only(right: 8, bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                  Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              t,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.coverImageUrl != null && post.coverImageUrl!.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 1.5,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'post-cover-${post.slug}',
                              child: CachedNetworkImage(
                                imageUrl: post.coverImageUrl!,
                                fit: BoxFit.cover,
                                maxHeightDiskCache: 1080,
                                maxWidthDiskCache: 1920,
                                memCacheHeight: 720,
                                memCacheWidth: 1280,
                                placeholder: (c, _) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                        Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                ),
                                errorWidget: (c, _, __) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
                                        Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.2),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(Icons.image_not_supported_rounded, size: 64),
                                ),
                              ),
                            ),
                            // Subtle gradient overlay at bottom
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Theme.of(context).colorScheme.surface.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.tags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Wrap(children: chips.toList()),
                            ),
                          Text(
                            post.title,
                            style: GoogleFonts.montserrat(
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                        Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Taktik Ekibi',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (post.publishedAt != null) dateFmt.format(post.publishedAt!),
                                          if (post.readTime != null) '${post.readTime} dk okuma'
                                        ].join(' • '),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
                  child: MarkdownBody(
                    data: post.contentMarkdown,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.montserrat(
                        fontSize: 16,
                        height: 1.75,
                        letterSpacing: 0.2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      h1: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                      h2: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                      h3: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.2,
                      ),
                      h4: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                      h1Padding: const EdgeInsets.only(top: 24, bottom: 12),
                      h2Padding: const EdgeInsets.only(top: 20, bottom: 10),
                      h3Padding: const EdgeInsets.only(top: 18, bottom: 8),
                      h4Padding: const EdgeInsets.only(top: 16, bottom: 8),
                      code: GoogleFonts.montserrat(
                        fontSize: 14,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      ),
                      codeblockPadding: const EdgeInsets.all(16),
                      codeblockDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                            Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      blockquote: GoogleFonts.montserrat(
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        height: 1.7,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      blockquoteDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
                            Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.1),
                          ],
                        ),
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.secondary,
                            width: 4,
                          ),
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      listBullet: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      a: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      ),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      img: GoogleFonts.montserrat(),
                      tableHead: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                      tableBody: GoogleFonts.montserrat(),
                    ),
                    sizedImageBuilder: (image) {
                      final uri = image.uri;
                      final height = (image.height?.toDouble() ?? 220).clamp(120, 1200);
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: uri.toString(),
                            fit: BoxFit.cover,
                            height: height as double,
                            width: double.infinity,
                            placeholder: (c, _) => Container(
                              height: height,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.3),
                                  ],
                                ),
                              ),
                            ),
                            errorWidget: (c, _, __) => Container(
                              height: height,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
                                    Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.image_not_supported_rounded, size: 48),
                            ),
                          ),
                        ),
                      );
                    },
                    onTapLink: (text, href, title) {
                      // İsteğe bağlı: link tıklama
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

