import 'package:flutter/material.dart';

/// Uygulama genelinde ders ikonları ve renklerini merkezi olarak yöneten yardımcı sınıf
/// HİÇBİR DERS KLASÖR İKONU GÖSTERMEZ!
class SubjectUtils {
  SubjectUtils._();

  /// Ders adına göre ikon döndürür
  static IconData getSubjectIcon(String subject) {
    switch (subject) {
    // YKS - TYT
      case 'Türkçe':
        return Icons.menu_book_rounded; // Okuma-anlama
      case 'Tarih (Sosyal Bilimler)':
        return Icons.account_balance_rounded; // Medeniyet/devlet
      case 'Coğrafya (Sosyal Bilimler)':
        return Icons.public_rounded; // Dünya/harita
      case 'Felsefe (Sosyal Bilimler)':
        return Icons.psychology_rounded; // Düşünce/zihin
      case 'Din Kültürü ve Ahlak Bilgisi (Sosyal Bilimler)':
        return Icons.self_improvement_rounded; // Manevi değerler
      case 'Temel Matematik':
      case 'Matematik':
        return Icons.calculate_rounded; // Hesaplama
      case 'Fizik (Fen Bilimleri)':
      case 'Fizik':
        return Icons.bolt_rounded; // Enerji/hareket
      case 'Kimya (Fen Bilimleri)':
      case 'Kimya':
        return Icons.science_rounded; // Deney/reaksiyon
      case 'Biyoloji (Fen Bilimleri)':
      case 'Biyoloji':
        return Icons.eco_rounded; // Canlılar/doğa

    // YKS - AYT
      case 'Türk Dili ve Edebiyatı':
        return Icons.auto_stories_rounded; // Edebiyat/metin
      case 'Tarih-1':
      case 'Tarih-2':
        return Icons.history_edu_rounded;
      case 'Coğrafya-1':
      case 'Coğrafya-2':
        return Icons.map_rounded; // Harita
      case 'Felsefe Grubu':
        return Icons.lightbulb_rounded; // Fikir/yorum
      case 'Din Kültürü ve Ahlak Bilgisi':
        return Icons.self_improvement_rounded;

    // YKS - YDT
      case 'Yabancı Dil':
        return Icons.language_rounded; // Dil/iletişim

    // LGS
      case 'T.C. İnkılap Tarihi ve Atatürkçülük':
        return Icons.flag_rounded; // Cumhuriyet/inkılap
      case 'İngilizce':
        return Icons.translate_rounded;
      case 'Fen Bilimleri':
        return Icons.science_rounded;

    // KPSS
      case 'Türkçe (Genel Yetenek)':
        return Icons.menu_book_rounded;
      case 'Matematik (Genel Yetenek)':
        return Icons.functions_rounded; // Matematiksel yapı
      case 'Tarih (Genel Kültür)':
        return Icons.history_edu_rounded;
      case 'Coğrafya (Genel Kültür)':
        return Icons.public_rounded;
      case 'Vatandaşlık (Genel Kültür)':
        return Icons.balance_rounded; // Hukuk/devlet
      case 'Güncel Bilgiler (Genel Kültür)':
        return Icons.newspaper_rounded; // Güncel olaylar

    // AGS
      case 'Sözel Yetenek':
        return Icons.record_voice_over_rounded; // Sözel ifade
      case 'Sayısal Yetenek':
        return Icons.onetwothree_rounded; // Sayılar
      case 'Tarih':
        return Icons.history_edu_rounded;
      case 'Türkiye Coğrafyası':
        return Icons.terrain_rounded; // Fiziki coğrafya
      case 'Eğitim Bilimleri ve Türk Milli Eğitim Sistemi':
        return Icons.school_rounded; // Eğitim
      case 'Mevzuat':
        return Icons.gavel_rounded; // Kanun
      case 'Alan Bilgisi':
        return Icons.badge_rounded; // Uzmanlık
      case 'Temel Alan Bilgisi':
        return Icons.assignment_rounded;
      case 'Alan Eğitimi':
        return Icons.cast_for_education_rounded;

    // Varsayılan
      default:
        return Icons.book_rounded;
    }
  }

  /// Ders adına göre renk döndürür
  static Color getSubjectColor(String subject, {ColorScheme? colorScheme}) {
    switch (subject) {
    // YKS - TYT
      case 'Türkçe':
        return Colors.red.shade600; // Dil/sözel
      case 'Tarih (Sosyal Bilimler)':
        return Colors.brown.shade700; // Geçmiş/toprak
      case 'Coğrafya (Sosyal Bilimler)':
        return Colors.teal.shade600; // Doğa/dünya
      case 'Felsefe (Sosyal Bilimler)':
        return Colors.deepOrange.shade600; // Düşünce
      case 'Din Kültürü ve Ahlak Bilgisi (Sosyal Bilimler)':
        return Colors.green.shade700; // Maneviyat
      case 'Temel Matematik':
      case 'Matematik':
        return Colors.blue.shade700; // Sayısal
      case 'Fizik (Fen Bilimleri)':
      case 'Fizik':
        return Colors.deepPurple.shade600; // Enerji
      case 'Kimya (Fen Bilimleri)':
      case 'Kimya':
        return Colors.orange.shade700; // Reaksiyon
      case 'Biyoloji (Fen Bilimleri)':
      case 'Biyoloji':
        return Colors.green.shade600; // Canlılar

    // YKS - AYT
      case 'Türk Dili ve Edebiyatı':
        return Colors.pink.shade600; // Edebiyat
      case 'Tarih-1':
      case 'Tarih-2':
        return Colors.brown.shade800;
      case 'Coğrafya-1':
      case 'Coğrafya-2':
        return Colors.teal.shade700;
      case 'Felsefe Grubu':
        return Colors.deepOrange.shade700;
      case 'Din Kültürü ve Ahlak Bilgisi':
        return Colors.green.shade800;

    // YKS - YDT
      case 'Yabancı Dil':
        return Colors.indigo.shade500;

    // LGS
      case 'T.C. İnkılap Tarihi ve Atatürkçülük':
        return Colors.red.shade800; // Cumhuriyet vurgusu
      case 'İngilizce':
        return Colors.indigo.shade400;
      case 'Fen Bilimleri':
        return Colors.teal.shade500;

    // KPSS
      case 'Türkçe (Genel Yetenek)':
        return Colors.red.shade600;
      case 'Matematik (Genel Yetenek)':
        return Colors.blue.shade800;
      case 'Tarih (Genel Kültür)':
        return Colors.brown.shade700;
      case 'Coğrafya (Genel Kültür)':
        return Colors.teal.shade600;
      case 'Vatandaşlık (Genel Kültür)':
        return Colors.deepPurple.shade700;
      case 'Güncel Bilgiler (Genel Kültür)':
        return Colors.blueGrey.shade600;

    // AGS
      case 'Sözel Yetenek':
        return Colors.blueGrey.shade700;
      case 'Sayısal Yetenek':
        return Colors.blue.shade900;
      case 'Tarih':
        return Colors.brown.shade600;
      case 'Türkiye Coğrafyası':
        return Colors.teal.shade700;
      case 'Eğitim Bilimleri ve Türk Milli Eğitim Sistemi':
        return Colors.green.shade800;
      case 'Mevzuat':
        return Colors.indigo.shade900;
      case 'Alan Bilgisi':
        return Colors.deepPurple.shade800;
      case 'Temel Alan Bilgisi':
        return Colors.purple.shade700;
      case 'Alan Eğitimi':
        return Colors.indigo.shade600;

    // Varsayılan
      default:
        return colorScheme?.primary ?? Colors.indigo;
    }
  }
}
