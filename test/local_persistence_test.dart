import "package:flutter_test/flutter_test.dart";
import "package:media_lib/core/local/catalog_cache_store.dart";
import "package:media_lib/core/local/media_lib_database.dart";
import "package:media_lib/core/local/progress_local_store.dart";
import "package:media_lib/core/local/recently_viewed_local_store.dart";
import "package:media_lib/features/library/data/library_repository.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await MediaLibDatabase.disposeForTests();
  });

  test("CatalogCacheStore roundtrip", () async {
    final db = await MediaLibDatabase.open();
    final store = CatalogCacheStore(db);
    const userId = "user-1";
    final key = CatalogCacheStore.buildCacheKey(
      userId: userId,
      searchQuery: "",
      typeFilter: null,
    );
    final items = <MediaListItem>[
      const MediaListItem(
        id: "m1",
        userId: userId,
        title: "T",
        type: "book",
        author: "A",
      ),
    ];
    await store.replaceCatalog(userId: userId, cacheKey: key, items: items);
    final loaded = await store.loadCatalog(key);
    expect(loaded, isNotNull);
    expect(loaded!.length, 1);
    expect(loaded.single.id, "m1");
    expect(loaded.single.title, "T");
  });

  test("CatalogCacheStore retention LRU", () async {
    final db = await MediaLibDatabase.open();
    final store = CatalogCacheStore(db);
    const userId = "user-lru";
    final item = const MediaListItem(
      id: "m",
      userId: userId,
      title: "T",
      type: "book",
      author: "A",
    );
    for (var i = 0; i < 7; i++) {
      await store.replaceCatalog(
        userId: userId,
        cacheKey: CatalogCacheStore.buildCacheKey(
          userId: userId,
          searchQuery: "$i",
          typeFilter: null,
        ),
        items: [item],
      );
    }
    final rows = await db.query(
      "catalog_cache",
      where: "user_id = ?",
      whereArgs: <Object?>[userId],
    );
    expect(rows.length, CatalogCacheStore.maxSnapshotsPerUser);
  });

  test("CatalogCacheStore fallback to base snapshot", () async {
    final db = await MediaLibDatabase.open();
    final store = CatalogCacheStore(db);
    const userId = "user-fb";
    const baseItem = MediaListItem(
      id: "b1",
      userId: userId,
      title: "Base",
      type: "book",
      author: "",
    );
    const filteredItem = MediaListItem(
      id: "f1",
      userId: userId,
      title: "F",
      type: "video",
      author: "",
    );
    await store.replaceCatalog(
      userId: userId,
      cacheKey: CatalogCacheStore.buildBaseCacheKey(userId),
      items: const [baseItem],
    );
    await store.replaceCatalog(
      userId: userId,
      cacheKey: CatalogCacheStore.buildCacheKey(
        userId: userId,
        searchQuery: "qq",
        typeFilter: null,
      ),
      items: const [filteredItem],
    );
    final missing = CatalogCacheStore.buildCacheKey(
      userId: userId,
      searchQuery: "nope",
      typeFilter: null,
    );
    final r = await store.loadCatalogWithFallback(
      userId: userId,
      exactCacheKey: missing,
    );
    expect(r.fallback, CatalogCacheFallback.baseSnapshot);
    expect(r.items?.single.id, "b1");
  });

  test("ProgressLocalStore pending flag", () async {
    final db = await MediaLibDatabase.open();
    final store = ProgressLocalStore(db);
    const userId = "u2";
    await store.upsertMirror(
      userId: userId,
      mediaItemId: "mid",
      positionSeconds: 42,
      durationSeconds: 100,
      isCompleted: false,
      pendingSync: true,
    );
    final pending = await store.listPending(userId);
    expect(pending.length, 1);
    expect(pending.single.positionSeconds, 42);
    await store.upsertMirror(
      userId: userId,
      mediaItemId: "mid",
      positionSeconds: 42,
      durationSeconds: 100,
      isCompleted: false,
      pendingSync: false,
    );
    expect(await store.listPending(userId), isEmpty);
  });

  test("ProgressLocalStore loadMirror", () async {
    final db = await MediaLibDatabase.open();
    final store = ProgressLocalStore(db);
    const userId = "u-mirror";
    expect(await store.loadMirror(userId: userId, mediaItemId: "x"), isNull);
    await store.upsertMirror(
      userId: userId,
      mediaItemId: "x",
      positionSeconds: 7,
      durationSeconds: 70,
      isCompleted: true,
      pendingSync: false,
    );
    final m = await store.loadMirror(userId: userId, mediaItemId: "x");
    expect(m, isNotNull);
    expect(m!.positionSeconds, 7);
    expect(m.isCompleted, true);
    expect(m.pendingSync, false);
  });

  test("RecentlyViewedLocalStore roundtrip", () async {
    final db = await MediaLibDatabase.open();
    final store = RecentlyViewedLocalStore(db);
    const userId = "u-recent";
    expect(await store.loadItemIds(userId), isNull);
    await store.saveItemIds(userId, ["a", "b", "c"]);
    expect(await store.loadItemIds(userId), ["a", "b", "c"]);
    await store.clearForUser(userId);
    expect(await store.loadItemIds(userId), isNull);
  });
}
