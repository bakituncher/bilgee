// functions/src/cache.js
// In-memory cache for Cloud Functions with TTL support

const { logger } = require("firebase-functions");

class CacheEntry {
  constructor(data, ttl) {
    this.data = data;
    this.timestamp = Date.now();
    this.ttl = ttl;
  }

  isExpired() {
    return Date.now() - this.timestamp > this.ttl;
  }
}

class CacheManager {
  constructor() {
    this.cache = new Map();
    this.hits = 0;
    this.misses = 0;
    this.evictions = 0;
  }

  /**
   * Get cached data if available and not expired
   * @param {string} key - Cache key
   * @returns {any|null} Cached data or null
   */
  get(key) {
    const entry = this.cache.get(key);
    if (!entry) {
      this.misses++;
      return null;
    }

    if (entry.isExpired()) {
      this.cache.delete(key);
      this.evictions++;
      this.misses++;
      return null;
    }

    this.hits++;
    return entry.data;
  }

  /**
   * Store data in cache with TTL
   * @param {string} key - Cache key
   * @param {any} data - Data to cache
   * @param {number} ttl - Time to live in milliseconds
   */
  set(key, data, ttl) {
    this.cache.set(key, new CacheEntry(data, ttl));
  }

  /**
   * Check if a key exists and is not expired
   * @param {string} key - Cache key
   * @returns {boolean}
   */
  has(key) {
    const entry = this.cache.get(key);
    if (!entry) return false;
    if (entry.isExpired()) {
      this.cache.delete(key);
      this.evictions++;
      return false;
    }
    return true;
  }

  /**
   * Invalidate specific cache key
   * @param {string} key - Cache key
   */
  invalidate(key) {
    this.cache.delete(key);
  }

  /**
   * Invalidate all keys matching a pattern
   * @param {string} pattern - Pattern to match
   */
  invalidatePattern(pattern) {
    const keysToRemove = [];
    for (const key of this.cache.keys()) {
      if (key.includes(pattern)) {
        keysToRemove.push(key);
      }
    }
    keysToRemove.forEach((key) => this.cache.delete(key));
  }

  /**
   * Clear all cache entries
   */
  clear() {
    this.cache.clear();
    this.hits = 0;
    this.misses = 0;
    this.evictions = 0;
  }

  /**
   * Get cache statistics
   * @returns {Object} Cache stats
   */
  getStats() {
    const total = this.hits + this.misses;
    return {
      hits: this.hits,
      misses: this.misses,
      evictions: this.evictions,
      hitRate: total === 0 ? 0 : this.hits / total,
      size: this.cache.size,
    };
  }

  /**
   * Clean up expired entries
   */
  cleanup() {
    const expiredKeys = [];
    for (const [key, entry] of this.cache.entries()) {
      if (entry.isExpired()) {
        expiredKeys.push(key);
      }
    }
    expiredKeys.forEach((key) => {
      this.cache.delete(key);
      this.evictions++;
    });
    return expiredKeys.length;
  }

  /**
   * Log cache statistics
   */
  logStats() {
    const stats = this.getStats();
    logger.info("Cache statistics:", stats);
  }
}

// Global cache instance for Cloud Functions
// Shared across function invocations in the same instance
const globalCache = new CacheManager();

// Cache TTL constants (in milliseconds)
const CacheTTL = {
  VERY_SHORT: 60 * 1000, // 1 minute
  SHORT: 5 * 60 * 1000, // 5 minutes
  MEDIUM: 10 * 60 * 1000, // 10 minutes
  LONG: 15 * 60 * 1000, // 15 minutes
  VERY_LONG: 30 * 60 * 1000, // 30 minutes
  HOUR: 60 * 60 * 1000, // 1 hour
  DAY: 24 * 60 * 60 * 1000, // 1 day
};

// Cache key generators
const CacheKeys = {
  leaderboardSnapshot: (examType, period) => `leaderboard_snapshot_${examType}_${period}`,
  userProfile: (userId) => `user_profile_${userId}`,
  publicProfile: (userId) => `public_profile_${userId}`,
  userStats: (userId) => `user_stats_${userId}`,
  examConfig: (examType) => `exam_config_${examType}`,
  aiPrompt: (promptKey) => `ai_prompt_${promptKey}`,
  quest: (userId) => `quest_${userId}`,
};

// Periodic cleanup (run every 15 minutes)
setInterval(() => {
  const cleaned = globalCache.cleanup();
  if (cleaned > 0) {
    logger.info(`Cache cleanup: removed ${cleaned} expired entries`);
  }
}, 15 * 60 * 1000);

// Log stats every hour
setInterval(() => {
  globalCache.logStats();
}, 60 * 60 * 1000);

module.exports = {
  CacheManager,
  globalCache,
  CacheTTL,
  CacheKeys,
};
