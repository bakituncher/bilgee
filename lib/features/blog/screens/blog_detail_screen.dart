// lib/features/blog/screens/blog_detail_screen.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:bilge_ai/features/blog/providers/blog_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

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

    Future<void> _deletePost() async {
      final post = postForActions;
      if (post == null) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Yazıyı sil'),
          content: Text('"${post.title}" kalıcı olarak silinsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Vazgeç')),
            ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Sil')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yazı'),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
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
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Sil',
              onPressed: _deletePost,
            ),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Yazı yüklenemedi: $e')),
        data: (post) {
          if (post == null) {
            return const Center(child: Text('Yazı bulunamadı.'));
          }

          final chips = post.tags.map((t) => Chip(
                label: Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: .25),
                shape: StadiumBorder(side: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .4))),
              ));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.coverImageUrl != null && post.coverImageUrl!.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'post-cover-${post.slug}',
                              child: CachedNetworkImage(
                                imageUrl: post.coverImageUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0x880D1B2A),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.secondaryTextColor),
                              const SizedBox(width: 6),
                              Text(post.author ?? 'BilgeAI', style: TextStyle(color: AppTheme.secondaryTextColor)),
                              const SizedBox(width: 12),
                              Icon(Icons.schedule_rounded, size: 16, color: AppTheme.secondaryTextColor),
                              const SizedBox(width: 6),
                              Text(
                                [
                                  if (post.publishedAt != null) dateFmt.format(post.publishedAt!),
                                  if (post.readTime != null) '${post.readTime} dk'
                                ].join(' • '),
                                style: TextStyle(color: AppTheme.secondaryTextColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (post.tags.isNotEmpty)
                            Wrap(spacing: 8, runSpacing: -6, children: chips.toList()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: MarkdownBody(
                    data: post.contentMarkdown,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.montserrat(fontSize: 16, height: 1.6),
                      h1: GoogleFonts.playfairDisplay(fontSize: 30, fontWeight: FontWeight.w800),
                      h2: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.w800),
                      h3: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w800),
                      h4: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700),
                      code: GoogleFonts.robotoMono(fontSize: 13, color: AppTheme.secondaryColor),
                      blockquote: GoogleFonts.montserrat(fontStyle: FontStyle.italic, color: AppTheme.secondaryTextColor),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(left: BorderSide(color: AppTheme.secondaryColor, width: 3)),
                      ),
                      listBullet: TextStyle(color: AppTheme.secondaryColor),
                      a: const TextStyle(color: Color(0xFF55C1FF)),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .6), width: 1)),
                      ),
                    ),
                    sizedImageBuilder: (image) {
                      final uri = image.uri;
                      final height = (image.height?.toDouble() ?? 180).clamp(80, 1200);
                      return SizedBox(
                        width: double.infinity,
                        height: height as double,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: uri.toString(),
                            fit: BoxFit.cover,
                            placeholder: (c, _) => Container(
                              color: AppTheme.lightSurfaceColor.withValues(alpha: .25),
                            ),
                            errorWidget: (c, _, __) => Container(
                              alignment: Alignment.center,
                              color: AppTheme.lightSurfaceColor.withValues(alpha: .2),
                              child: const Icon(Icons.image_not_supported_rounded),
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
