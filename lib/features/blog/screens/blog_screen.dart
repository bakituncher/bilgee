// lib/features/blog/screens/blog_screen.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/blog/providers/blog_providers.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlogScreen extends ConsumerWidget {
  const BlogScreen({super.key});

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(blogPostsStreamProvider);
    final dateFmt = DateFormat('d MMM y', 'tr');
    final isAdminAsync = ref.watch(adminClaimProvider);
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    final isSuperAdminEmail = email == 'baki@gmail.com';

    Future<void> requestSelfAdmin() async {
      try {
        final functions = ref.read(functionsProvider);
        await functions.httpsCallable('setSelfAdmin').call();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        ref.invalidate(adminClaimProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin yetkisi verildi. Tekrar deneyin.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
        }
      }
    }

    Widget? buildFab() {
      return isAdminAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (isAdmin) {
          if (isAdmin == true) {
            return FloatingActionButton.extended(
              onPressed: () => context.go('/blog/admin/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni Yazı'),
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: AppTheme.primaryColor,
            );
          }
          // Admin değilse, self-claim butonunu her zaman göster
          return FloatingActionButton.extended(
            onPressed: requestSelfAdmin,
            icon: const Icon(Icons.verified_user_rounded),
            label: const Text('Admin Yetkisi Al'),
            backgroundColor: AppTheme.successColor,
            foregroundColor: Colors.white,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilgelik Yazıları'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: () => _handleBack(context),
        ),
      ),
      floatingActionButton: buildFab(),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Yazılar yüklenemedi: $e')),
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(child: Text('Henüz yayınlanmış yazı yok.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = posts[i];
              return Card(
                elevation: 6,
                shadowColor: AppTheme.lightSurfaceColor.withValues(alpha: .4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go('/blog/${p.slug}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CachedNetworkImage(
                            imageUrl: p.coverImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (c, _) => Container(color: AppTheme.lightSurfaceColor.withValues(alpha: .3)),
                            errorWidget: (c, _, __) => Container(color: AppTheme.lightSurfaceColor.withValues(alpha: .2), child: const Icon(Icons.image_not_supported_rounded)),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (p.excerpt != null && p.excerpt!.isNotEmpty)
                              Text(
                                p.excerpt!,
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 16, color: AppTheme.secondaryTextColor),
                                const SizedBox(width: 6),
                                Text(
                                  [
                                    if (p.publishedAt != null) dateFmt.format(p.publishedAt!),
                                    if (p.readTime != null) '${p.readTime} dk'
                                  ].join(' • '),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor),
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 250.ms).slideY(begin: .05, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }
}
