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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        /// HEADER
        Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceVariant,
              ),
              child: Icon(
                state.isBranchMode ? Icons.category_rounded : Icons.edit_note_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.isBranchMode ? "Branş Denemesi" : "Yeni Deneme Ekle",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.isBranchMode
                  ? "Hangi dersin denemesini çözdün?"
                  : "Denemenin temel bilgilerini girerek başlayalım.",
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 40),

        /// TEST NAME (Her iki modda da gerekli)
        Text(
          "Deneme Adı",
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.testName,
          decoration: InputDecoration(
            hintText: "Örn: 3D Yayınları 5. Deneme",
            prefixIcon: Icon(
              Icons.description_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          onChanged: notifier.setTestName,
        ),

        const SizedBox(height: 32),

        /// MODE SELECTION AREA
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          firstChild: _buildGeneralMode(context, state, notifier),
          secondChild: _buildBranchMode(context, state, notifier),
          crossFadeState: state.isBranchMode
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
        ),

        const SizedBox(height: 48),

        /// CTA
        SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isButtonEnabled ? notifier.nextStep : null,
              style: ElevatedButton.styleFrom(
                elevation: isButtonEnabled ? 2 : 0,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor: theme.colorScheme.surfaceVariant,
                disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Netleri Girmeye Başla",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ]
          .animate(interval: 50.ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.1),
    );
  }

  // --- GENEL DENEME MODU GÖRÜNÜMÜ ---
  Widget _buildGeneralMode(BuildContext context, AddTestState state, AddTestNotifier notifier) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Deneme Türü",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Mevcut Bölümler (TYT, AYT vb.)
        ...state.availableSections.map(
              (section) => _SectionSelectionCard(
            section: section,
            isSelected: state.selectedSection == section && !state.isBranchMode,
            onTap: () {
              notifier.setBranchMode(false); // Garanti olsun
              notifier.setSection(section);
            },
          ),
        ),

        const SizedBox(height: 24),

        // --- VEYA --- Ayracı
        Row(
          children: [
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "VEYA",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
          ],
        ),

        const SizedBox(height: 24),

        // Branş Denemesi Butonu
        InkWell(
          onTap: () {
            notifier.setBranchMode(true);
            // Eğer daha önce bir bölüm seçilmediyse varsayılan olarak ilkini seç (dersleri listelemek için)
            if (state.selectedSection == null && state.availableSections.isNotEmpty) {
              notifier.setSection(state.availableSections.first);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 1.5),
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  "Branş Denemesi Ekle",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Geri Dön butonu (Genel Moda geçiş)
        TextButton.icon(
          onPressed: () => notifier.setBranchMode(false),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text("Genel Deneme Türüne Dön"),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),

        const SizedBox(height: 16),

        // Bölüm Seçimi (Branch modunda hangi sınavın dersi?)
        // Eğer birden fazla bölüm varsa (Örn: TYT ve AYT), kullanıcı önce onu seçmeli
        if (state.availableSections.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: state.availableSections.map((section) {
                final isSelected = state.selectedSection == section;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(section.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) notifier.setSection(section);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          "Ders Seçimi",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Seçili bölümün dersleri
        if (state.selectedSection != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.selectedSection!.subjects.keys.map((subject) {
              final isSelected = state.selectedBranchSubject == subject;
              return ChoiceChip(
                label: Text(subject),
                selected: isSelected,
                showCheckmark: true,
                onSelected: (selected) {
                  if (selected) notifier.setBranchSubject(subject);
                },
                selectedColor: theme.colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              );
            }).toList(),
          )
        else
          const Text("Lütfen önce yukarıdan bir sınav türü seçin."),
      ],
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected
            ? theme.colorScheme.surfaceVariant
            : theme.colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Text(
                section.name, // Örn: TYT
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