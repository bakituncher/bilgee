// lib/features/blog/providers/blog_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/blog/models/blog_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Yayımlanmış blog yazıları (TR) listesi
final blogPostsStreamProvider = StreamProvider.autoDispose<List<BlogPost>>((ref) {
  final fs = ref.watch(firestoreProvider);
  final q = fs
      .collection('posts')
      .where('status', isEqualTo: 'published')
      .where('publishedAt', isLessThanOrEqualTo: Timestamp.now())
      .where('locale', isEqualTo: 'tr')
      .orderBy('publishedAt', descending: true)
      .limit(50);
  return q.snapshots().map((s) {
    final now = DateTime.now();
    return s.docs
        .map((d) => BlogPost.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
        .where((p) => p.expireAt == null || p.expireAt!.isAfter(now))
        .toList();
  });
});

// Slug ile tek yazı
final blogPostBySlugProvider = FutureProvider.family.autoDispose<BlogPost?, String>((ref, slug) async {
  final fs = ref.watch(firestoreProvider);
  final qs = await fs.collection('posts').where('slug', isEqualTo: slug).limit(1).get();
  if (qs.docs.isEmpty) return null;
  final post = BlogPost.fromDoc(qs.docs.first as DocumentSnapshot<Map<String, dynamic>>);
  final now = DateTime.now();
  if (post.expireAt != null && !post.expireAt!.isAfter(now)) return null;
  return post;
});
