// lib/features/home/widgets/add_test_step1.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/home/logic/add_test_notifier.dart';

class Step1TestInfo extends ConsumerWidget {
  const Step1TestInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addTestProvider);
    final notifier = ref.read(addTestProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    // Butonun aktif olup olmayacağını kontrol eden mantık.
    final isButtonEnabled =
        state.testName.isNotEmpty && state.selectedSection != null;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // 1. Başlık ve İkon
        const Icon(Icons.edit_document,
            size: 64, color: AppTheme.secondaryColor),
        const SizedBox(height: 16),
        Text(
          "Yeni Deneme Sonucu Ekle",
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Kaydedilecek denemenin temel bilgilerini girerek ilk adımı at.",
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: 48),

        // 2. Deneme Adı Girişi
        Text("Deneme Adı", style: textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.testName,
          decoration: InputDecoration(
            hintText: 'Örn: 3D Genel Deneme Sınavı',
            prefixIcon:
            const Icon(Icons.label_important_outline, color: AppTheme.secondaryTextColor),
            // Odaklanıldığında ve normal durumda kenarlık rengi
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 2),
            ),
          ),
          onChanged: (value) => notifier.setTestName(value),
        ),
        const SizedBox(height: 32),

        // 3. Deneme Türü Seçimi (Yeniden Tasarlandı)
        if (state.availableSections.length > 1) ...[
          Text("Deneme Türü", style: textTheme.titleLarge),
          const SizedBox(height: 12),
          ...state.availableSections
              .map((section) => _SectionSelectionCard(
            section: section,
            isSelected: state.selectedSection == section,
            onTap: () => notifier.setSection(section),
          ))
              .toList(),
        ],
        const SizedBox(height: 32),

        // 4. İlerleme Butonu
        ElevatedButton(
          onPressed: isButtonEnabled ? () => notifier.nextStep() : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            // Buton pasifken farklı bir görünüm
            backgroundColor: isButtonEnabled
                ? AppTheme.secondaryColor
                : AppTheme.lightSurfaceColor,
            foregroundColor:
            isButtonEnabled ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Netleri Girmeye Başla'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ]
          .animate(interval: 80.ms)
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.2, curve: Curves.easeOutCubic),
    );
  }
}

// Deneme türlerini seçmek için özel olarak tasarlanmış kart widget'ı
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppTheme.successColor : AppTheme.lightSurfaceColor,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Seçili olduğunda gösterilecek ikon
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: 200.ms,
                child: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.successColor),
              ),
              if (isSelected) const SizedBox(width: 12),
              Text(
                section.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}