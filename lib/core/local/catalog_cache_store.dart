import "dart:convert";

import "package:sqflite/sqflite.dart";

import "../../features/library/data/library_repository.dart";

/// Источник данных при офлайн-деградации каталога.
enum CatalogCacheFallback {
  /// Точное совпадение ключа (поиск + тип).
  exact,

  /// Базовый снимок: пустой поиск, без типа.
  baseSnapshot,

  /// В кэше нечего показать.
  none,
}

/// Результат поиска в локальном кэше каталога (блок G недели 8).
class CatalogCacheLookupResult {
  const CatalogCacheLookupResult({
    required this.items,
    required this.fallback,
  });

  final List<MediaListItem>? items;
  final CatalogCacheFallback fallback;
}

class CatalogCacheStore {
  CatalogCacheStore(this._db);

  final Database _db;

  /// Максимум строк `catalog_cache` на одного пользователя (LRU по `updated_at_ms`).
  static const int maxSnapshotsPerUser = 6;

  static String buildCacheKey({
    required String userId,
    required String searchQuery,
    required List<String> selectedTypes,
    required List<String> selectedGenres,
  }) {
    final t =
        [...selectedTypes.map((e) => e.trim()).where((e) => e.isNotEmpty)]
          ..sort();
    final g =
        [...selectedGenres.map((e) => e.trim()).where((e) => e.isNotEmpty)]
          ..sort();
    return "$userId\x1e${searchQuery.trim()}\x1e${t.join(",")}\x1e${g.join("\x1d")}";
  }

  /// Ключ «полный список»: без поиска и без фильтров.
  static String buildBaseCacheKey(String userId) {
    return buildCacheKey(
      userId: userId,
      searchQuery: "",
      selectedTypes: const [],
      selectedGenres: const [],
    );
  }

  Future<void> replaceCatalog({
    required String userId,
    required String cacheKey,
    required List<MediaListItem> items,
  }) async {
    final encoded = jsonEncode(
      items.map((e) => e.toJson()).toList(growable: false),
    );
    await _db.insert("catalog_cache", <String, Object?>{
      "cache_key": cacheKey,
      "user_id": userId,
      "items_json": encoded,
      "updated_at_ms": DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enforceRetention(userId);
  }

  Future<void> _enforceRetention(String userId) async {
    final rows = await _db.query(
      "catalog_cache",
      where: "user_id = ?",
      whereArgs: <Object?>[userId],
    );
    if (rows.length <= maxSnapshotsPerUser) {
      return;
    }
    final baseKey = buildBaseCacheKey(userId);
    var needDelete = rows.length - maxSnapshotsPerUser;
    final sorted = [...rows]..sort((a, b) {
      final ka = a["cache_key"]! as String;
      final kb = b["cache_key"]! as String;
      final aBase = ka == baseKey;
      final bBase = kb == baseKey;
      if (aBase != bBase) {
        return aBase ? 1 : -1;
      }
      return (a["updated_at_ms"]! as int).compareTo(b["updated_at_ms"]! as int);
    });
    for (final row in sorted) {
      if (needDelete <= 0) {
        break;
      }
      await _db.delete(
        "catalog_cache",
        where: "cache_key = ?",
        whereArgs: <Object?>[row["cache_key"]],
      );
      needDelete--;
    }
  }

  Future<List<MediaListItem>?> loadCatalog(String cacheKey) async {
    final rows = await _db.query(
      "catalog_cache",
      columns: ["items_json"],
      where: "cache_key = ?",
      whereArgs: <Object?>[cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final raw = rows.first["items_json"];
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return null;
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MediaListItem.fromJson)
        .toList(growable: false);
  }

  /// Сначала точный ключ, затем базовый снимок (если ключи различаются).
  Future<CatalogCacheLookupResult> loadCatalogWithFallback({
    required String userId,
    required String exactCacheKey,
  }) async {
    final exact = await loadCatalog(exactCacheKey);
    if (exact != null) {
      return CatalogCacheLookupResult(
        items: exact,
        fallback: CatalogCacheFallback.exact,
      );
    }
    final baseKey = buildBaseCacheKey(userId);
    if (baseKey != exactCacheKey) {
      final base = await loadCatalog(baseKey);
      if (base != null) {
        return CatalogCacheLookupResult(
          items: base,
          fallback: CatalogCacheFallback.baseSnapshot,
        );
      }
    }
    return const CatalogCacheLookupResult(
      items: null,
      fallback: CatalogCacheFallback.none,
    );
  }

  Future<void> clearForUser(String userId) async {
    await _db.delete(
      "catalog_cache",
      where: "user_id = ?",
      whereArgs: <Object?>[userId],
    );
  }
}
