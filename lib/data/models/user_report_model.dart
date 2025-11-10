// lib/data/models/user_report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı raporlama kategorileri
enum UserReportReason {
  spam('spam', 'Spam veya İstenmeyen İçerik'),
  harassment('harassment', 'Taciz veya Zorbalık'),
  inappropriate('inappropriate', 'Uygunsuz İçerik'),
  impersonation('impersonation', 'Kimliğe Bürünme'),
  underage('underage', 'Yaş Sınırı İhlali'),
  hateSpeech('hate_speech', 'Nefret Söylemi'),
  scam('scam', 'Dolandırıcılık'),
  other('other', 'Diğer');

  final String value;
  final String displayName;

  const UserReportReason(this.value, this.displayName);

  static UserReportReason fromString(String value) {
    return UserReportReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserReportReason.other,
    );
  }
}

/// Rapor durumu
enum ReportStatus {
  pending('pending', 'Beklemede'),
  reviewed('reviewed', 'İncelendi'),
  resolved('resolved', 'Çözüldü'),
  dismissed('dismissed', 'Reddedildi');

  final String value;
  final String displayName;

  const ReportStatus(this.value, this.displayName);

  static ReportStatus fromString(String value) {
    return ReportStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportStatus.pending,
    );
  }
}

/// Kullanıcı raporu modeli
class UserReportModel {
  final String id; // Rapor ID'si
  final String reportedUserId; // Raporlanan kullanıcı ID'si
  final String reporterUserId; // Raporlayan kullanıcı ID'si
  final UserReportReason reason; // Raporlama nedeni
  final String? details; // Ek detaylar
  final Timestamp createdAt; // Oluşturulma zamanı
  final ReportStatus status; // Rapor durumu
  final String? adminNotes; // Admin notları
  final Timestamp? reviewedAt; // İncelenme zamanı
  final String? reviewedBy; // İnceleyen admin ID'si

  UserReportModel({
    required this.id,
    required this.reportedUserId,
    required this.reporterUserId,
    required this.reason,
    this.details,
    required this.createdAt,
    this.status = ReportStatus.pending,
    this.adminNotes,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory UserReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserReportModel(
      id: doc.id,
      reportedUserId: data['reportedUserId'] as String? ?? '',
      reporterUserId: data['reporterUserId'] as String? ?? '',
      reason: UserReportReason.fromString(data['reason'] as String? ?? 'other'),
      details: data['details'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      status: ReportStatus.fromString(data['status'] as String? ?? 'pending'),
      adminNotes: data['adminNotes'] as String?,
      reviewedAt: data['reviewedAt'] as Timestamp?,
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reportedUserId': reportedUserId,
      'reporterUserId': reporterUserId,
      'reason': reason.value,
      if (details != null && details!.isNotEmpty) 'details': details,
      'createdAt': createdAt,
      'status': status.value,
      if (adminNotes != null) 'adminNotes': adminNotes,
      if (reviewedAt != null) 'reviewedAt': reviewedAt,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
    };
  }

  UserReportModel copyWith({
    String? id,
    String? reportedUserId,
    String? reporterUserId,
    UserReportReason? reason,
    String? details,
    Timestamp? createdAt,
    ReportStatus? status,
    String? adminNotes,
    Timestamp? reviewedAt,
    String? reviewedBy,
  }) {
    return UserReportModel(
      id: id ?? this.id,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      reporterUserId: reporterUserId ?? this.reporterUserId,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }
}

