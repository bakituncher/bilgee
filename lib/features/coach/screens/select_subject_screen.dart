import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/utils/exam_utils.dart';
import 'package:taktik/utils/subject_utils.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class SelectSubjectScreen extends ConsumerWidget {
  const SelectSubjectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    if (user == null || user.selectedExam == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _EmptyStateWidget(
          icon: Icons.assignment_outlined,
          title: 'Sınav Seçilmedi',
          message: 'Devam etmek için önce bir sınav türü seçmelisin.',
          actionLabel: 'Sınav Seç',
          onAction: () => context.pop(),
        ),
      );
    }
    final examType = ExamType.values.byName(user.selectedExam!);
    return FutureBuilder<Exam>(
      future: ExamData.getExamByType(examType),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: _LoadingStateWidget(),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: _EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Bir Hata Oluştu',
              message: 'Dersler yüklenirken bir sorun oluştu. Lütfen tekrar dene.',
              actionLabel: 'Geri Dön',
              onAction: () => context.pop(),
            ),
          );
        }
        final exam = snap.data!;
        final relevantSections = ExamUtils.getRelevantSectionsForUser(user, exam);
        // Eğer hiçbir bölüm yoksa boş durumu göster
        final hasAnySubject = relevantSections.any((s) => s.subjects.isNotEmpty);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: !hasAnySubject
              ? _EmptyStateWidget(
                  icon: Icons.school_outlined,
                  title: 'Ders Bulunamadı',
                  message: 'Seçtiğin sınav türü için henüz ders bulunmuyor.',
                  actionLabel: 'Geri Dön',
                  onAction: () => context.pop(),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(context, user.selectedExam!),
                    _buildHeroSection(context, _countSubjects(relevantSections)),
                    _buildGroupedSections(context, relevantSections, exam.type),
                  ],
                ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, String examType) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: const CustomBackButton(),
      title: Text(
        'Ders Seçimi',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeroSection(BuildContext context, int subjectCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF22D3EE).withValues(alpha: 0.08),
                    const Color(0xFF6366F1).withValues(alpha: 0.08),
                  ]
                : [
                    const Color(0xFF22D3EE).withValues(alpha: 0.06),
                    const Color(0xFF6366F1).withValues(alpha: 0.06),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 0.8,
          ),
        ),
        child: Center(
          child: Text(
            'Test eklemek istediğin dersi seç',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // Güncel: Bölüm başlıkları altında ders kartları, YKS için TYT/AYT ayrı grup başlıkları
  Widget _buildGroupedSections(BuildContext context, List<ExamSection> sections, ExamType examType) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final section = sections[index];
            final subjectEntries = section.subjects.entries.toList();
            if (subjectEntries.isEmpty) {
              return const SizedBox.shrink();
            }

            final isYks = examType == ExamType.yks;
            final isLgs = examType == ExamType.lgs;
            final isKpss = examType == ExamType.kpssLisans || examType == ExamType.kpssOnlisans || examType == ExamType.kpssOrtaogretim;
            final isTyt = section.name.trim().toUpperCase() == 'TYT';
            final isAyt = section.name.trim().toUpperCase().startsWith('AYT');

            final lgsName = section.name.trim();
            final isSozel = isLgs && lgsName.toLowerCase().contains('sözel');
            final isSayisal = isLgs && lgsName.toLowerCase().contains('sayısal');

            // KPSS için dersleri iki alt gruba ayır: Genel Yetenek ve Genel Kültür
            List<MapEntry<String, SubjectDetails>> genelYetenekSubjects = [];
            List<MapEntry<String, SubjectDetails>> genelKulturSubjects = [];
            if (isKpss) {
              for (final e in subjectEntries) {
                final keyLower = e.key.toLowerCase();
                if (keyLower.contains('genel yetenek')) {
                  genelYetenekSubjects.add(e);
                } else if (keyLower.contains('genel kültür') || keyLower.contains('genel kultur')) {
                  genelKulturSubjects.add(e);
                } else {
                  // Etiket içermeyenleri akıllıca dağıt: Türkçe/Matematik -> Genel Yetenek, Tarih/Coğrafya/Vatandaşlık/Güncel -> Genel Kültür
                  if (keyLower.contains('türkçe') || keyLower.contains('matematik')) {
                    genelYetenekSubjects.add(e);
                  } else {
                    genelKulturSubjects.add(e);
                  }
                }
              }
            }

            // KPSS başlık metnini daha okunur yapmak için küçük düzenleme (fallback)
            final kpssHeader = section.name.replaceAll(' - ', ' & ');

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isYks && (isTyt || isAyt))
                    _ExamGroupHeader(title: isTyt ? 'TYT' : 'AYT')
                  else if (isLgs && (isSozel || isSayisal))
                    _ExamGroupHeader(title: isSozel ? 'Sözel' : 'Sayısal')
                  else if (!isKpss)
                    _SectionHeader(title: section.name)
                  else if (isKpss && genelYetenekSubjects.isEmpty && genelKulturSubjects.isEmpty)
                    _ExamGroupHeader(title: kpssHeader),

                  // KPSS: Genel Yetenek alt grubu
                  if (isKpss && genelYetenekSubjects.isNotEmpty) ...[
                    _ExamGroupHeader(title: 'Genel Yetenek'),
                    const SizedBox(height: 10),
                    ...List.generate(genelYetenekSubjects.length, (i) {
                      final subjectName = genelYetenekSubjects[i].key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (i * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: _SubjectCard(
                            subject: subjectName,
                            index: i,
                            onTap: () {
                              final route = Uri(
                                path: '/coach',
                                queryParameters: {'subject': subjectName},
                              ).toString();
                              context.go(route);
                            },
                          ),
                        ),
                      );
                    }),
                  ],

                  // KPSS: Genel Kültür alt grubu
                  if (isKpss && genelKulturSubjects.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ExamGroupHeader(title: 'Genel Kültür'),
                    const SizedBox(height: 10),
                    ...List.generate(genelKulturSubjects.length, (i) {
                      final subjectName = genelKulturSubjects[i].key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (i * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: _SubjectCard(
                            subject: subjectName,
                            index: i,
                            onTap: () {
                              final route = Uri(
                                path: '/coach',
                                queryParameters: {'subject': subjectName},
                              ).toString();
                              context.go(route);
                            },
                          ),
                        ),
                      );
                    }),
                  ],

                  // Diğer sınavlarda normal listeleme
                  if (!isKpss) ...[
                    const SizedBox(height: 10),
                    ...List.generate(subjectEntries.length, (i) {
                      final subjectName = subjectEntries[i].key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (i * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: _SubjectCard(
                            subject: subjectName,
                            index: i,
                            onTap: () {
                              final route = Uri(
                                path: '/coach',
                                queryParameters: {'subject': subjectName},
                              ).toString();
                              context.go(route);
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
          childCount: sections.length,
        ),
      ),
    );
  }

  int _countSubjects(List<ExamSection> sections) {
    int total = 0;
    for (final s in sections) {
      total += s.subjects.length;
    }
    return total;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF34D399).withValues(alpha: 0.18),
                  const Color(0xFF10B981).withValues(alpha: 0.18),
                ]
              : [
                  const Color(0xFF34D399).withValues(alpha: 0.12),
                  const Color(0xFF10B981).withValues(alpha: 0.12),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.layers_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamGroupHeader extends StatelessWidget {
  final String title;
  const _ExamGroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF6366F1).withValues(alpha: 0.18),
                  const Color(0xFF22D3EE).withValues(alpha: 0.18),
                ]
              : [
                  const Color(0xFF6366F1).withValues(alpha: 0.12),
                  const Color(0xFF22D3EE).withValues(alpha: 0.12),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.layers_rounded,
              color: Color(0xFF6366F1),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatefulWidget {
  final String subject;
  final int index;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.index,
    required this.onTap,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _isHovered = false;


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // SubjectUtils'den dinamik renk ve ikon çekiliyor
    final subjectColor = SubjectUtils.getSubjectColor(widget.subject, colorScheme: cs);
    final subjectIcon = SubjectUtils.getSubjectIcon(widget.subject);

    final scale = _isHovered ? 1.01 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(scale, scale, 1.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? cs.surfaceContainerHighest : cs.surface,
                border: Border.all(
                  color: _isHovered
                      ? subjectColor.withValues(alpha: 0.4)
                      : cs.outlineVariant.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: _isHovered
                          ? subjectColor.withValues(alpha: 0.15)
                          : cs.shadow.withValues(alpha: 0.06),
                      blurRadius: _isHovered ? 16 : 8,
                      offset: Offset(0, _isHovered ? 4 : 2),
                    ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: subjectColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      subjectIcon,
                      color: subjectColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.subject,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              letterSpacing: -0.2,
                            ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(_isHovered ? 4 : 0, 0, 0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: _isHovered
                          ? subjectColor
                          : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingStateWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF22D3EE).withValues(alpha: 0.2),
                    const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: const Color(0xFF22D3EE),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Dersler yükleniyor...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lütfen bekle',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF22D3EE).withValues(alpha: 0.2),
                      const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 56,
                  color: const Color(0xFF22D3EE),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22D3EE),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                  shadowColor: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
