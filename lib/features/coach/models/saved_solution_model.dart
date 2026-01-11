import 'dart:convert';

class SavedSolutionModel {
  final String id;
  final String localImagePath; // Cihazdaki dosya yolu
  final String solutionText;
  final DateTime timestamp;
  final String? subject; // Ders adı (opsiyonel)

  SavedSolutionModel({
    required this.id,
    required this.localImagePath,
    required this.solutionText,
    required this.timestamp,
    this.subject,
  });

  // JSON'dan modele çevirme
  factory SavedSolutionModel.fromMap(Map<String, dynamic> map) {
    return SavedSolutionModel(
      id: map['id'] ?? '',
      localImagePath: map['localImagePath'] ?? '',
      solutionText: map['solutionText'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      subject: map['subject'],
    );
  }

  // Modelden JSON'a çevirme
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'localImagePath': localImagePath,
      'solutionText': solutionText,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'subject': subject,
    };
  }

  String toJson() => json.encode(toMap());

  factory SavedSolutionModel.fromJson(String source) =>
      SavedSolutionModel.fromMap(json.decode(source));
}

