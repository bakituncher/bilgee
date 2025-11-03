// lib/data/providers/cache_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Cache entry with TTL (Time To Live) support
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry(this.data, this.ttl) : timestamp = DateTime.now();

  /// Check if cache entry has expired
  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
  
  /// Get remaining time before expiration
  Duration get remainingTTL {
    final elapsed = DateTime.now().difference(timestamp);
    final remaining = ttl - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// In-memory cache manager for application data
/// Implements aggressive caching strategy with automatic expiration
class CacheManager {
  final Map<String, CacheEntry> _cache = {};
  
  // Cache statistics for monitoring
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// Get cached data if available and not expired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) {
      _misses++;
      return null;
    }
    
    if (entry.isExpired) {
      _cache.remove(key);
      _evictions++;
      _misses++;
      return null;
    }
    
    _hits++;
    return entry.data as T;
  }

  /// Store data in cache with TTL
  void set<T>(String key, T data, Duration ttl) {
    _cache[key] = CacheEntry(data, ttl);
  }

  /// Check if a key exists and is not expired
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      _evictions++;
      return false;
    }
    return true;
  }

  /// Invalidate specific cache key
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidate all keys matching a pattern
  void invalidatePattern(String pattern) {
    final keysToRemove = _cache.keys.where((key) => key.contains(pattern)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Clear all cache entries
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  /// Get cache statistics
  Map<String, dynamic> get stats => {
    'hits': _hits,
    'misses': _misses,
    'evictions': _evictions,
    'hitRate': _misses == 0 ? 1.0 : _hits / (_hits + _misses),
    'size': _cache.length,
  };

  /// Clean up expired entries
  void cleanup() {
    final now = DateTime.now();
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _cache.remove(key);
      _evictions++;
    }
  }
}

/// Persistent cache using SharedPreferences for data that survives app restarts
class PersistentCacheManager {
  SharedPreferences? _prefs;
  
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Store data persistently with expiration timestamp
  Future<void> set(String key, String data, Duration ttl) async {
    await _ensureInitialized();
    final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
    final cacheData = jsonEncode({
      'data': data,
      'expiresAt': expiresAt,
    });
    await _prefs!.setString(key, cacheData);
  }

  /// Get data from persistent cache if not expired
  Future<String?> get(String key) async {
    await _ensureInitialized();
    final cacheData = _prefs!.getString(key);
    if (cacheData == null) return null;
    
    try {
      final decoded = jsonDecode(cacheData) as Map<String, dynamic>;
      final expiresAt = decoded['expiresAt'] as int;
      
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        // Expired, remove it
        await _prefs!.remove(key);
        return null;
      }
      
      return decoded['data'] as String;
    } catch (e) {
      // Invalid cache data, remove it
      await _prefs!.remove(key);
      return null;
    }
  }

  /// Check if key exists and is not expired
  Future<bool> has(String key) async {
    final data = await get(key);
    return data != null;
  }

  /// Remove specific key
  Future<void> remove(String key) async {
    await _ensureInitialized();
    await _prefs!.remove(key);
  }

  /// Clear all persistent cache
  Future<void> clear() async {
    await _ensureInitialized();
    final keys = _prefs!.getKeys().where((key) => key.startsWith('cache_')).toList();
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
}

/// Provider for in-memory cache manager
final cacheManagerProvider = Provider<CacheManager>((ref) {
  final manager = CacheManager();
  
  // Cleanup expired entries every 5 minutes
  ref.onDispose(() {
    manager.clear();
  });
  
  return manager;
});

/// Provider for persistent cache manager
final persistentCacheManagerProvider = Provider<PersistentCacheManager>((ref) {
  return PersistentCacheManager();
});

/// Cache key utilities
class CacheKeys {
  // Leaderboard cache keys (5 min TTL)
  static String leaderboard(String examType, String period) => 'leaderboard_${examType}_$period';
  
  // User profile cache keys (5 min TTL)
  static String userProfile(String userId) => 'user_profile_$userId';
  
  // Public profile cache keys (10 min TTL)
  static String publicProfile(String userId) => 'public_profile_$userId';
  
  // Exam config cache keys (30 min TTL)
  static String examConfig(String examType) => 'exam_config_$examType';
  
  // Blog posts cache keys (15 min TTL)
  static String blogPosts(String? locale) => 'blog_posts_${locale ?? 'all'}';
  static String blogPost(String slug) => 'blog_post_$slug';
  
  // User stats cache keys (5 min TTL)
  static String userStats(String userId) => 'user_stats_$userId';
  
  // Quest cache keys (10 min TTL)
  static String dailyQuests(String userId) => 'daily_quests_$userId';
  
  // Performance cache keys (10 min TTL)
  static String performanceSummary(String userId) => 'performance_summary_$userId';
}

/// Cache TTL constants
class CacheTTL {
  static const veryShort = Duration(minutes: 1);
  static const short = Duration(minutes: 5);
  static const medium = Duration(minutes: 10);
  static const long = Duration(minutes: 15);
  static const veryLong = Duration(minutes: 30);
  static const hour = Duration(hours: 1);
  static const day = Duration(days: 1);
}
