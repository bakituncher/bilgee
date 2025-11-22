// lib/data/repositories/firestore_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/data/models/focus_session_model.dart';
import 'package:taktik/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/app_state.dart';
import 'package:taktik/features/arena/models/leaderboard_entry_model.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/data/models/user_stats_model.dart';
import 'package:taktik/features/blog/models/blog_post.dart';
import 'package:taktik/features/profile/screens/user_search_screen.dart'; // SearchType enum için
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
import 'package:taktik/shared/notifications/in_app_notification_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/core/app_check/app_check_helper.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;
  FirestoreService(this._firestore);

  // Firestore instance'ına erişim için getter ekle
  FirebaseFirestore get db => _firestore;

  String sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[.\s()]'), '_');
  }

  String? getUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  CollectionReference<Map<String, dynamic>> get usersCollection => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _leaderboardsCollection => _firestore.collection('leaderboards');
  CollectionReference<Map<String, dynamic>> get _testsCollection => _firestore.collection('tests');
  CollectionReference<Map<String, dynamic>> get _focusSessionsCollection => _firestore.collection('focusSessions');
  CollectionReference<Map<String, dynamic>> get _postsCollection => _firestore.collection('posts');
  CollectionReference<Map<String, dynamic>> get _questionReportsCollection => _firestore.collection('questionReports');
  CollectionReference<Map<String, dynamic>> get _questionReportsIndexCollection => _firestore.collection('question_report_index');
  // YENİ: Yayınlanmış tepe listesi dokümanı (latest)
  DocumentReference<Map<String, dynamic>> _leaderboardTopLatestDoc(String examType, String period)
      => _firestore.collection('leaderboard_top').doc(examType).collection(period).doc('latest');
  // YENİ: Optimize edilmiş anlık görüntü dokümanı referansı
  DocumentReference<Map<String, dynamic>> _leaderboardSnapshotDoc(String examType, String period)
      => _firestore.collection('leaderboard_snapshots').doc('${examType}_$period');
  // YENİ: Public profile dokümanı
  DocumentReference<Map<String, dynamic>> _publicProfileDoc(String userId)
      => _firestore.collection('public_profiles').doc(userId);

  // Admin: rapor indeks akışı (en çok raporlananlar en üstte)
  Stream<List<Map<String, dynamic>>> streamQuestionReportIndex({int limit = 200}) {
    return _questionReportsIndexCollection
        .orderBy('reportCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map((d) => { 'id': d.id, ...d.data() }).toList());
  }

  // Admin: belirli qhash için ham raporlar
  Stream<List<Map<String, dynamic>>> streamQuestionReportsByHash(String qhash, {int limit = 200}) {
    return _questionReportsCollection
        .where('qhash', isEqualTo: qhash)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map((d) => { 'id': d.id, ...d.data() }).toList());
  }

  String _computeQuestionHash(String question, List<String> options) {
    final normalized = ('${question.trim().toLowerCase()}|${options.map((o) => o.trim().toLowerCase()).join('||')}');
    final bytes = utf8.encode(normalized);
    return crypto.sha256.convert(bytes).toString();
  }

  // BLOG: Yayımlanmış yazıları canlı dinle (locale opsiyonel)
  Stream<List<BlogPost>> streamPublishedPosts({String? locale, int limit = 20}) {
    Query<Map<String, dynamic>> q = _postsCollection
        .where('status', isEqualTo: 'published')
        .where('publishedAt', isLessThanOrEqualTo: Timestamp.now())
        .orderBy('publishedAt', descending: true)
        .limit(limit);
    if (locale != null) {
      q = q.where('locale', isEqualTo: locale);
    }
    return q.snapshots().map((snap) => snap.docs
        .map((d) => BlogPost.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList());
  }

  // BLOG: Sayfalı okuma
  Future<(List<BlogPost> items, DocumentSnapshot? lastDoc)> getPublishedPostsPaginated({
    String? locale,
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _postsCollection
        .where('status', isEqualTo: 'published')
        .where('publishedAt', isLessThanOrEqualTo: Timestamp.now())
        .orderBy('publishedAt', descending: true)
        .limit(limit);
    if (locale != null) {
      q = q.where('locale', isEqualTo: locale);
    }
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    final qs = await q.get();
    final items = qs.docs
        .map((d) => BlogPost.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
    final last = qs.docs.isNotEmpty ? qs.docs.last : null;
    return (items, last);
  }

  // BLOG: Slug ile tek yazı
  Future<BlogPost?> getPostBySlug(String slug) async {
    final qs = await _postsCollection.where('slug', isEqualTo: slug).limit(1).get();
    if (qs.docs.isEmpty) return null;
    final doc = qs.docs.first as DocumentSnapshot<Map<String, dynamic>>;
    return BlogPost.fromDoc(doc);
  }

  // YENI: Kullanıcı aktivite alt koleksiyonu (Günlük dokümanlar)
  CollectionReference<Map<String, dynamic>> _userActivityCollection(String userId) => usersCollection.doc(userId).collection('user_activity');
  // Günlük aktivite dokümanı: users/{uid}/user_activity/YYYY-MM-DD
  DocumentReference<Map<String, dynamic>> _userActivityDailyDoc(String userId, DateTime date) {
    final id = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _userActivityCollection(userId).doc(id);
  }

  // ESKI: Aylık referans (artık kullanılmıyor)
  // KALDIRILDI: _userActivityMonthlyDoc

  // YENI: Stats dokümanı
  DocumentReference<Map<String, dynamic>> _userStatsDoc(String userId) => usersCollection.doc(userId).collection('state').doc('stats');

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // GÜNCEL: Tek gün tamamlanan görevleri oku (günlük dokümandan)
  Future<List<String>> getCompletedTasksForDate(String userId, DateTime date) async {
    final snap = await _userActivityDailyDoc(userId, date).get();
    final data = snap.data() ?? <String, dynamic>{};
    final v = data['completedTasks'];
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  // GÜNCEL: Haftalık tamamlanan görevler (Optimize Edilmiş: Tek sorgu)
  Future<Map<String, List<String>>> getCompletedTasksForWeek(String userId, DateTime weekStart) async {
    final startDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    // Haftanın son günü, başlangıçtan 6 gün sonradır.
    final endDay = startDay.add(const Duration(days: 6));
    return getCompletedTasksInRange(userId, start: startDay, end: endDay);
  }

  // YENİ: Belirli bir tarih aralığındaki (start dahil, end dahil) günlerin tamamlanan görevlerini tek sorguda getir (Collection Group Query)
  Future<Map<String, List<String>>> getCompletedTasksInRange(String userId, {required DateTime start, required DateTime end}) async {
    final startTs = Timestamp.fromDate(DateTime(start.year, start.month, start.day));
    final endTs = Timestamp.fromDate(DateTime(end.year, end.month, end.day).add(const Duration(days: 1)));

    final qs = await _firestore.collectionGroup('completed_tasks')
        .where('userId', isEqualTo: userId)
        .where('completedAt', isGreaterThanOrEqualTo: startTs)
        .where('completedAt', isLessThan: endTs)
        .get();

    final Map<String, List<String>> out = {};
    for (final doc in qs.docs) {
        final data = doc.data();
        final taskId = data['taskId'] as String;
        // The document ID of the parent is the dateKey
        final dateKey = doc.reference.parent.parent!.id;

        if (out.containsKey(dateKey)) {
            out[dateKey]!.add(taskId);
        } else {
            out[dateKey] = [taskId];
        }
    }
    return out;
  }

  // GÜNCEL: Ay içindeki tüm ziyaretleri getir (Ölçeklenebilir: Collection Group Query)
  Future<List<Timestamp>> getVisitsForMonth(String userId, DateTime anyDayInMonth) async {
    final monthStart = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final nextMonth = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);
    final startTs = Timestamp.fromDate(monthStart);
    final endTs = Timestamp.fromDate(nextMonth);

    final qs = await _firestore.collectionGroup('visits')
        .where('userId', isEqualTo: userId)
        .where('visitTime', isGreaterThanOrEqualTo: startTs)
        .where('visitTime', isLessThan: endTs)
        .get();

    final List<Timestamp> visits = [];
    for (final doc in qs.docs) {
        final data = doc.data();
        final visitTime = data['visitTime'] as Timestamp?;
        if (visitTime != null) {
            visits.add(visitTime);
        }
    }
    return visits;
  }

  // GÜNCEL: Günlük practice volume arttır
  Future<void> incrementPracticeVolume(String userId, {required DateTime date, required int delta}) async {
    final dailyRef = _userActivityDailyDoc(userId, date);
    await dailyRef.set({
      'practiceVolume': FieldValue.increment(delta),
      // sorgulanabilir alanlar
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'dateKey': _dateKey(date),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // GÜNCEL: Ziyaret kaydı (Ölçeklenebilir: Alt koleksiyon modeli)
  Future<void> recordUserVisit(String userId, {Timestamp? at}) async {
    final nowTs = at ?? Timestamp.now();
    final now = nowTs.toDate();
    final dailyRef = _userActivityDailyDoc(userId, now);
    final visitsCollection = dailyRef.collection('visits');

    // Son ziyareti kontrol et
    final lastVisitQuery = await visitsCollection.orderBy('visitTime', descending: true).limit(1).get();

    bool shouldRecord = true;
    if (lastVisitQuery.docs.isNotEmpty) {
      final lastVisitData = lastVisitQuery.docs.first.data();
      final lastVisitTs = lastVisitData['visitTime'] as Timestamp;
      if (now.difference(lastVisitTs.toDate()).inHours < 1) {
        shouldRecord = false;
      }
    }

    if (shouldRecord) {
      // Ziyareti yeni bir doküman olarak ekle
      await visitsCollection.add({
        'visitTime': nowTs,
        'userId': userId, // Koleksiyon grubu sorguları için eklendi
      });
      // Ana günlük dokümanı (meta veri için) oluştur/güncelle
      await dailyRef.set({
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'dateKey': _dateKey(now),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  DocumentReference<Map<String, dynamic>> _planDoc(String userId) => usersCollection.doc(userId).collection('plans').doc('current_plan');
  DocumentReference<Map<String, dynamic>> _performanceDoc(String userId) => usersCollection.doc(userId).collection('performance').doc('summary');
  DocumentReference<Map<String, dynamic>> _appStateDoc(String userId) => usersCollection.doc(userId).collection('state').doc('app_state');
  DocumentReference<Map<String, dynamic>> _leaderboardUserDoc({required String examType, required String userId}) => _leaderboardsCollection.doc(examType).collection('users').doc(userId);
  // YENI: Konu performansları için alt koleksiyon
  CollectionReference<Map<String, dynamic>> _topicPerformanceCollection(String userId) => usersCollection.doc(userId).collection('topic_performance');
  // YENI: Ustalaşılan konular için alt koleksiyon
  CollectionReference<Map<String, dynamic>> _masteredTopicsCollection(String userId) => _performanceDoc(userId).collection('masteredTopics');

  Future<void> _syncLeaderboardUser(String userId, {String? targetExam}) async {
    final userSnap = await usersCollection.doc(userId).get();
    if (!userSnap.exists) return;
    final data = userSnap.data()!;
    final String? examType = targetExam ?? data['selectedExam'] as String?;
    if (examType == null) return;

    // Stats'tan değerleri oku
    final statsSnap = await _userStatsDoc(userId).get();
    final stats = statsSnap.data() ?? const <String, dynamic>{};

    final docRef = _leaderboardUserDoc(examType: examType, userId: userId);
    await docRef.set({
      'userId': userId,
      'userName': data['name'],
      'score': stats['engagementScore'] ?? 0,
      'testCount': stats['testCount'] ?? 0,
      'avatarStyle': data['avatarStyle'],
      'avatarSeed': data['avatarSeed'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Public wrapper: leaderboard kaydını güncelle
  Future<void> syncLeaderboardUser(String userId, {String? targetExam}) async {
    await _syncLeaderboardUser(userId, targetExam: targetExam);
  }

  Future<void> updateUserAvatar({
    required String userId,
    required String style,
    required String seed,
  }) async {
    final userDocRef = usersCollection.doc(userId);
    // Önce avatarı garanti kaydet (merge)
    await userDocRef.set({
      'avatarStyle': style,
      'avatarSeed': seed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Liderlik tablosu güncellemesi: en iyi çaba, kural engellerse sessizce geç
    try {
      final userSnap = await userDocRef.get();
      final data = userSnap.data();
      final String? examType = data?['selectedExam'] as String?;
      if (examType != null) {
        final statsSnap = await _userStatsDoc(userId).get();
        final stats = statsSnap.data() ?? const <String, dynamic>{};
        final lbRef = _leaderboardUserDoc(examType: examType, userId: userId);
        await lbRef.set({
          'userId': userId,
          'userName': data?['name'],
          'score': stats['engagementScore'] ?? 0,
          'testCount': stats['testCount'] ?? 0,
          'avatarStyle': style,
          'avatarSeed': seed,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // no-op: avatar zaten kullanıcı dokümanında kaydedildi
    }
  }

  Future<void> saveWorkshopForUser(String userId, SavedWorkshopModel workshop) async {
    final userDocRef = usersCollection.doc(userId);
    final workshopCollectionRef = userDocRef.collection('savedWorkshops');
    await workshopCollectionRef.doc(workshop.id).set(workshop.toMap());
  }

  Future<void> deleteSavedWorkshop(String userId, String workshopId) async {
    await usersCollection
        .doc(userId)
        .collection('savedWorkshops')
        .doc(workshopId)
        .delete();
  }

  Stream<List<SavedWorkshopModel>> getSavedWorkshops(String userId) {
    return usersCollection
        .doc(userId)
        .collection('savedWorkshops')
        .orderBy('savedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SavedWorkshopModel.fromSnapshot(doc)).toList());
  }

  Future<void> createUserProfile({
    required User user,
    required String firstName,
    required String lastName,
    required String username,
    String? gender,
    DateTime? dateOfBirth,
    bool profileCompleted = false,
    String avatarStyle = 'bottts',
    String? avatarSeed,
  }) async {
    // KRİTİK DÜZELTME: 'female' stili geçersizdir, 'avataaars' kullan
    if (avatarStyle == 'female') {
      avatarStyle = 'avataaars';
    }

    final userProfile = UserModel(
      id: user.uid,
      email: user.email!,
      firstName: firstName,
      lastName: lastName,
      username: username,
      gender: gender,
      dateOfBirth: dateOfBirth,
      profileCompleted: profileCompleted,
      tutorialCompleted: false,
      avatarStyle: avatarStyle,
      avatarSeed: avatarSeed ?? user.uid,
    );
    await usersCollection.doc(user.uid).set(userProfile.toJson());

    // Create searchable keywords for the new user
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) {
      await updateSearchableKeywords(user.uid, fullName);
    }

    // Stats başlangıç değerleri
    await _userStatsDoc(user.uid).set({
      'streak': 0,
      'testCount': 0,
      'totalNetSum': 0.0,
      'engagementScore': 0,
      'lastStreakUpdate': null,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _appStateDoc(user.uid).set(const AppState().toMap(), SetOptions(merge: true));
    await _planDoc(user.uid).set(PlanDocument().toMap(), SetOptions(merge: true));
    await _performanceDoc(user.uid).set(const PerformanceSummary().toMap(), SetOptions(merge: true));
  }

  Future<void> updateUserProfileDetails({
    required String userId,
    required String username,
    required String gender,
    required DateTime dateOfBirth,
  }) async {
    await usersCollection.doc(userId).update({
      'username': username,
      'gender': gender,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'profileCompleted': true,
    });
  }

  Future<bool> checkUsernameAvailability(String username) async {
    // Güvenli okuma: public_profiles herkesçe (auth) okunabilir
    final q = await _firestore
        .collection('public_profiles')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  // KULLANICI ADI GÜNCELLEME (BASİTLEŞTİRİLDİ)
  // Veri senkronizasyonu artık onUserUpdate Cloud Function'ı tarafından yapılıyor.
  Future<void> updateUserName({required String userId, required String newName}) async {
    final userDocRef = usersCollection.doc(userId);
    final parts = newName.split(' ');
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    await userDocRef.update({
      'name': newName,
      'firstName': firstName,
      'lastName': lastName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markTutorialAsCompleted(String userId) async {
    // Sadece ana users belgesini güncelle (state belgesine yazma izni yok)
    await usersCollection.doc(userId).update({'tutorialCompleted': true});
  }

  // KULLANICI PROFİLİ GÜNCELLEME (BASİTLEŞTİRİLDİ)
  // Veri senkronizasyonu artık onUserUpdate Cloud Function'ı tarafından yapılıyor.
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    final userDocRef = usersCollection.doc(userId);

    // Geriye dönük uyumluluk için name alanını da ekle
    if (data.containsKey('firstName') || data.containsKey('lastName')) {
      final userSnap = await userDocRef.get();
      final existingData = userSnap.data() ?? {};
      final firstName = data['firstName'] ?? existingData['firstName'] ?? '';
      final lastName = data['lastName'] ?? existingData['lastName'] ?? '';
      data['name'] = '$firstName $lastName'.trim();
    }

    data['updatedAt'] = FieldValue.serverTimestamp();

    // onUserUpdate trigger'ı senkronizasyonu halledecek.
    await userDocRef.update(data);
  }

  // GÜVENLİK GÜNCELLEMESİ: Bu fonksiyon artık diğer kullanıcıların genel profilini
  // güvenli bir şekilde `/public_profiles` koleksiyonundan okur.
  // Mevcut giriş yapmış kullanıcının kendi tam profili için `streamCombinedUserModel` kullanılır.
  Stream<UserModel> getUserProfile(String userId) {
    return _publicProfileDoc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        // Belge yoksa veya boşsa, UI'da hata oluşmasını önlemek için
        // varsayılan bir UserModel döndür.
        return UserModel(id: userId, email: '', firstName: 'Kullanıcı', lastName: 'Bulunamadı', username: 'bulunamadi');
      }
      final data = doc.data()!;
      final name = data['name'] as String? ?? '';
      final parts = name.split(' ');
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      // `public_profiles`'tan gelen verilerle bir UserModel oluştur.
      // Özel alanlar (email, gender vb.) burada bulunmayacaktır, bu beklenen bir durumdur.
      return UserModel(
        id: userId,
        email: '', // Özel alan, public profilde yok.
        firstName: firstName,
        lastName: lastName,
        username: data['username'] as String? ?? '',
        name: name,
        avatarStyle: data['avatarStyle'] as String?,
        avatarSeed: data['avatarSeed'] as String?,
        selectedExam: data['selectedExam'] as String?,
        // İstatistikler de public profile ile senkronize edilir
        engagementScore: (data['engagementScore'] as num?)?.toInt() ?? 0,
        streak: (data['streak'] as num?)?.toInt() ?? 0,
        testCount: (data['testCount'] as num?)?.toInt() ?? 0,
        totalNetSum: (data['totalNetSum'] as num?)?.toDouble() ?? 0.0,
        followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
        followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Future<UserModel?> getUserById(String userId) async {
    final doc = await usersCollection.doc(userId).get();
    if(!doc.exists) {
      return null;
    }
    final user = UserModel.fromSnapshot(doc);
    final statsDoc = await _userStatsDoc(userId).get();
    final data = statsDoc.data() ?? <String, dynamic>{};
    return user.withStats(
      streak: (data['streak'] as num?)?.toInt(),
      testCount: (data['testCount'] as num?)?.toInt(),
      totalNetSum: (data['totalNetSum'] as num?)?.toDouble(),
      engagementScore: (data['engagementScore'] as num?)?.toInt(),
      lastStreakUpdate: (data['lastStreakUpdate'] as Timestamp?)?.toDate(),
    );
  }

  // YENİ: Kullanıcıları sayfalı olarak getirme
  Future<(List<UserModel> users, DocumentSnapshot? lastDoc)> getUsersPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = usersCollection
        .orderBy('username')
        .limit(limit);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final qs = await q.get();
    final users = qs.docs
        .map((d) => UserModel.fromSnapshot(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
    final last = qs.docs.isNotEmpty ? qs.docs.last : null;
    return (users, last);
  }


  // GÜNCEL: Puan güncelleme artık Cloud Function üzerinden yapılır
  Future<void> updateEngagementScore(String userId, int pointsToAdd) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('tests-addEngagementPoints');
      await callable.call({'pointsToAdd': pointsToAdd});
    } catch (_) {
      // istemci tarafında sessiz geç
    }
  }

  Future<void> addTestResult(TestModel test) async {
    // Güvenlik: Test ekleme + streak/puan/leaderboard sunucuda yapılır
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('tests-addTestResult');
      await callable.call({
        'testName': test.testName,
        'examType': test.examType.name,
        'sectionName': test.sectionName,
        'scores': test.scores,
        'penaltyCoefficient': test.penaltyCoefficient,
        'dateMs': test.date.millisecondsSinceEpoch,
      });
    } catch (e) {
      // Hatanın çağrıldığı yere yeniden fırlatılması, UI'ın hatayı yakalamasına olanak tanır.
      rethrow;
    }
  }

  // YENI SAYFALAMALI FONKSIYON
  Future<List<TestModel>> getTestResultsPaginated(String userId, {DocumentSnapshot? lastVisible, int limit = 20}) async {
    Query query = _testsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(limit);

    if (lastVisible != null) {
      query = query.startAfterDocument(lastVisible);
    }

    final qs = await query.get();
    return qs.docs.map((d) => TestModel.fromSnapshot(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  Future<void> saveExamSelection({
    required String userId,
    required ExamType examType,
    required String sectionName,
  }) async {
    // Yalnızca kullanıcı belgesini güncelle. Leaderboard/public_profiles
    // senkronizasyonu Cloud Function (onUserUpdate) tarafından yapılır.
    await usersCollection.doc(userId).update({
      'selectedExam': examType.name,
      'selectedExamSection': sectionName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<PlanDocument?> getPlansStream(String userId) {
    return _planDoc(userId).snapshots().map((doc) => doc.exists ? PlanDocument.fromSnapshot(doc) : null);
  }

  // Geri yüklendi: AppState akışı
  Stream<AppState?> getAppStateStream(String userId) {
    return _appStateDoc(userId).snapshots().map((doc) => doc.exists ? AppState.fromSnapshot(doc) : null);
  }

  Future<PerformanceSummary> getPerformanceSummaryOnce(String userId) async {
    final topicsSnap = await _topicPerformanceCollection(userId).get();
    final masteredSnap = await _masteredTopicsCollection(userId).get();

    final topics = topicsSnap.docs;
    final mastered = masteredSnap.docs.map((d) => d.id).toList();

    return PerformanceSummary.fromTopicDocs(topics, masteredTopics: mastered);
  }

  Future<void> updateTopicPerformance({
    required String userId,
    required String subject,
    required String topic,
    required TopicPerformanceModel performance,
  }) async {
    final sanitizedSubject = sanitizeKey(subject);
    final sanitizedTopic = sanitizeKey(topic);
    final docId = '${sanitizedSubject}_$sanitizedTopic';
    // Her konuyu ayrı bir dokümanda tut
    await _topicPerformanceCollection(userId).doc(docId).set({
      'subject': sanitizedSubject,
      'topic': sanitizedTopic,
      ...performance.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addFocusSession(FocusSessionModel session) async {
    await _focusSessionsCollection.add(session.toMap());
    await updateEngagementScore(session.userId, 25);
  }

  // YENI: Pomodoro seansını ve ilgili istatistikleri tek atomik işlemde kaydet
  Future<void> recordFocusSessionAndStats(FocusSessionModel session) async {
    final statsRef = _userStatsDoc(session.userId);
    final newSessionRef = _focusSessionsCollection.doc();
    final minutes = (session.durationInSeconds / 60).floor();
    final dailyRef = _userActivityDailyDoc(session.userId, session.date);
    final dateKey = _dateKey(session.date);

    await _firestore.runTransaction((txn) async {
      // Detay seans
      txn.set(newSessionRef, session.toMap());

      // Stats dokümanı (atomik artışlar)
      txn.set(statsRef, {
        'focusMinutes': FieldValue.increment(minutes),
        'engagementScore': FieldValue.increment(minutes), // Genel puan
        'pomodoroBp': FieldValue.increment(minutes),      // Sadece Pomodoro'dan kazanılan puan
        'pomodoroSessions': FieldValue.increment(1),
        'totalFocusSeconds': FieldValue.increment(session.durationInSeconds),
        // Son 30 güne yönelik hafifletilmiş rollup (UI haftalık/aylık sorguları azaltır)
        'focusRollup30.$dateKey': FieldValue.increment(minutes),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Günlük aktivite dokümanı
      final d0 = DateTime(session.date.year, session.date.month, session.date.day);
      txn.set(dailyRef, {
        'focusMinutes': FieldValue.increment(minutes),
        'date': Timestamp.fromDate(d0),
        'dateKey': dateKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // GÜNCEL: Günlük görev tamamlama (Ölçeklenebilir: Alt koleksiyon modeli)
  Future<void> updateDailyTaskCompletion({
    required String userId,
    required String dateKey, // yyyy-MM-dd
    required String task,    // '${time}-${activity}'
    required bool isCompleted,
  }) async {
    final dailyRef = _userActivityCollection(userId).doc(dateKey);
    final completedTasksCollection = dailyRef.collection('completed_tasks');
    final taskDocRef = completedTasksCollection.doc(task);

    if (isCompleted) {
      // Görevi tamamlandı olarak işaretle (doküman oluştur)
      await taskDocRef.set({
        'completedAt': FieldValue.serverTimestamp(),
        'taskId': task,
        'userId': userId, // Koleksiyon grubu sorguları için eklendi
      });
    } else {
      // Tamamlanmış görevi geri al (dokümanı sil)
      await taskDocRef.delete();
    }

    // Ana günlük dokümanı (meta veri için) oluştur/güncelle
    await dailyRef.set({
      'date': Timestamp.fromDate(DateTime.parse(dateKey)),
      'dateKey': dateKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateWeeklyAvailability({
    required String userId,
    required Map<String, List<String>> availability,
  }) async {
    await usersCollection.doc(userId).update({
      'weeklyAvailability': availability,
    });
  }

  Future<void> updateStrategicPlan({
    required String userId,
    required String pacing,
    required Map<String, dynamic> weeklyPlan,
  }) async {
    await _planDoc(userId).set({
      'studyPacing': pacing,
      'weeklyPlan': weeklyPlan,
    }, SetOptions(merge: true));
    await updateEngagementScore(userId, 100);
  }

  Future<void> markTopicAsMastered({required String userId, required String subject, required String topic}) async {
    final sanitizedSubject = sanitizeKey(subject);
    final sanitizedTopic = sanitizeKey(topic);
    final uniqueIdentifier = '$sanitizedSubject-$sanitizedTopic';
    // Alt koleksiyon: users/{uid}/performance/summary/masteredTopics/{uniqueIdentifier}
    await _masteredTopicsCollection(userId).doc(uniqueIdentifier).set({
      'subject': sanitizedSubject,
      'topic': sanitizedTopic,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }



  // YENİ: Optimize edilmiş anlık görüntüden tüm listeyi oku
  Future<List<LeaderboardEntry>> getLeaderboardSnapshot(String examType, {required String period}) async {
    final doc = await _leaderboardSnapshotDoc(examType, period).get();
    if (!doc.exists) return const <LeaderboardEntry>[];
    final data = doc.data()!;
    final List list = (data['entries'] as List?) ?? const [];
    return list.map((raw) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(raw as Map);
      return LeaderboardEntry(
        userId: (m['userId'] ?? '') as String,
        userName: (m['userName'] ?? '') as String,
        username: m['username'] as String?,
        score: ((m['score'] ?? 0) as num).toInt(),
        // rank alanı snapshot'tan doğrudan gelir
        rank: ((m['rank'] ?? 0) as num).toInt(),
        testCount: ((m['testCount'] ?? 0) as num).toInt(),
        avatarStyle: m['avatarStyle'] as String?,
        avatarSeed: m['avatarSeed'] as String?,
      );
    }).where((e) => e.userName.isNotEmpty).toList(growable: false);
  }

  // YENİ: Public profile oku (güvenli alanlar)
  Future<Map<String, dynamic>?> getPublicProfileRaw(String userId) async {
    final snap = await _publicProfileDoc(userId).get();
    if (snap.exists) return snap.data();

    // GERİYE DÖNÜK UYUMLULUK: public_profiles yoksa users + stats'tan güvenli alanları derle
    try {
      final userSnap = await usersCollection.doc(userId).get();
      if (!userSnap.exists) return null;
      final u = userSnap.data() ?? <String, dynamic>{};
      final statsSnap = await _userStatsDoc(userId).get();
      final s = statsSnap.data() ?? const <String, dynamic>{};

      return <String, dynamic>{
        'name': (u['name'] ?? '') as String,
        'testCount': ((s['testCount'] ?? u['testCount'] ?? 0) as num).toInt(),
        'totalNetSum': ((s['totalNetSum'] ?? u['totalNetSum'] ?? 0.0) as num).toDouble(),
        'engagementScore': ((s['engagementScore'] ?? u['engagementScore'] ?? 0) as num).toInt(),
        'streak': ((s['streak'] ?? u['streak'] ?? 0) as num).toInt(),
        'avatarStyle': u['avatarStyle'] as String?,
        'avatarSeed': u['avatarSeed'] as String?,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLeaderboardUserRaw(String examType, String userId) async {
    try {
      final doc = await _leaderboardUserDoc(examType: examType, userId: userId).get();
      if (!doc.exists) return null;
      final d = doc.data() ?? const <String, dynamic>{};
      return {
        'name': (d['userName'] ?? '') as String,
        'testCount': ((d['testCount'] ?? 0) as num).toInt(),
        'totalNetSum': 0.0, // liderlikte yok, 0 olarak dön
        'engagementScore': ((d['score'] ?? 0) as num).toInt(),
        'streak': 0, // liderlikte yok
        'avatarStyle': d['avatarStyle'] as String?,
        'avatarSeed': d['avatarSeed'] as String?,
      };
    } catch (_) {
      return null;
    }
  }

  // In-App Notifications
  Stream<List<InAppNotification>> streamInAppNotifications(String userId, {int limit = 100}) {
    return usersCollection
        .doc(userId)
        .collection('in_app_notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map((d) => InAppNotification.fromSnapshot(d as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Stream<int> streamUnreadInAppCount(String userId) {
    return usersCollection
        .doc(userId)
        .collection('in_app_notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((qs) => qs.size);
  }

  Future<void> markInAppNotificationRead(String userId, String notifId) async {
    await usersCollection
        .doc(userId)
        .collection('in_app_notifications')
        .doc(notifId)
        .set({'read': true, 'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> markAllInAppNotificationsRead(String userId) async {
    final col = usersCollection.doc(userId).collection('in_app_notifications');
    final qs = await col.where('read', isEqualTo: false).limit(300).get();
    if (qs.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final d in qs.docs) {
      batch.set(d.reference, {'read': true, 'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // YENI: In-app bildirimi tekil sil
  Future<void> deleteInAppNotification(String userId, String notifId) async {
    await usersCollection
        .doc(userId)
        .collection('in_app_notifications')
        .doc(notifId)
        .delete();
  }

  // YENI: Tüm in-app bildirimlerini temizle (parçalı batch ile)
  Future<void> clearAllInAppNotifications(String userId) async {
    final col = usersCollection.doc(userId).collection('in_app_notifications');
    while (true) {
      final qs = await col.limit(450).get();
      if (qs.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final d in qs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      // Döngü sonunda tekrar okuyup devam et
    }
  }

  // YENI: Belirli tarih aralığında günlük odak dakikalarını oku (user_activity)
  Future<Map<String, int>> getFocusMinutesInRange(String userId, {required DateTime start, required DateTime end}) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endNextDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    final qs = await _userActivityCollection(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
        .where('date', isLessThan: Timestamp.fromDate(endNextDay))
        .get();

    final Map<String, int> out = {};
    for (final doc in qs.docs) {
      final data = doc.data();
      final num? m = data['focusMinutes'] as num?;
      if (m != null) out[doc.id] = m.toInt();
    }
    return out;
  }

  // === EKSİK API’LER: USER + STATS BİRLEŞİK ===
  Stream<UserModel> streamCombinedUserModel(String userId) {
    return Stream<UserModel>.multi((controller) {
      UserModel? lastUser;
      Map<String, dynamic>? lastStats;

      void emitIfReady() {
        if (lastUser == null) return;
        final u = lastUser!;
        final streak = (lastStats?['streak'] as num?)?.toInt() ?? u.streak;
        final testCount = (lastStats?['testCount'] as num?)?.toInt() ?? u.testCount;
        final totalNetSum = (lastStats?['totalNetSum'] as num?)?.toDouble() ?? u.totalNetSum;
        final engagementScore = (lastStats?['engagementScore'] as num?)?.toInt() ?? u.engagementScore;
        final lastStreakUpdate = (lastStats?['lastStreakUpdate'] as Timestamp?)?.toDate() ?? u.lastStreakUpdate;
        controller.add(u.withStats(
          streak: streak,
          testCount: testCount,
          totalNetSum: totalNetSum,
          engagementScore: engagementScore,
          lastStreakUpdate: lastStreakUpdate,
        ));
      }

      final userSub = usersCollection.doc(userId).snapshots().listen((snap) {
        if (snap.exists) {
          lastUser = UserModel.fromSnapshot(snap);

          emitIfReady();
        }
      }, onError: controller.addError);

      final statsSub = _userStatsDoc(userId).snapshots().listen((snap) {
        lastStats = snap.data() ?? <String, dynamic>{};
        emitIfReady();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await userSub.cancel();
        await statsSub.cancel();
      };
    });
  }

  Stream<UserStats?> getUserStatsStream(String userId) {
    return _userStatsDoc(userId).snapshots().map((doc) => doc.exists ? UserStats.fromSnapshot(doc) : null);
  }

  Future<void> updateAnalysisSummary(String userId, StatsAnalysis analysis) {
    final summaryData = {
      'weakestSubjectByNet': analysis.weakestSubjectByNet,
      'strongestSubjectByNet': analysis.strongestSubjectByNet,
      'trend': analysis.trend,
      'warriorScore': analysis.warriorScore,
      'averageNet': analysis.averageNet,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return usersCollection
        .doc(userId)
        .collection('performance')
        .doc('analysis_summary')
        .set(summaryData, SetOptions(merge: true));
  }

  /// YENİ: Quests collection genel erişim metodu
  CollectionReference<Map<String, dynamic>> questsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('daily_quests');
  }

  // === /TAKIP SISTEMI ===

  Future<void> updateUserDocument(String userId, Map<String, dynamic> fields) async {
    await usersCollection.doc(userId).set(fields, SetOptions(merge: true));
  }

  /// Daily quests stream
  Stream<List<Quest>> streamDailyQuests(String userId) {
    return questsCollection(userId)
        .orderBy('qid')
        .snapshots()
        .map((qs) => qs.docs.map((d) => Quest.fromMap(d.data(), d.id)).toList());
  }

  /// Single read helpers for quests
  Future<List<Quest>> getDailyQuestsOnce(String userId) async {
    final snapshot = await questsCollection(userId).orderBy('qid').get();
    return snapshot.docs.map((d) => Quest.fromMap(d.data(), d.id)).toList();
  }

  // weekly/monthly streams already used earlier rely on weeklyQuestsCollection/monthlyQuestsCollection

  /// Update arbitrary quest fields
  Future<void> updateQuestFields(String userId, String questId, Map<String, dynamic> fields) async {
    await questsCollection(userId).doc(questId).set(fields, SetOptions(merge: true));
  }

  /// Claim quest reward (marks rewardClaimed and increments user BP)
  Future<void> claimQuestReward(String userId, Quest quest) async {
    final reward = quest.calculateDynamicReward();

    final batch = _firestore.batch();

    // Mark quest as claimed in the daily_quests collection
    final questRef = questsCollection(userId).doc(quest.id);
    batch.set(questRef, {'rewardClaimed': true, 'rewardClaimedAt': FieldValue.serverTimestamp(), 'actualReward': reward}, SetOptions(merge: true));

    // Update the engagementScore in the stats document, which triggers other backend processes
    final statsRef = usersCollection.doc(userId).collection('state').doc('stats');
    batch.set(statsRef, {
      'engagementScore': FieldValue.increment(reward),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    // The leaderboard sync is now handled by the onUserStatsWritten trigger, so no need to call it here.
  }

  /// Report question issue (creates report and updates index)
  /// Soru raporu gönderir. Başarı/hata durumunu Map olarak döndürür.
  /// { 'success': true } veya { 'success': false, 'message': 'Hata mesajı' }
  Future<Map<String, dynamic>> reportQuestionIssue({
    required String userId,
    required String subject,
    required String topic,
    required String question,
    required List<String> options,
    required int correctIndex,
    int? selectedIndex,
    required String reason,
  }) async {
    try {
      // ESKİ: qhash hesaplaması ve payload oluşturma istemcideydi.
      // YENİ: Payload'ı sunucuya gönderiyoruz, qhash orada hesaplanacak.
      final payload = {
        // 'reporterId' GEREKMEZ, sunucu auth context'ten alır
        'subject': subject,
        'topic': topic,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'selectedIndex': selectedIndex,
        'reason': reason,
        // 'qhash' GEREKMEZ, sunucu hesaplar
        // 'createdAt' GEREKMEZ, sunucu ekler
      };

      // ESKİ: _questionReportsCollection.add(payload);
      // ESKİ: idxRef.set(...);

      // YENİ: Güvenli ve hız limitli callable function'ı çağır
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('reports-submitQuestionReport');

      // App Check token'ının hazır olduğundan emin ol (çok önemli)
      await ensureAppCheckTokenReady();

      // Fonksiyonu çağır
      await callable.call(payload);

      return {'success': true};

    } catch (e) {
      if (kDebugMode) {
        print('Soru raporlama hatası: $e');
      }

      if (e is FirebaseFunctionsException) {
        if (e.code == 'resource-exhausted') {
          return {
            'success': false,
            'message': 'Çok fazla rapor gönderdiniz. Lütfen 5 dakika bekleyip tekrar deneyin.'
          };
        } else if (e.code == 'already-exists') {
          return {
            'success': false,
            'message': 'Bu soruyu daha önce rapor ettiniz.'
          };
        } else if (e.code == 'unauthenticated') {
          return {
            'success': false,
            'message': 'Oturum gerekli. Lütfen giriş yapın.'
          };
        } else if (e.code == 'invalid-argument') {
          return {
            'success': false,
            'message': 'Geçersiz rapor verisi. Lütfen tüm alanları doldurun.'
          };
        }
      }

      // Diğer hatalar için genel mesaj
      return {
        'success': false,
        'message': 'Rapor gönderilirken bir hata oluştu. Lütfen tekrar deneyin.'
      };
    }
  }

  /// --- FOLLOW / SOCIAL ---
  CollectionReference<Map<String, dynamic>> _followersCollection(String userId) =>
      usersCollection.doc(userId).collection('followers');
  CollectionReference<Map<String, dynamic>> _followingCollection(String userId) =>
      usersCollection.doc(userId).collection('following');

  /// Stream follower ids
  Stream<List<String>> streamFollowerIds(String userId) {
    return _followersCollection(userId).snapshots().map((qs) => qs.docs.map((d) => d.id).toList());
  }

  /// Stream following ids
  Stream<List<String>> streamFollowingIds(String userId) {
    return _followingCollection(userId).snapshots().map((qs) => qs.docs.map((d) => d.id).toList());
  }

  /// Stream whether me is following target
  Stream<bool> streamIsFollowing(String meUserId, String targetUserId) {
    return _followersCollection(targetUserId)
        .doc(meUserId)
        .snapshots()
        .map((snap) => snap.exists);
  }


  /// Follow a user (adds docs both sides)
  // GÜVENLİK GÜNCELLEMESİ: Sayaç güncellemeleri artık Cloud Function tarafından yapılıyor.
  // İstemci yalnızca takip ilişkisini oluşturan dokümanları ekler.
  Future<void> followUser({required String currentUserId, required String targetUserId}) async {
    if (currentUserId == targetUserId) return;
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    // Takip edilen kullanıcının 'followers' alt koleksiyonuna takip edeni ekle
    batch.set(_followersCollection(targetUserId).doc(currentUserId), {'createdAt': now});
    // Takip eden kullanıcının 'following' alt koleksiyonuna takip edileni ekle
    batch.set(_followingCollection(currentUserId).doc(targetUserId), {'createdAt': now});
    await batch.commit();
  }

  /// Unfollow a user
  // GÜVENLİK GÜNCELLEMESİ: Sayaç güncellemeleri artık Cloud Function tarafından yapılıyor.
  // İstemci yalnızca takip ilişkisini bozan dokümanları siler.
  Future<void> unfollowUser({required String currentUserId, required String targetUserId}) async {
    if (currentUserId == targetUserId) return;
    final batch = _firestore.batch();
    // İlgili dokümanları her iki taraftan da sil
    batch.delete(_followersCollection(targetUserId).doc(currentUserId));
    batch.delete(_followingCollection(currentUserId).doc(targetUserId));
    await batch.commit();
  }

  /// Search users by username only - OPTIMIZE EDİLMİŞ VE GÜVENLİ
  /// Sadece public_profiles koleksiyonunda username alanında arama yapar
  /// Bu yöntem hem güvenli hem de maliyet optimizasyonludur
  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query) async {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.trim().toLowerCase();

    try {
      // Sadece public_profiles koleksiyonunda username ile arama
      final searchQuery = _firestore
          .collection('public_profiles')
          .where('username', isGreaterThanOrEqualTo: normalizedQuery)
          .where('username', isLessThan: '$normalizedQuery\uf8ff')
          .limit(20);

      final querySnapshot = await searchQuery.get();

      final results = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['userId'] = doc.id; // Sonuçlara userId'yi ekle
        return data;
      }).toList();

      return results;

    } catch (e) {
      print('Error searching users by username: $e');
      return [];
    }
  }

  /// Generate search keywords for better search functionality
  List<String> _generateSearchKeywords(String text) {
    final keywords = <String>[];
    final normalizedText = text.toLowerCase().trim();

    // Add the full text
    keywords.add(normalizedText);

    // Add substrings starting from beginning
    for (int i = 1; i <= normalizedText.length; i++) {
      keywords.add(normalizedText.substring(0, i));
    }

    // Add individual words
    final words = normalizedText.split(' ');
    for (String word in words) {
      if (word.isNotEmpty) {
        keywords.add(word);
        // Add substrings of each word
        for (int i = 1; i <= word.length; i++) {
          keywords.add(word.substring(0, i));
        }
      }
    }

    return keywords.toSet().toList();
  }

  /// Update user's searchable keywords when profile is updated
  Future<void> updateSearchableKeywords(String userId, String name) async {
    try {
      final keywords = _generateSearchKeywords(name);
      await _firestore.collection('public_profiles').doc(userId).set({
        'name': name,
        'searchableKeywords': keywords,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating searchable keywords: $e');
    }
  }

  /// Batch update all users' searchable keywords (for migration)
  Future<void> updateAllUsersSearchableKeywords() async {
    print('Starting batch update of user searchable keywords...');
    try {
      // Get all users in batches
      final allUsers = await usersCollection.get();
      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in allUsers.docs) {
        final data = doc.data();
        final name = data['name'] as String?;

        if (name != null && name.trim().isNotEmpty) {
          final keywords = _generateSearchKeywords(name);
          final publicProfileRef = _firestore.collection('public_profiles').doc(doc.id);

          batch.set(publicProfileRef, {
            'name': name,
            'searchableKeywords': keywords,
            'avatarStyle': data['avatarStyle'],
            'avatarSeed': data['avatarSeed'],
            'selectedExam': data['selectedExam'],
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          updateCount++;

          // Commit in batches of 450 (Firestore limit is 500)
          if (updateCount % 450 == 0) {
            await batch.commit();
            print('Updated $updateCount users so far...');
          }
        }
      }

      // Commit remaining operations
      await batch.commit();
      print('Successfully updated searchable keywords for $updateCount users');
    } catch (e) {
      print('Error in batch update: $e');
    }
  }

  Future<void> resetUserDataForNewExam() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('users-resetUserDataForNewExam');
      await callable.call(<String, dynamic>{});
    } catch (e) {
      rethrow;
    }
  }
}
