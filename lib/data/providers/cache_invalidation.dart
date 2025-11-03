// lib/data/providers/cache_invalidation.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cache_provider.dart';

/// Cache invalidation utilities
/// Use these methods when data is updated to ensure cache consistency
class CacheInvalidation {
  /// Invalidate user-related caches when user data changes
  static void invalidateUserCaches(WidgetRef ref, String userId) {
    final cache = ref.read(cacheManagerProvider);
    
    // Invalidate all user-related caches
    cache.invalidate(CacheKeys.userProfile(userId));
    cache.invalidate(CacheKeys.publicProfile(userId));
    cache.invalidate(CacheKeys.userStats(userId));
    cache.invalidate(CacheKeys.performanceSummary(userId));
    cache.invalidate(CacheKeys.dailyQuests(userId));
  }

  /// Invalidate leaderboard caches when scores change
  static void invalidateLeaderboardCaches(WidgetRef ref, String examType) {
    final cache = ref.read(cacheManagerProvider);
    
    // Invalidate daily and weekly leaderboards for this exam type
    cache.invalidate(CacheKeys.leaderboard(examType, 'daily'));
    cache.invalidate(CacheKeys.leaderboard(examType, 'weekly'));
  }

  /// Invalidate all leaderboards (use sparingly)
  static void invalidateAllLeaderboards(WidgetRef ref) {
    final cache = ref.read(cacheManagerProvider);
    cache.invalidatePattern('leaderboard_');
  }

  /// Invalidate blog post caches
  static void invalidateBlogCaches(WidgetRef ref, {String? slug}) {
    final cache = ref.read(cacheManagerProvider);
    
    if (slug != null) {
      cache.invalidate(CacheKeys.blogPost(slug));
    } else {
      // Invalidate all blog caches
      cache.invalidatePattern('blog_');
    }
  }

  /// Invalidate exam configuration caches
  static void invalidateExamConfigCache(WidgetRef ref, String examType) {
    final cache = ref.read(cacheManagerProvider);
    cache.invalidate(CacheKeys.examConfig(examType));
  }

  /// Clear all caches (use for logout or major data changes)
  static void clearAllCaches(WidgetRef ref) {
    final cache = ref.read(cacheManagerProvider);
    cache.clear();
  }
}

/// Cache warming utilities
/// Pre-load frequently accessed data into cache
class CacheWarming {
  /// Warm up user-related caches on app start
  static Future<void> warmupUserCaches(WidgetRef ref, String userId) async {
    // These providers will fetch and cache the data
    try {
      // Trigger loading of user stats (will be cached)
      ref.read(userStatsStreamProvider);
      
      // Performance summary will be cached when accessed
      ref.read(performanceProvider);
    } catch (e) {
      // Silently fail - cache warming is not critical
    }
  }

  /// Warm up leaderboard caches for the user's exam type
  static Future<void> warmupLeaderboardCaches(WidgetRef ref, String examType) async {
    try {
      // Trigger loading of leaderboards (will be cached)
      ref.read(leaderboardDailyProvider(examType));
      ref.read(leaderboardWeeklyProvider(examType));
    } catch (e) {
      // Silently fail - cache warming is not critical
    }
  }
}

/// Cache monitoring utilities
class CacheMonitoring {
  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats(WidgetRef ref) {
    final cache = ref.read(cacheManagerProvider);
    return cache.stats;
  }

  /// Log cache statistics to console
  static void logCacheStats(WidgetRef ref) {
    final stats = getCacheStats(ref);
    print('=== Cache Statistics ===');
    print('Hits: ${stats['hits']}');
    print('Misses: ${stats['misses']}');
    print('Evictions: ${stats['evictions']}');
    print('Hit Rate: ${(stats['hitRate'] * 100).toStringAsFixed(2)}%');
    print('Cache Size: ${stats['size']} entries');
    print('=======================');
  }

  /// Cleanup expired cache entries
  static void cleanupCache(WidgetRef ref) {
    final cache = ref.read(cacheManagerProvider);
    cache.cleanup();
  }
}
