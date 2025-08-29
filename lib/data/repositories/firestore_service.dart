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
import 'package:bilge_ai/data/models/plan_model.dart';
import 'package:bilge_ai/data/models/plan_document.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:bilge_ai/data/models/app_state.dart';
import 'package:bilge_ai/features/arena/models/leaderboard_entry_model.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:bilge_ai/data/models/user_stats_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;
  FirestoreService(this._firestore);

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

  // YENI: Kullanıcı aktivite alt koleksiyonu (Günlük dokümanlar)
  CollectionReference<Map<String, dynamic>> _userActivityCollection(String userId) => usersCollection.doc(userId).collection('user_activity');
  // Günlük aktivite dokümanı: users/{uid}/user_activity/YYYY-MM-DD
  DocumentReference<Map<String, dynamic>> _userActivityDailyDoc(String userId, DateTime date) {
    final id = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _userActivityCollection(userId).doc(id);
  }

  // ESKI: Aylık referans (artık kullanılmıyor ama geriye dönük ihtiyaç olursa dursun)
  DocumentReference<Map<String, dynamic>> _userActivityMonthlyDoc(String userId, DateTime date) {
    final id = '${date.year.toString().padLeft(4, '0')}_${date.month.toString().padLeft(2, '0')}';
    return _userActivityCollection(userId).doc(id);
  }

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

  Stream<List<SavedWorkshopModel>> getSavedWorkshops(String userId) {
    return usersCollection
        .doc(userId)
        .collection('savedWorkshops')
        .orderBy('savedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SavedWorkshopModel.fromSnapshot(doc)).toList());
  }

  Future<void> createUserProfile(User user, String name) async {
    final userProfile = UserModel(id: user.uid, email: user.email!, name: name, tutorialCompleted: false);
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
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userDocRef);
      final data = snap.data();
      final String? examType = data?['selectedExam'];
      txn.update(userDocRef, {'name': newName});
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

  // GÜNCEL: Puan güncelleme stats dokümanında
  Future<void> updateEngagementScore(String userId, int pointsToAdd) async {
    await _userStatsDoc(userId).set({
      'engagementScore': FieldValue.increment(pointsToAdd),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Liderlik tablosu senkronu idealde Cloud Function ile yapılmalı.
  }

  Future<void> addTestResult(TestModel test) async {
    // Testi ekle ve stats sayaçlarını arttır + streak hesapla
    final newTestRef = _testsCollection.doc();
    final statsRef = _userStatsDoc(test.userId);
    await _firestore.runTransaction((txn) async {
      // ÖNCE OKU
      final statsSnap = await txn.get(statsRef);
      final stats = statsSnap.data() ?? <String, dynamic>{};
      final Timestamp? lastTs = stats['lastStreakUpdate'] as Timestamp?;
      final int currentStreak = (stats['streak'] as num?)?.toInt() ?? 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int newStreak;
      if (lastTs == null) {
        newStreak = 1;
      } else {
        final lastDate = lastTs.toDate();
        final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
        if (lastDay == today) {
          newStreak = currentStreak; // aynı gün tekrar test
        } else {
          final yesterday = today.subtract(const Duration(days: 1));
          if (lastDay == yesterday) {
            newStreak = currentStreak + 1;
          } else {
            newStreak = 1;
          }
        }
      }

      // SONRA YAZ
      txn.set(newTestRef, test.toJson());
      txn.set(statsRef, {
        'testCount': FieldValue.increment(1),
        'totalNetSum': FieldValue.increment(test.totalNet),
        'streak': newStreak,
        'lastStreakUpdate': Timestamp.fromDate(today),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    await updateEngagementScore(test.userId, 50);
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
    required String longTermStrategy,
    required Map<String, dynamic> weeklyPlan,
  }) async {
    await _planDoc(userId).set({
      'studyPacing': pacing,
      'longTermStrategy': longTermStrategy,
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
        score: (data['score'] ?? 0) as int,
        testCount: (data['testCount'] ?? 0) as int,
        avatarStyle: data['avatarStyle'] as String?,
        avatarSeed: data['avatarSeed'] as String?,
      );
    }).where((e) => e.userName.isNotEmpty).toList();
  }

  CollectionReference<Map<String, dynamic>> dailyQuestsCollection(String userId) => usersCollection.doc(userId).collection('daily_quests');

  Stream<List<Quest>> streamDailyQuests(String userId) {
    return dailyQuestsCollection(userId)
        .orderBy('qid')
        .snapshots()
        .map((qs) => qs.docs.map((d) => Quest.fromMap(d.data(), d.id)).toList());
  }

  Future<List<Quest>> getDailyQuestsOnce(String userId) async {
    final qs = await dailyQuestsCollection(userId).orderBy('qid').get();
    return qs.docs.map((d) => Quest.fromMap(d.data(), d.id)).toList();
  }

  Future<void> replaceAllDailyQuests(String userId, List<Quest> quests) async {
    final col = dailyQuestsCollection(userId);
    final batch = _firestore.batch();
    final existing = await col.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final q in quests) {
      batch.set(col.doc(q.id), q.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> upsertQuest(String userId, Quest quest) async {
    await dailyQuestsCollection(userId).doc(quest.id).set(quest.toMap(), SetOptions(merge: true));
  }

  Future<void> updateQuestFields(String userId, String questId, Map<String, dynamic> fields) async {
    await dailyQuestsCollection(userId).doc(questId).update(fields);
  }

  Future<void> batchUpdateQuestFields(String userId, Map<String, Map<String, dynamic>> updates, {int? engagementDelta}) async {
    final batch = _firestore.batch();
    // Stats'a yaz
    if (engagementDelta != null && engagementDelta != 0) {
      batch.set(_userStatsDoc(userId), {
        'engagementScore': FieldValue.increment(engagementDelta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    updates.forEach((questId, fields) {
      batch.update(dailyQuestsCollection(userId).doc(questId), fields);
    });
    await batch.commit();
  }

  Future<void> claimQuestReward(String userId, Quest quest) async {
    final batch = _firestore.batch();
    final questRef = dailyQuestsCollection(userId).doc(quest.id);
    // Ödül alınırken görevin tamamlanmasını garanti altına al
    batch.update(questRef, {
      'rewardClaimed': true,
      'isCompleted': true,
      'currentProgress': quest.goalValue,
      'completionDate': FieldValue.serverTimestamp(),
    });

    // Puanı stats'a yaz
    batch.set(_userStatsDoc(userId), {
      'engagementScore': FieldValue.increment(quest.reward),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    await _syncLeaderboardUser(userId); // Skoru liderlik tablosuna yansıt
  }

  // ISTEGE BAGLI: Tek kullanımlık migrate yardımcısı. Client tarafında sadece tek kullanıcı için güvenli.
  Future<void> migrateActiveDailyQuestsForUser(String userId) async {
    final userDoc = await usersCollection.doc(userId).get();
    if (!userDoc.exists) return;
    final data = userDoc.data()!;
    if (data['activeDailyQuests'] is! List) return;
    final List active = data['activeDailyQuests'];
    final List<Quest> quests = [];
    for (final e in active) {
      if (e is Map<String, dynamic>) {
        final dynamic rawId = e['qid'] ?? e['id'];
        if (rawId != null) {
          quests.add(Quest.fromMap(e, rawId.toString()));
        }
      }
    }
    if (quests.isEmpty) return;
    await replaceAllDailyQuests(userId, quests);
    // Alanı temizle
    await usersCollection.doc(userId).update({'activeDailyQuests': FieldValue.delete()});
  }

  String _weekdayName(int weekday) {
    const list = ['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'];
    return list[(weekday-1).clamp(0,6)];
  }

  // YENI: Analiz özetini küçük bir dokümana yaz
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

  // Stats stream/once
  Stream<UserStats> getUserStatsStream(String userId) {
    return _userStatsDoc(userId).snapshots().map((doc) => UserStats.fromSnapshot(doc));
  }

  Future<UserStats> getUserStatsOnce(String userId) async {
    final doc = await _userStatsDoc(userId).get();
    return UserStats.fromSnapshot(doc);
  }

  // KÖK kullanıcı dokümanı ile stats dokümanını birleştiren akış
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
}

