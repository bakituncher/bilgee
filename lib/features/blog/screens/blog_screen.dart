// lib/features/blog/screens/blog_screen.dart
import 'dart:async';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/features/blog/models/blog_post.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedTag;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = v);
    });
  }

  List<BlogPost> _filterPosts(List<BlogPost> posts) {
    final q = _query.trim().toLowerCase();
    final tag = _selectedTag?.toLowerCase();
    Iterable<BlogPost> res = posts;
    if (tag != null && tag.isNotEmpty) {
      res = res.where((p) => p.tags.any((t) => t.toLowerCase() == tag));
    }
    if (q.isNotEmpty) {
      res = res.where((p) {
        final inTitle = p.title.toLowerCase().contains(q);
        final inExcerpt = (p.excerpt ?? '').toLowerCase().contains(q);
        final inTags = p.tags.any((t) => t.toLowerCase().contains(q));
        return inTitle || inExcerpt || inTags;
      });
    }
    return res.toList(growable: false);
  }

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(blogPostsStreamProvider); // genel akış (geri uyumlu)
    final user = ref.watch(userProfileProvider).value; // sınav hedefi için
    String? examKey;
    final sel = user?.selectedExam?.toLowerCase();
    if (sel != null) {
      if (sel == 'yks') examKey = 'yks';
      else if (sel == 'lgs') examKey = 'lgs';
      else if (sel.startsWith('kpss')) examKey = 'kpss';
    }
    final dateFmt = DateFormat('d MMM y', 'tr');
    final isAdminAsync = ref.watch(adminClaimProvider);

    Future<void> requestSelfAdmin() async {
      try {
        final functions = ref.read(functionsProvider);
        await functions.httpsCallable('admin-setSelfAdmin').call();
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
          // Hedef kitle filtreleme (client-side): all, tam eşleşme veya startsWith eşleşme
          final targeted = posts.where((p) {
            final tg = p.targetExams.map((e) => e.toLowerCase()).toList();
            if (examKey == null) return true; // sınav seçilmemişse tümü
            final key = examKey!; // non-null garanti
            if (tg.contains('all')) return true;
            if (tg.contains(key)) return true;
            return tg.any((e) => e.startsWith(key));
          }).toList(growable: false);
          final List<BlogPost> filtered = _filterPosts(targeted);
          final allTags = {
            for (final p in targeted) ...p.tags.map((e) => e.trim())
          }.where((e) => e.isNotEmpty).toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(blogPostsStreamProvider);
              await ref.read(blogPostsStreamProvider.future);
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Yazı ara, etiket veya başlık...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppTheme.lightSurfaceColor.withValues(alpha: .18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: (v) => _onSearchChanged(v),
                        ),
                        if (allTags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: allTags.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (c, i) {
                                final label = i == 0 ? 'Tümü' : allTags[i - 1];
                                final isSelected = i == 0 ? _selectedTag == null : _selectedTag?.toLowerCase() == label.toLowerCase();
                                return ChoiceChip(
                                  label: Text(label),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() {
                                    _selectedTag = (i == 0) ? null : label;
                                  }),
                                  visualDensity: VisualDensity.compact,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty ? 'Henüz yayınlanmış yazı yok.' : 'Aramanızla eşleşen yazı bulunamadı.',
                              style: GoogleFonts.montserrat(fontSize: 16, color: AppTheme.secondaryTextColor),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final p = filtered[i];
                        final isAdmin = isAdminAsync.asData?.value ?? false;

                        Future<void> deletePost() async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Yazıyı sil'),
                              content: Text('"${p.title}" kalıcı olarak silinsin mi?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Vazgeç')),
                                ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Sil')),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          try {
                            await FirebaseFirestore.instance.collection('posts').doc(p.slug).delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yazı silindi.')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
                            }
                          }
                        }

                        List<Widget> buildTagChips() {
                          final t = p.tags.take(3).toList();
                          return t
                              .map<Widget>((tag) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Chip(
                                      label: Text(tag, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600)),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: .25),
                                      shape: StadiumBorder(side: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .4))),
                                    ),
                                  ))
                              .toList(growable: false);
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: RepaintBoundary(
                            child: Card(
                              elevation: 0, // AppTheme.cardTheme ile uyumlu: gölgeyi kaldır
                              shadowColor: AppTheme.lightSurfaceColor.withValues(alpha: .18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .45)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => context.go('/blog/${p.slug}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                                      AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Hero(
                                              tag: 'post-cover-${p.slug}',
                                              child: CachedNetworkImage(
                                                imageUrl: p.coverImageUrl!,
                                                fit: BoxFit.cover,
                                                placeholder: (c, _) => Container(color: AppTheme.lightSurfaceColor.withValues(alpha: .25)),
                                                errorWidget: (c, _, __) => Container(color: AppTheme.lightSurfaceColor.withValues(alpha: .2), child: const Icon(Icons.image_not_supported_rounded)),
                                              ),
                                            ),
                                            // Alt kısımda okunabilirlik için yumuşak degrade
                                            Container(
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [Color(0x990D1B2A), Colors.transparent],
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 10,
                                              bottom: 10,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF000000).withValues(alpha: .35),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
                                                    const SizedBox(width: 4),
                                                    Text('${p.readTime ?? 1} dk', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.title,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              height: 1.25,
                                              letterSpacing: .1,
                                              color: AppTheme.textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          if (p.excerpt != null && p.excerpt!.isNotEmpty)
                                            Text(
                                              p.excerpt!,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 13.5,
                                                height: 1.65,
                                                letterSpacing: .05,
                                                color: AppTheme.secondaryTextColor,
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          if (p.tags.isNotEmpty)
                                            Wrap(children: buildTagChips()),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.secondaryTextColor),
                                              const SizedBox(width: 6),
                                              Text(
                                                p.publishedAt != null ? dateFmt.format(p.publishedAt!) : '-',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor),
                                              ),
                                              const Spacer(),
                                              if (isAdmin)
                                                PopupMenuButton<String>(
                                                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.secondaryTextColor),
                                                  onSelected: (v) {
                                                    switch (v) {
                                                      case 'edit':
                                                        context.go('/blog/admin/edit/${p.slug}');
                                                        break;
                                                      case 'delete':
                                                        deletePost();
                                                        break;
                                                    }
                                                  },
                                                  itemBuilder: (c) => const [
                                                    PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                                    PopupMenuItem(value: 'delete', child: Text('Sil')),
                                                  ],
                                                )
                                              else
                                                const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 160.ms).slideY(begin: .05, curve: Curves.easeOut));
                      },
                      childCount: filtered.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
