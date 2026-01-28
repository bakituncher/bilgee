import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications/in_app_notification_model.dart';

/// Global Kampanya Servisi
///
/// Bu servis, admin tarafından oluşturulan global kampanyaları "Pull" modeliyle çeker.
/// Tek tek kullanıcılara yazma yerine, tüm kullanıcılar global koleksiyondan okur.
///
/// Avantajları:
/// - 100.000 kullanıcı için 100.000 yazma yerine 1 yazma
/// - Hızlı ve ölçeklenebilir
/// - Maliyet optimizasyonu
class GlobalCampaignService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GlobalCampaignService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Aktif global kampanyaları getir (Future)
  ///
  /// Kullanıcının daha önce kapattığı kampanyaları filtreler.
  /// Okundu durumunu 'readCampaignIds' listesinden kontrol eder.
  Future<List<InAppNotification>> fetchGlobalCampaigns() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      // 1. Aktif global kampanyaları çek (son 5 kampanya)
      final campaignsSnap = await _firestore
          .collection('global_campaigns')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (campaignsSnap.docs.isEmpty) return [];

      // 2. Kullanıcının kapattığı ve okuduğu kampanyaları çek
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      final List<dynamic> closedCampaigns = userData?['closedCampaignIds'] ?? [];
      final List<dynamic> readCampaigns = userData?['readCampaignIds'] ?? [];

      // 3. Kapatılmamış kampanyaları modele çevir
      final campaigns = campaignsSnap.docs
          .where((doc) => !closedCampaigns.contains(doc.id))
          .map((doc) {
        final data = doc.data();
        // Okundu bilgisini kontrol et
        final isRead = readCampaigns.contains(doc.id);

        return InAppNotification(
          id: doc.id,
          title: data['title'] ?? '',
          body: data['body'] ?? '',
          imageUrl: data['imageUrl']?.toString().isNotEmpty == true ? data['imageUrl'] as String : null,
          route: data['route'] ?? '/home',
          type: 'global_campaign',
          read: isRead, // Dinamik okundu durumu
          createdAt: data['createdAt'] as Timestamp?,
        );
      })
          .toList();

      return campaigns;
    } catch (e) {
      print('❌ Global kampanyalar alınırken hata: $e');
      return [];
    }
  }

  /// Kullanıcının özel bildirimleri ile global kampanyaları birleştir
  ///
  /// Kullanıcının bildirim listesini çekerken bu fonksiyonu kullanın
  Future<List<InAppNotification>> fetchAllNotifications() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      // 1. Kullanıcının özel bildirimlerini çek
      final userNotificationsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('in_app_notifications')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final userNotifications = userNotificationsSnap.docs
          .map((doc) => InAppNotification.fromSnapshot(doc))
          .toList();

      // 2. Global kampanyaları çek (Güncellenmiş mantıkla)
      final globalCampaigns = await fetchGlobalCampaigns();

      // 3. İki listeyi birleştir ve tarihe göre sırala
      final allNotifications = [...globalCampaigns, ...userNotifications];
      allNotifications.sort((a, b) {
        final aTime = a.createdAt?.toDate() ?? DateTime.now();
        final bTime = b.createdAt?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      return allNotifications;
    } catch (e) {
      print('❌ Bildirimler alınırken hata: $e');
      return [];
    }
  }

  /// Global kampanyayı kapat (kullanıcı dismiss/close yaptığında veya sildiğinde)
  ///
  /// [campaignId]: Kapatılacak kampanyanın ID'si
  Future<void> closeGlobalCampaign(String campaignId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Kullanıcının kapattığı kampanyalar listesine ekle
      await _firestore.collection('users').doc(userId).set({
        'closedCampaignIds': FieldValue.arrayUnion([campaignId])
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Kampanya kapatılırken hata: $e');
    }
  }

  /// Global kampanyayı okundu olarak işaretle
  ///
  /// Bu fonksiyon artık kampanyayı kapatmaz, sadece 'readCampaignIds' listesine ekler.
  /// Böylece bildirim listesinde görünmeye devam eder ama "okundu" (soluk) görünür.
  Future<void> markGlobalCampaignAsRead(String campaignId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'readCampaignIds': FieldValue.arrayUnion([campaignId])
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Global kampanya okundu işaretlenirken hata: $e');
    }
  }

  /// Okunmamış (ve kapatılmamış) global kampanyaların sayısını getir (badge için)
  Future<int> getUnreadGlobalCampaignsCount() async {
    final campaigns = await fetchGlobalCampaigns();
    // fetchGlobalCampaigns zaten kapatılanları filtreler.
    // Geriye sadece 'read' property'si false olanları saymak kalır.
    return campaigns.where((c) => !c.read).length;
  }

  /// Global kampanyaları gerçek zamanlı dinle (Stream)
  ///
  /// UI'da gerçek zamanlı güncelleme istiyorsanız bu stream'i kullanın.
  /// Okundu bilgisini de anlık olarak günceller.
  Stream<List<InAppNotification>> watchGlobalCampaigns() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('global_campaigns')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <InAppNotification>[];

      // Kullanıcının kapattığı ve okuduğu kampanyaları çek
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      final List<dynamic> closedCampaigns = userData?['closedCampaignIds'] ?? [];
      final List<dynamic> readCampaigns = userData?['readCampaignIds'] ?? [];

      return snapshot.docs
          .where((doc) => !closedCampaigns.contains(doc.id))
          .map((doc) {
        final data = doc.data();
        // Okundu bilgisini kontrol et
        final isRead = readCampaigns.contains(doc.id);

        return InAppNotification(
          id: doc.id,
          title: data['title'] ?? '',
          body: data['body'] ?? '',
          imageUrl: data['imageUrl']?.toString().isNotEmpty == true ? data['imageUrl'] as String : null,
          route: data['route'] ?? '/home',
          type: 'global_campaign',
          read: isRead, // Dinamik okundu durumu
          createdAt: data['createdAt'] as Timestamp?,
        );
      })
          .toList();
    });
  }
}