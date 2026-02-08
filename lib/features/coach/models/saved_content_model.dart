import 'package:hive/hive.dart';

/// Kaydedilebilecek içerik türleri
enum SavedContentType {
  flashcard,  // Bilgi kartları (eski infoCards)
  quiz,       // Quiz/Test soruları (eski questionCards)
  summary,    // Özet
}

/// Kaydedilen içerik modeli - Quiz, Flashcard ve Özet için ortak
/// TypeId: 1 -> Veritabanı kimliği (SavedSolutionModel = 0)
class SavedContentModel extends HiveObject {
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

/// Hive Adaptörü - SavedContentModel için
class SavedContentAdapter extends TypeAdapter<SavedContentModel> {
  @override
  final int typeId = 1;

  @override
  SavedContentModel read(BinaryReader reader) {
    return SavedContentModel(
      id: reader.read(),
      type: SavedContentType.values[reader.read()],
      title: reader.read(),
      content: reader.read(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.read()),
      contentHash: reader.read(),
      subject: reader.read(),
      examType: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, SavedContentModel obj) {
    writer.write(obj.id);
    writer.write(obj.type.index);
    writer.write(obj.title);
    writer.write(obj.content);
    writer.write(obj.createdAt.millisecondsSinceEpoch);
    writer.write(obj.contentHash);
    writer.write(obj.subject);
    writer.write(obj.examType);
  }
}

/// SavedContentType için Hive Adaptörü
class SavedContentTypeAdapter extends TypeAdapter<SavedContentType> {
  @override
  final int typeId = 2;

  @override
  SavedContentType read(BinaryReader reader) {
    return SavedContentType.values[reader.read()];
  }

  @override
  void write(BinaryWriter writer, SavedContentType obj) {
    writer.write(obj.index);
  }
}
