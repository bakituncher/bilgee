import 'package:hive/hive.dart';

// TypeId: 0 -> Veritabanı kimliği
class SavedSolutionModel extends HiveObject {
  final String id;
  final String localImagePath;   // Orijinal resim (Detay ekranı için)
  final String thumbnailPath;    // Küçük resim (Liste ekranı için - PERFORMANS İÇİN KRİTİK)
  final String solutionText;     // Çözüm metni
  final DateTime timestamp;      // Kayıt tarihi
  final String? subject;         // Ders (Matematik vb.)

  SavedSolutionModel({
    required this.id,
    required this.localImagePath,
    required this.thumbnailPath,
    required this.solutionText,
    required this.timestamp,
    this.subject,
  });
}

// Hive Adaptörü (build_runner çalıştırmaman için elle yazdım)
class SavedSolutionAdapter extends TypeAdapter<SavedSolutionModel> {
  @override
  final int typeId = 0;

  @override
  SavedSolutionModel read(BinaryReader reader) {
    return SavedSolutionModel(
      id: reader.read(),
      localImagePath: reader.read(),
      thumbnailPath: reader.read(),
      solutionText: reader.read(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.read()),
      subject: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, SavedSolutionModel obj) {
    writer.write(obj.id);
    writer.write(obj.localImagePath);
    writer.write(obj.thumbnailPath);
    writer.write(obj.solutionText);
    writer.write(obj.timestamp.millisecondsSinceEpoch);
    writer.write(obj.subject);
  }
}

