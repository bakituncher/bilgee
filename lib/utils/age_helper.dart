// lib/utils/age_helper.dart
/// Kullanıcının doğum tarihinden yaşını hesaplar
class AgeHelper {
  /// Kullanıcının 18 yaşından küçük olup olmadığını kontrol eder
  static bool isUnder18(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      // Yaş bilgisi yoksa güvenli tarafta kal
      return true;
    }

    final now = DateTime.now();
    final age = now.year - dateOfBirth.year;

    // Doğum günü henüz gelmemişse bir yaş düşür
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      return (age - 1) < 18;
    }

    return age < 18;
  }

  /// Kullanıcının yaşını hesaplar
  static int calculateAge(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return 0;

    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;

    // Doğum günü henüz gelmemişse bir yaş düşür
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }

    return age;
  }
}

