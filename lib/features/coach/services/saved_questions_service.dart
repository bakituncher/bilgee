import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SavedQuestion {
  final String id;
  final DateTime date;
  final String imagePath;
  final String solutionMarkdown;

  SavedQuestion({
    required this.id,
    required this.date,
    required this.imagePath,
    required this.solutionMarkdown,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'solutionMarkdown': solutionMarkdown,
    };
  }

  factory SavedQuestion.fromJson(Map<String, dynamic> json) {
    return SavedQuestion(
      id: json['id'],
      date: DateTime.parse(json['date']),
      imagePath: json['imagePath'],
      solutionMarkdown: json['solutionMarkdown'],
    );
  }
}

class SavedQuestionsService {
  static const String _storageKey = 'saved_questions_v1';

  Future<List<SavedQuestion>> getQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => SavedQuestion.fromJson(e)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveQuestion({
    required File imageFile,
    required String solutionMarkdown,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.jpg';
    final savedImage = await imageFile.copy('${appDir.path}/$fileName');

    final newQuestion = SavedQuestion(
      id: const Uuid().v4(),
      date: DateTime.now(),
      imagePath: savedImage.path,
      solutionMarkdown: solutionMarkdown,
    );

    final questions = await getQuestions();
    questions.insert(0, newQuestion);

    await _saveToPrefs(questions);
  }

  Future<void> deleteQuestion(String id) async {
    final questions = await getQuestions();
    final index = questions.indexWhere((q) => q.id == id);

    if (index == -1) return;

    final questionToDelete = questions[index];

    // Delete image file
    try {
      final file = File(questionToDelete.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore
    }

    questions.removeAt(index);
    await _saveToPrefs(questions);
  }

  Future<void> _saveToPrefs(List<SavedQuestion> questions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(questions.map((q) => q.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}

final savedQuestionsServiceProvider = Provider<SavedQuestionsService>((ref) {
  return SavedQuestionsService();
});
