// lib/features/weakness_workshop/screens/saved_workshop_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:taktik/features/weakness_workshop/models/study_guide_model.dart';

class SavedWorkshopDetailScreen extends StatelessWidget {
  final SavedWorkshopModel workshop;

  const SavedWorkshopDetailScreen({super.key, required this.workshop});

  @override
  Widget build(BuildContext context) {
    // Kaydedilmiş quiz verisini tekrar QuizQuestion modeline çeviriyoruz
    final quizQuestions = workshop.quiz.map((q) => QuizQuestion.fromJson(q)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(workshop.topic),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.secondary,
            tabs: const [
              Tab(icon: Icon(Icons.school_rounded), text: "Çalışma Kartı"),
              Tab(icon: Icon(Icons.quiz_rounded), text: "Ustalık Sınavı"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Çalışma Kartı Sekmesi
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: MarkdownBody(
                data: workshop.studyGuide,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(fontSize: 16, height: 1.5, color: Theme.of(context).colorScheme.onSurface),
                  h1: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                  h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            // Ustalık Sınavı Sekmesi
            _QuizReviewView(quizQuestions: quizQuestions),
          ],
        ),
      ),
    );
  }
}

// Sadece bu ekranda kullanılacak özel bir Karne widget'ı
class _QuizReviewView extends StatelessWidget {
  final List<QuizQuestion> quizQuestions;

  const _QuizReviewView({required this.quizQuestions});

  @override
  Widget build(BuildContext context) {
    if (quizQuestions.isEmpty) {
      return const Center(child: Text("Bu cevher için sınav kaydedilmemiş."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: quizQuestions.length,
      itemBuilder: (context, index) {
        final question = quizQuestions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Soru ${index + 1}: ${question.question}", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...List.generate(question.options.length, (optIndex) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      question.options[optIndex],
                      style: TextStyle(
                        color: optIndex == question.correctOptionIndex ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    leading: Icon(
                      optIndex == question.correctOptionIndex ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: optIndex == question.correctOptionIndex ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }),
                const Divider(height: 24),
                // Açıklama Kartı
                Card(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Usta'nın Açıklaması", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.secondary)),
                              const SizedBox(height: 8),
                              Text(question.explanation, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, height: 1.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}