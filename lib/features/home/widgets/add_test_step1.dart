// lib/features/home/widgets/add_test_step1.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/features/home/logic/add_test_notifier.dart';

class Step1TestInfo extends ConsumerWidget {
  const Step1TestInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addTestProvider);
    final notifier = ref.read(addTestProvider.notifier);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Buton aktiflik kontrolü
    final isButtonEnabled = state.testName.trim().isNotEmpty &&
        (state.selectedSection != null || (state.isBranchMode && state.selectedBranchSubject != null));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              /// HEADER
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 28,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Yeni Deneme Ekle",
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Denemenin temel bilgilerini gir",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// MODE TOGGLE - Modern Segmented Control
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeToggleButton(
                        label: "Genel Deneme",
                        icon: Icons.library_books_rounded,
                        isSelected: !state.isBranchMode,
                        onTap: () {
                          notifier.setBranchMode(false);
                          if (state.selectedSection == null && state.availableSections.isNotEmpty) {
                            notifier.setSection(state.availableSections.first);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ModeToggleButton(
                        label: "Branş Denemesi",
                        icon: Icons.school_rounded,
                        isSelected: state.isBranchMode,
                        onTap: () {
                          notifier.setBranchMode(true);
                          if (state.selectedSection == null && state.availableSections.isNotEmpty) {
                            notifier.setSection(state.availableSections.first);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// TEST NAME (Her iki modda da gerekli)
              Text(
                "Deneme Adı",
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: state.testName,
                style: textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: state.isBranchMode
                      ? "Örn: Tarih Branş Denemesi"
                      : "Örn: 3D Yayınları 5. Deneme",
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.description_outlined,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: notifier.setTestName,
              ),

              const SizedBox(height: 24),

              /// MODE SELECTION AREA
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: state.isBranchMode
                      ? _buildBranchMode(context, state, notifier)
                      : _buildGeneralMode(context, state, notifier),
                ),
              ),
            ]
                .animate(interval: 50.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.1),
          ),
        ),

        /// CTA - Sabit Buton
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface.withValues(alpha: 0.0),
                theme.colorScheme.surface,
              ],
              stops: const [0.0, 0.3],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isButtonEnabled ? notifier.nextStep : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: isButtonEnabled ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onPrimary,
                    disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                    disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Netleri Girmeye Başla",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- GENEL DENEME MODU GÖRÜNÜMÜ ---
  Widget _buildGeneralMode(BuildContext context, AddTestState state, AddTestNotifier notifier) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('general_mode'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.library_books_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(
              "Sınav Türü Seç",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Sınav türü seçimi
        ...state.availableSections.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SectionSelectionCard(
              section: section,
              isSelected: state.selectedSection == section,
              onTap: () => notifier.setSection(section),
            ),
          ),
        ),
      ],
    );
  }

  // --- BRANŞ DENEMESİ MODU GÖRÜNÜMÜ ---
  Widget _buildBranchMode(BuildContext context, AddTestState state, AddTestNotifier notifier) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('branch_mode'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ders Seçimi
        Row(
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(
              "Ders Seçimi",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Ders seçimi butonu
        InkWell(
          onTap: () => _showSubjectBottomSheet(context, state, notifier, theme),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: state.selectedBranchSubject != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: state.selectedBranchSubject != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  state.selectedBranchSubject != null
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: state.selectedBranchSubject != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    state.selectedBranchSubject ?? "Ders Seç",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: state.selectedBranchSubject != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Bottom sheet for subject selection - Tüm bölümlerdeki tüm dersleri göster
  void _showSubjectBottomSheet(
    BuildContext context,
    AddTestState state,
    AddTestNotifier notifier,
    ThemeData theme,
  ) {
    // Tüm bölümlerden tüm dersleri topla
    final Map<String, List<String>> allSubjectsBySection = {};
    for (final section in state.availableSections) {
      allSubjectsBySection[section.name] = section.subjects.keys.toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Ders Seçin",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Subject list grouped by section
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                itemCount: allSubjectsBySection.length,
                itemBuilder: (context, index) {
                  final sectionName = allSubjectsBySection.keys.elementAt(index);
                  final subjects = allSubjectsBySection[sectionName]!;
                  final section = state.availableSections.firstWhere((s) => s.name == sectionName);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bölüm Başlığı
                      if (allSubjectsBySection.length > 1) ...[
                        Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8, top: index > 0 ? 16 : 0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sectionName,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Dersler
                      ...subjects.map((subject) {
                        final isSelected = state.selectedBranchSubject == subject;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              // Dersi seç ve ilgili bölümü de seç
                              notifier.setSection(section);
                              notifier.setBranchSubject(subject);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      subject,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? theme.colorScheme.onPrimaryContainer
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Yardımcı Kart Widget'ı (Değişmedi)
class _SectionSelectionCard extends StatelessWidget {
  final ExamSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionSelectionCard({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: 24,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Text(
                section.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Modern Segmented Control Button Widget
class _ModeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
