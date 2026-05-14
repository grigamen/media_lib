import "../../features/library/data/library_repository.dart";

/// Демо-данные каталога и стримов, если с сервера пришёл пустой список.
abstract final class DemoLibraryData {
  static const Map<String, String> streamByType = {
    "audiobook":
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    "video":
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
  };

  static const List<MediaListItem> items = [
    MediaListItem(
      id: "demo-hp-book",
      title: "Гарри Поттер и философский камень",
      type: "book",
      author: "Джоан Роулинг",
      genres: ["Фэнтези"],
      description: "Первая книга цикла о Гарри Поттере.",
    ),
    MediaListItem(
      id: "demo-hp-audio",
      title: "Гарри Поттер и философский камень",
      type: "audiobook",
      author: "Джоан Роулинг",
      genres: ["Фэнтези"],
      description: "Аудиокнижная версия первой части цикла.",
    ),
    MediaListItem(
      id: "demo-hp-video",
      title: "Гарри Поттер и философский камень",
      type: "video",
      author: "Джоан Роулинг",
      genres: ["Фэнтези"],
      description: "Фильм-экранизация первой книги о Гарри Поттере.",
    ),
    MediaListItem(
      id: "demo-lotr-book",
      title: "Властелин колец: Братство кольца",
      type: "book",
      author: "Дж. Р. Р. Толкин",
      genres: ["Фэнтези"],
      description: "Первая часть эпического фэнтези-цикла.",
    ),
    MediaListItem(
      id: "demo-lotr-audio",
      title: "Властелин колец: Братство кольца",
      type: "audiobook",
      author: "Дж. Р. Р. Толкин",
      genres: ["Фэнтези"],
      description: "Аудиоверсия первой части 'Властелина колец'.",
    ),
    MediaListItem(
      id: "demo-lotr-video",
      title: "Властелин колец: Братство кольца",
      type: "video",
      author: "Дж. Р. Р. Толкин",
      genres: ["Фэнтези"],
      description: "Киноэкранизация первой части трилогии.",
    ),
  ];

  static MediaListItem? findItemById(String mediaItemId) {
    for (final item in items) {
      if (item.id == mediaItemId) {
        return item;
      }
    }
    return null;
  }

  static List<MediaListItem> filteredDemoItems({
    required String searchQuery,
    required List<String> selectedTypes,
    required List<String> selectedGenres,
  }) {
    final query = searchQuery.toLowerCase();
    return items
        .where((item) {
          if (selectedTypes.isNotEmpty && !selectedTypes.contains(item.type)) {
            return false;
          }
          if (selectedGenres.isNotEmpty) {
            final itemLower =
                (item.genres ?? const <String>[])
                    .map((g) => g.trim().toLowerCase())
                    .where((g) => g.isNotEmpty)
                    .toSet();
            final wanted =
                selectedGenres
                    .map((g) => g.trim().toLowerCase())
                    .where((g) => g.isNotEmpty)
                    .toSet();
            final overlap = wanted.any(itemLower.contains);
            if (!overlap) {
              return false;
            }
          }
          if (query.isEmpty) {
            return true;
          }
          return item.title.toLowerCase().contains(query) ||
              (item.author ?? "").toLowerCase().contains(query);
        })
        .toList(growable: false);
  }
}
