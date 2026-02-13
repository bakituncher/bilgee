import 'package:cloud_firestore/cloud_firestore.dart';

/// Kaydedilebilecek içerik türleri
enum SavedContentType {
  flashcard,  // Bilgi kartları (eski infoCards)
  quiz,       // Quiz/Test soruları (eski questionCards)
  summary,    // Özet
}

/// Kaydedilen içerik modeli - Quiz, Flashcard ve Özet için ortak
class SavedContentModel {
  final String id;
  final SavedContentType type;
  final String title;           // İçerik başlığı
  final String content;         // JSON formatında içerik
  final DateTime createdAt;
  final String? subject;        // Ders (Matematik vb.)
  final String? examType;       // Sınav türü (YKS, LGS vb.)
  final String contentHash;     // Duplicate kontrolü için hash

  SavedContentModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.contentHash,
    this.subject,
    this.examType,
  });

  /// Firestore için Map dönüşümü
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // Enum -> String
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'contentHash': contentHash,
      'subject': subject,
      'examType': examType,
    };
  }

  /// Firestore'dan Model dönüşümü
  factory SavedContentModel.fromMap(Map<String, dynamic> map) {
    return SavedContentModel(
      id: map['id'] ?? '',
      type: SavedContentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SavedContentType.summary,
      ),
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      contentHash: map['contentHash'] ?? '',
      subject: map['subject'],
      examType: map['examType'],
    );
  }

  /// Kopyalama metodu
  SavedContentModel copyWith({
    String? id,
    SavedContentType? type,
    String? title,
    String? content,
    DateTime? createdAt,
    String? contentHash,
    String? subject,
    String? examType,
  }) {
    return SavedContentModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      contentHash: contentHash ?? this.contentHash,
      subject: subject ?? this.subject,
      examType: examType ?? this.examType,
    );
  }
}
