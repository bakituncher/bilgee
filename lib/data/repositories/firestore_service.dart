// lib/data/repositories/firestore_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/data/models/topic_performance_model.dart';
import 'package:bilge_ai/data/models/focus_session_model.dart';
import 'package:bilge_ai/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:bilge_ai/data/models/plan_document.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:bilge_ai/data/models/app_state.dart';
import 'package:bilge_ai/features/arena/models/leaderboard_entry_model.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:bilge_ai/data/models/user_stats_model.dart';
import 'package:bilge_ai/features/blog/models/blog_post.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
import 'package:bilge_ai/shared/notifications/in_app_notification_model.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
    final normalized = (question.trim().toLowerCase() + '|' + options.map((o) => o.trim().toLowerCase()).join('||'));
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

  // GÜNCEL: Haftalık tamamlanan görevler (7 günlük günlük doküman okuması)
  Future<Map<String, List<String>>> getCompletedTasksForWeek(String userId, DateTime weekStart) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final days = List<DateTime>.generate(7, (i) => start.add(Duration(days: i)));
    final results = await Future.wait(days.map((d) async {
      final list = await getCompletedTasksForDate(userId, d);
      return MapEntry(_dateKey(d), list);
    }));
    return Map<String, List<String>>.fromEntries(results);
  }

  // YENİ: Belirli bir tarih aralığındaki (start dahil, end dahil) günlerin tamamlanan görevlerini tek sorguda getir
  Future<Map<String, List<String>>> getCompletedTasksInRange(String userId, {required DateTime start, required DateTime end}) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endNextDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final qs = await _userActivityCollection(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
        .where('date', isLessThan: Timestamp.fromDate(endNextDay))
        .get();
    final Map<String, List<String>> out = {};
    for (final doc in qs.docs) {
      final data = doc.data();
      final v = data['completedTasks'];
      if (v is List && v.isNotEmpty) {
        out[doc.id] = v.map((e) => e.toString()).toList();
      }
    }
    return out;
  }

  // GÜNCEL: Ay içindeki tüm ziyaretleri getir (günlük dokümanları aralıktan sorgula)
  Future<List<Timestamp>> getVisitsForMonth(String userId, DateTime anyDayInMonth) async {
    final monthStart = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final nextMonth = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);
    final startTs = Timestamp.fromDate(monthStart);
    final endTs = Timestamp.fromDate(nextMonth);

    final qs = await _userActivityCollection(userId)
        .where('date', isGreaterThanOrEqualTo: startTs)
        .where('date', isLessThan: endTs)
        .get();
    final List<Timestamp> visits = [];
    for (final d in qs.docs) {
      final v = d.data()['visits'];
      if (v is List) {
        visits.addAll(v.whereType<Timestamp>());
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

  // GÜNCEL: Ziyaret kaydı (günlük doküman)
  Future<void> recordUserVisit(String userId, {Timestamp? at}) async {
    final nowTs = at ?? Timestamp.now();
    final now = nowTs.toDate();
    final d0 = DateTime(now.year, now.month, now.day);
    final dailyRef = _userActivityDailyDoc(userId, now);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(dailyRef);
      final data = snap.data() ?? <String, dynamic>{};
      final List<Timestamp> visits = List<Timestamp>.from(data['visits'] ?? const <Timestamp>[]);
      visits.sort((a, b) => a.compareTo(b));
      if (visits.isEmpty || now.difference(visits.last.toDate()).inHours >= 1) {
        visits.add(nowTs);
      }
      txn.set(dailyRef, {
        'visits': visits,
        'date': Timestamp.fromDate(d0),
        'dateKey': _dateKey(d0),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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
  }) async {
    final userProfile = UserModel(
      id: user.uid,
      email: user.email!,
      firstName: firstName,
      lastName: lastName,
      username: username,
      gender: gender,
      dateOfBirth: dateOfBirth,
      tutorialCompleted: false,
    );
    await usersCollection.doc(user.uid).set(userProfile.toJson());
    // Stats başlangıç değerleri
    await _userStatsDoc(user.uid).set({
      'streak': 0,
      'testCount': 0,
      'totalNetSum': 0.0,
      'engagementScore': 0,
      'lastStreakUpdate': null,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _appStateDoc(user.uid).set(AppState().toMap(), SetOptions(merge: true));
    await _planDoc(user.uid).set(PlanDocument().toMap(), SetOptions(merge: true));
    await _performanceDoc(user.uid).set(const PerformanceSummary().toMap(), SetOptions(merge: true));
  }

  Future<void> updateUserName({required String userId, required String newName}) async {
    final userDocRef = usersCollection.doc(userId);
    final parts = newName.split(' ');
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userDocRef);
      final data = snap.data();
      final String? examType = data?['selectedExam'];
      txn.update(userDocRef, {
        'name': newName,
        'firstName': firstName,
        'lastName': lastName,
      });
      if (examType != null) {
        final statsSnap = await txn.get(_userStatsDoc(userId));
        final stats = statsSnap.data() ?? const <String, dynamic>{};
        final lbRef = _leaderboardUserDoc(examType: examType, userId: userId);
        txn.set(lbRef, {
          'userId': userId,
          'userName': newName,
          'score': stats['engagementScore'] ?? 0,
          'testCount': stats['testCount'] ?? 0,
          'avatarStyle': data?['avatarStyle'],
          'avatarSeed': data?['avatarSeed'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> markTutorialAsCompleted(String userId) async {
    await _appStateDoc(userId).set({'tutorialCompleted': true}, SetOptions(merge: true));
    await usersCollection.doc(userId).update({'tutorialCompleted': true});
  }

  Future<void> updateOnboardingData({
    required String userId,
    required String goal,
    required List<String> challenges,
    required double weeklyStudyGoal,
  }) async {
    await usersCollection.doc(userId).update({
      'goal': goal,
      'challenges': challenges,
      'weeklyStudyGoal': weeklyStudyGoal,
    });
    await _appStateDoc(userId).set({'onboardingCompleted': true}, SetOptions(merge: true));
    await usersCollection.doc(userId).update({'onboardingCompleted': true});
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    final userDocRef = usersCollection.doc(userId);

    // Also update the full name for backward compatibility
    if (data.containsKey('firstName') || data.containsKey('lastName')) {
      final userSnap = await userDocRef.get();
      final existingData = userSnap.data() ?? {};
      final firstName = data['firstName'] ?? existingData['firstName'] ?? '';
      final lastName = data['lastName'] ?? existingData['lastName'] ?? '';
      data['name'] = '$firstName $lastName'.trim();
    }

    await userDocRef.update(data);

    // Update leaderboard if name changed
    if (data.containsKey('name')) {
      final userSnap = await userDocRef.get();
      final userData = userSnap.data();
      final String? examType = userData?['selectedExam'];
      if (examType != null) {
        final lbRef = _leaderboardUserDoc(examType: examType, userId: userId);
        await lbRef.set({'userName': data['name'], 'username': data['username']}, SetOptions(merge: true));
      }
    }
  }

  Stream<UserModel> getUserProfile(String userId) {
    return usersCollection.doc(userId).snapshots().map((doc) => UserModel.fromSnapshot(doc));
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

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await usersCollection.get();
    return snapshot.docs.map((doc) => UserModel.fromSnapshot(doc)).toList();
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
    final userDocRef = usersCollection.doc(userId);
    await _firestore.runTransaction((txn) async {
      // *** HATA DÜZELTİLDİ: ÖNCE TÜM OKUMALARI YAP ***
      final prevSnap = await txn.get(userDocRef);
      final statsSnap = await txn.get(_userStatsDoc(userId));

      // *** OKUMA SONUÇLARINI DEĞİŞKENLERE ATA ***
      final prevData = prevSnap.data();
      final stats = statsSnap.data() ?? const <String, dynamic>{};
      final String? prevExam = prevData?['selectedExam'];

      // *** ŞİMDİ GÜVENLE TÜM YAZMALARI YAP ***
      txn.update(userDocRef, {
        'selectedExam': examType.name,
        'selectedExamSection': sectionName,
      });

      if (prevExam != null && prevExam != examType.name) {
        final oldLbRef = _leaderboardUserDoc(examType: prevExam, userId: userId);
        txn.delete(oldLbRef);
      }

      final newLbRef = _leaderboardUserDoc(examType: examType.name, userId: userId);
      txn.set(newLbRef, {
        'userId': userId,
        'userName': prevData?['name'],
        'score': stats['engagementScore'] ?? 0,
        'testCount': stats['testCount'] ?? 0,
        'avatarStyle': prevData?['avatarStyle'],
        'avatarSeed': prevData?['avatarSeed'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    final docId = '${sanitizedSubject}_${sanitizedTopic}';
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

  // GÜNCEL: Günlük görev tamamlama basitleştirildi (günlük doküman + stats artış)
  Future<void> updateDailyTaskCompletion({
    required String userId,
    required String dateKey, // yyyy-MM-dd
    required String task,    // '${time}-${activity}'
    required bool isCompleted,
  }) async {
    final dailyRef = _userActivityCollection(userId).doc(dateKey);
    // arrayUnion/arrayRemove ile atomik güncelleme
    await dailyRef.set({
      'completedTasks': isCompleted
          ? FieldValue.arrayUnion([task])
          : FieldValue.arrayRemove([task]),
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

  Future<void> resetUserDataForNewExam(String userId) async {
    final WriteBatch batch = _firestore.batch();
    final userDocRef = usersCollection.doc(userId);
    batch.update(userDocRef, {
      'onboardingCompleted': false,
      'tutorialCompleted': false,
      'selectedExam': null,
      'selectedExamSection': null,
      // Kökteki sayaçları temizleme (artık stats'ta tutuluyor)
      'weeklyAvailability': {},
      'goal': null,
      'challenges': [],
      'weeklyStudyGoal': null,
    });

    // Stats sıfırla
    final statsRef = _userStatsDoc(userId);
    batch.set(statsRef, {
      'streak': 0,
      'lastStreakUpdate': null,
      'testCount': 0,
      'totalNetSum': 0.0,
      'engagementScore': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_performanceDoc(userId), const PerformanceSummary().toMap());
    batch.set(_planDoc(userId), PlanDocument().toMap());

    final testsSnapshot = await _testsCollection.where('userId', isEqualTo: userId).get();
    for (final doc in testsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final focusSnapshot = await _focusSessionsCollection.where('userId', isEqualTo: userId).get();
    for (final doc in focusSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // user_activity alt koleksiyonunu temizle
    final activitySnap = await _userActivityCollection(userId).get();
    for (final doc in activitySnap.docs) {
      batch.delete(doc.reference);
    }

    // topic_performance alt koleksiyonunu temizle
    final topicSnap = await _topicPerformanceCollection(userId).get();
    for (final doc in topicSnap.docs) {
      batch.delete(doc.reference);
    }

    // masteredTopics alt koleksiyonunu temizle
    final masteredSnap = await _masteredTopicsCollection(userId).get();
    for (final doc in masteredSnap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<List<LeaderboardEntry>> getLeaderboardUsers(String examType) async {
    final snapshot = await _leaderboardsCollection
        .doc(examType)
        .collection('users')
        .orderBy('score', descending: true)
        .limit(100)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return LeaderboardEntry(
        userId: data['userId'] ?? doc.id,
        userName: (data['userName'] ?? '') as String,
        username: data['username'] as String?,
        score: (data['score'] ?? 0) as int,
        testCount: (data['testCount'] ?? 0) as int,
        avatarStyle: data['avatarStyle'] as String?,
        avatarSeed: data['avatarSeed'] as String?,
      );
    }).where((e) => e.userName.isNotEmpty).toList();
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
  Future<void> reportQuestionIssue({
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
      final qhash = _computeQuestionHash(question, options);
      final payload = {
        'reporterId': userId,
        'subject': subject,
        'topic': topic,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'selectedIndex': selectedIndex,
        'reason': reason,
        'qhash': qhash,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _questionReportsCollection.add(payload);

      // Index increment (reportCount)
      final idxRef = _questionReportsIndexCollection.doc(qhash);
      await idxRef.set({
        'qhash': qhash,
        'lastReportedAt': FieldValue.serverTimestamp(),
        'reportCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore errors to avoid blocking UI
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

  /// Stream follow counts as a record (followers, following)
  Stream<(int followers, int following)> streamFollowCounts(String userId) {
    return Stream<(int, int)>.multi((controller) {
      int? lastFollowers;
      int? lastFollowing;

      void emitIfReady() {
        if (lastFollowers == null || lastFollowing == null) return;
        controller.add((lastFollowers!, lastFollowing!));
      }

      final subF = _followersCollection(userId).snapshots().listen((qs) {
        lastFollowers = qs.size;
        emitIfReady();
      }, onError: controller.addError);

      final subG = _followingCollection(userId).snapshots().listen((qs) {
        lastFollowing = qs.size;
        emitIfReady();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await subF.cancel();
        await subG.cancel();
      };
    });
  }

  /// Follow a user (adds docs both sides)
  Future<void> followUser({required String currentUserId, required String targetUserId}) async {
    if (currentUserId == targetUserId) return;
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    batch.set(_followersCollection(targetUserId).doc(currentUserId), {'createdAt': now});
    batch.set(_followingCollection(currentUserId).doc(targetUserId), {'createdAt': now});

    // Optionally update counters on user docs
    batch.set(usersCollection.doc(targetUserId), {'followerCount': FieldValue.increment(1)}, SetOptions(merge: true));
    batch.set(usersCollection.doc(currentUserId), {'followingCount': FieldValue.increment(1)}, SetOptions(merge: true));

    await batch.commit();
  }

  /// Unfollow a user
  Future<void> unfollowUser({required String currentUserId, required String targetUserId}) async {
    if (currentUserId == targetUserId) return;
    final batch = _firestore.batch();
    batch.delete(_followersCollection(targetUserId).doc(currentUserId));
    batch.delete(_followingCollection(currentUserId).doc(targetUserId));

    batch.set(usersCollection.doc(targetUserId), {'followerCount': FieldValue.increment(-1)}, SetOptions(merge: true));
    batch.set(usersCollection.doc(currentUserId), {'followingCount': FieldValue.increment(-1)}, SetOptions(merge: true));

    await batch.commit();
  }

}
