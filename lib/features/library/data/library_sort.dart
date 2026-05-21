/// Поле сортировки каталога библиотеки (группы произведений).
enum LibrarySortField { title, rating, views }

extension LibrarySortFieldLabels on LibrarySortField {
  String get label {
    switch (this) {
      case LibrarySortField.title:
        return "По названию";
      case LibrarySortField.rating:
        return "По рейтингу";
      case LibrarySortField.views:
        return "По просмотрам";
    }
  }

  /// Направление по умолчанию при выборе поля.
  bool get defaultDescending {
    switch (this) {
      case LibrarySortField.title:
        return false;
      case LibrarySortField.rating:
      case LibrarySortField.views:
        return true;
    }
  }
}
