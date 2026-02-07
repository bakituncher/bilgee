// lib/features/blog/screens/blog_screen.dart
import 'dart:async';
import 'package:taktik/features/blog/providers/blog_providers.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/blog/models/blog_post.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

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
  bool _hasCheckedReviewPrompt = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // İlk render sonrası review teşvikini kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowReviewPrompt();
    });
  }

  Future<void> _checkAndShowReviewPrompt() async {
    if (_hasCheckedReviewPrompt || !mounted) return;
    _hasCheckedReviewPrompt = true;

    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final hasShownBlogReview = prefs.getBool('blog_review_prompt_shown4') ?? false;

      // Eğer daha önce gösterildiyse tekrar gösterme
      if (hasShownBlogReview) return;

      // 1.5 saniye bekle, sonra göster (kullanıcı ekranı inceleyebilsin)
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      await _showReviewPrompt();
      await prefs.setBool('blog_review_prompt_shown4', true);
    } catch (_) {
      // Hata durumunda sessiz kal
    }
  }

  Future<void> _showReviewPrompt() async {
    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // First step: Ask if they like the app
    final liked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest.withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Animated emoji icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.15),
                          colorScheme.secondary.withOpacity(0.15),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '💙',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Taktik\'i beğendin mi?',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Görüşlerin bizim için çok değerli! 🙏',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Choice buttons with icons
                  Row(
                    children: [
                      // Dislike button
                      Expanded(
                        child: _buildChoiceButton(
                          context: ctx,
                          icon: Icons.sentiment_dissatisfied_rounded,
                          label: 'Beğenmedim',
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.errorContainer.withOpacity(0.3),
                              colorScheme.error.withOpacity(0.2),
                            ],
                          ),
                          iconColor: colorScheme.error,
                          onTap: () => Navigator.of(ctx).pop(false),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Like button
                      Expanded(
                        child: _buildChoiceButton(
                          context: ctx,
                          icon: Icons.favorite_rounded,
                          label: 'Beğendim',
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          iconColor: Colors.white,
                          textColor: Colors.white,
                          onTap: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Maybe later button
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    child: Text(
                      'Şimdi Değil',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, curve: Curves.easeOut);
      },
    );

    if (liked == null || !mounted) return;

    // Small delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 300));

    if (liked) {
      // User likes the app - Show review request
      await _showRatingDialog();
    }
    // Beğenmeyenler için hiçbir şey gösterme, sadece kapat
  }

  Widget _buildChoiceButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Gradient gradient,
    required Color iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: iconColor,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest.withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Success icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.2),
                          colorScheme.secondary.withOpacity(0.2),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Desteğin çok değerli! 🙏',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Görüşünü paylaşarak bize destek olabilirsin! 💙',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // Rate button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final InAppReview inAppReview = InAppReview.instance;

                          if (await inAppReview.isAvailable()) {
                            await inAppReview.requestReview();
                          } else {
                            await inAppReview.openStoreListing(
                              appStoreId: '6738746059',
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(28),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mağazada Değerlendir',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Maybe later
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    child: Text(
                      'Belki Sonra',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut);
      },
    );
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
      if (sel == 'yks') {
        examKey = 'yks';
      } else if (sel == 'lgs') examKey = 'lgs';
      else if (sel.startsWith('kpss')) examKey = 'kpss';
    }
    final dateFmt = DateFormat('d MMM y', 'tr');
    final isAdminAsync = ref.watch(adminClaimProvider);

    Widget? buildFab() {
      final isAdmin = isAdminAsync.asData?.value ?? false;
      if (!isAdmin) return null;

      return FloatingActionButton.extended(
        onPressed: () => context.go('/blog/admin/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Yazı'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        elevation: 4,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: CustomBackButton(onPressed: () => _handleBack(context)),
        title: const Text('Blog'),
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
            final key = examKey; // non-null garanti
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Search Bar - Instagram/Spotify Style
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Ara...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                              size: 22,
                            ),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: (v) => _onSearchChanged(v),
                        ),
                      ),
                      if (allTags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: allTags.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (c, i) {
                              final label = i == 0 ? 'Tümü' : allTags[i - 1];
                              final isSelected = i == 0 ? _selectedTag == null : _selectedTag?.toLowerCase() == label.toLowerCase();
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: FilterChip(
                                  label: Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onSecondary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() {
                                    _selectedTag = (i == 0) ? null : label;
                                  }),
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
                                  selectedColor: Theme.of(context).colorScheme.secondary,
                                  checkmarkColor: Theme.of(context).colorScheme.onSecondary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.secondary
                                          : Theme.of(context).colorScheme.outline.withOpacity(0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
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
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                  Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.article_outlined,
                              size: 56,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _query.isEmpty ? 'Henüz yazı yok' : 'Sonuç bulunamadı',
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _query.isEmpty
                                ? 'Blog yazıları yakında yayınlanacak.'
                                : 'Farklı bir arama deneyin.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
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
                          final t = p.tags.take(2).toList();
                          return t
                              .map<Widget>((tag) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                                          Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      tag,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ))
                              .toList(growable: false);
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: RepaintBoundary(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                elevation: 0,
                                borderRadius: BorderRadius.circular(24),
                                color: Theme.of(context).colorScheme.surface,
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => context.go('/blog/${p.slug}'),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                                        AspectRatio(
                                          aspectRatio: 1.5,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Hero(
                                                tag: 'post-cover-${p.slug}',
                                                child: CachedNetworkImage(
                                                  imageUrl: p.coverImageUrl!,
                                                  fit: BoxFit.cover,
                                                  maxHeightDiskCache: 720,
                                                  maxWidthDiskCache: 1280,
                                                  memCacheHeight: 480,
                                                  memCacheWidth: 854,
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
                                                    child: Icon(
                                                      Icons.image_not_supported_rounded,
                                                      size: 48,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Gradient overlay for readability
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                    colors: [
                                                      Colors.black.withOpacity(0.7),
                                                      Colors.black.withOpacity(0.3),
                                                      Colors.transparent,
                                                    ],
                                                    stops: const [0.0, 0.3, 0.7],
                                                  ),
                                                ),
                                              ),
                                              // Read time badge
                                              if (p.readTime != null)
                                                Positioned(
                                                  right: 16,
                                                  top: 16,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.6),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(
                                                        color: Colors.white.withOpacity(0.2),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.access_time_rounded, size: 14, color: Colors.white),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '${p.readTime} dk',
                                                          style: GoogleFonts.inter(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (p.tags.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 12),
                                                child: Wrap(children: buildTagChips()),
                                              ),
                                            Text(
                                              p.title,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                height: 1.2,
                                                letterSpacing: -0.3,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (p.excerpt != null && p.excerpt!.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                p.excerpt!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  height: 1.5,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 14,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  p.publishedAt != null ? dateFmt.format(p.publishedAt!) : '-',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (isAdmin)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: PopupMenuButton<String>(
                                                      icon: Icon(
                                                        Icons.more_horiz_rounded,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(16),
                                                      ),
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
                                                    ),
                                                  )
                                                else
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 20,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 250.ms, curve: Curves.easeOut).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut));
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
