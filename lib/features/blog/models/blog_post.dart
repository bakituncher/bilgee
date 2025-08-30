// lib/features/blog/models/blog_post.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BlogPost {
  final String id;
  final String title;
  final String slug;
  final String? excerpt;
  final String contentMarkdown;
  final String? coverImageUrl;
  final List<String> tags;
  final String locale;
  final String status; // draft | published
  final DateTime? publishedAt;
  final DateTime updatedAt;
  final String? author;
  final int? readTime;
  final List<String> targetExams; // Yeni: Hedef kitle (yks, lgs, kpss veya all)

  BlogPost({
    required this.id,
    required this.title,
    required this.slug,
    required this.contentMarkdown,
    required this.locale,
    required this.status,
    required this.updatedAt,
    this.excerpt,
    this.coverImageUrl,
    this.tags = const [],
    this.publishedAt,
    this.author,
    this.readTime,
    this.targetExams = const ['all'],
  });

  factory BlogPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BlogPost(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      slug: (d['slug'] ?? doc.id) as String,
      excerpt: d['excerpt'] as String?,
      contentMarkdown: (d['contentMarkdown'] ?? '') as String,
      coverImageUrl: d['coverImageUrl'] as String?,
      tags: (d['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      locale: (d['locale'] ?? 'tr') as String,
      status: (d['status'] ?? 'draft') as String,
      publishedAt: (d['publishedAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      author: d['author'] as String?,
      readTime: (d['readTime'] as num?)?.toInt(),
      targetExams: (d['targetExams'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['all'],
    );
  }
}
