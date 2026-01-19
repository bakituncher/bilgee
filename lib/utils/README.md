# SubjectUtils - Ders İkon ve Renk Yönetimi

Uygulama genelinde tüm ders ikonlarını ve renklerini merkezi olarak yöneten sistem.

**ÖNEMLİ: HİÇBİR DERS KLASÖR İKONU GÖSTERMEZ!**

## Kullanım

```dart
import 'package:taktik/utils/subject_utils.dart';

// Ders ikonu almak
IconData icon = SubjectUtils.getSubjectIcon('Matematik');

// Ders rengi almak
Color color = SubjectUtils.getSubjectColor('Fizik');

// Tema ile birlikte kullanım
Color color = SubjectUtils.getSubjectColor('Kimya', colorScheme: theme.colorScheme);
```

## Desteklenen Dersler

### Sayısal
- **Matematik**: `Icons.calculate_rounded` - Mavi
- **Geometri**: `Icons.architecture_rounded` - Açık Yeşil

### Fen Bilimleri
- **Fizik**: `Icons.science_rounded` - Mor
- **Kimya**: `Icons.biotech_rounded` - Yeşil
- **Biyoloji**: `Icons.eco_rounded` - Turkuaz
- **Fen Bilimleri**: `Icons.science_outlined` - Cyan

### Dil ve Edebiyat
- **Türkçe / Türk Dili**: `Icons.menu_book_rounded` - Kırmızı
- **Edebiyat**: `Icons.auto_stories_rounded` - Pembe

### Sosyal Bilimler
- **Tarih / İnkılap**: `Icons.history_edu_rounded` - Kahverengi
- **Coğrafya**: `Icons.public_rounded` - Açık Mavi
- **Felsefe**: `Icons.psychology_rounded` - Koyu Mor
- **Vatandaşlık**: `Icons.account_balance_rounded` - İndigo
- **Sosyal Bilimler**: `Icons.groups_rounded` - Lime

### Din Kültürü
- **Din Kültürü / Ahlak**: `Icons.mosque_rounded` - Koyu Turuncu

### Yabancı Diller
- **İngilizce**: `Icons.language_rounded` - Turuncu
- **Almanca**: `Icons.translate_rounded` - Kehribar
- **Fransızca**: `Icons.translate_rounded` - Koyu Turuncu
- **Rusça**: `Icons.translate_rounded` - Koyu Kırmızı
- **Arapça**: `Icons.translate_rounded` - Koyu Yeşil
- **İspanyolca**: `Icons.translate_rounded` - Koyu Turuncu
- **İtalyanca**: `Icons.translate_rounded` - Açık Yeşil
- **Çince**: `Icons.translate_rounded` - Çok Koyu Kırmızı
- **Japonca**: `Icons.translate_rounded` - Koyu Pembe

### KPSS / AGS
- **Sözel Yetenek / Genel Yetenek**: `Icons.lightbulb_outline_rounded` - Mavi-Gri
- **Sayısal Yetenek**: `Icons.functions_rounded` - Koyu Mavi
- **Güncel Bilgiler**: `Icons.newspaper_rounded` - Gri
- **Eğitim Bilimleri**: `Icons.school_rounded` - Koyu Turkuaz

### Varsayılan
- **Diğer tüm dersler**: `Icons.book_rounded` - Primary veya İndigo

## Yeni Ders Eklemek

`subject_utils.dart` dosyasında ilgili yerlere ekleyin:

```dart
// İkon
if (subject.contains('Yeni Ders')) return Icons.yeni_ikon;

// Renk
if (subject.contains('Yeni Ders')) return Colors.yeniRenk;
```

