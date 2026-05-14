import "../../features/library/data/library_repository.dart";

List<MediaListItem> dedupeMediaItemsById(List<MediaListItem> items) {
  final seen = <String>{};
  final out = <MediaListItem>[];
  for (final item in items) {
    final id = item.id.trim();
    if (id.isEmpty || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    out.add(item);
  }
  return out;
}

List<String> normalizeLibrarySelectedTypes(Iterable<String> raw) {
  const allowed = {"book", "audiobook", "video"};
  final out = <String>[];
  final seen = <String>{};
  for (final r in raw) {
    final t = r.trim().toLowerCase();
    if (!allowed.contains(t) || seen.contains(t)) {
      continue;
    }
    seen.add(t);
    out.add(t);
  }
  return out;
}

List<String> normalizeLibraryGenres(List<String> genres) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in genres) {
    final genre = raw.trim();
    if (genre.isEmpty) {
      continue;
    }
    final key = genre.toLowerCase();
    if (seen.contains(key)) {
      continue;
    }
    seen.add(key);
    result.add(genre);
  }
  return result;
}
