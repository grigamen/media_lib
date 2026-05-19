/// Наличие средней оценки у произведения.
enum LibraryRatingPresence {
  any,
  withRating,
  withoutRating,
}

/// Наличие просмотров (сумма по форматам).
enum LibraryViewsPresence {
  any,
  withViews,
  withoutViews,
}

/// Сравнение с порогом: больше / меньше.
enum LibraryBoundCompare {
  greater,
  less,
}

/// Фильтр по рейтингу: наличие и/или граница по средней оценке (1–5).
class LibraryRatingCriteria {
  const LibraryRatingCriteria({
    this.presence = LibraryRatingPresence.any,
    this.boundCompare,
    this.boundValue,
  });

  final LibraryRatingPresence presence;
  final LibraryBoundCompare? boundCompare;
  final double? boundValue;

  static const any = LibraryRatingCriteria();

  bool get isActive =>
      presence != LibraryRatingPresence.any ||
      (boundCompare != null && boundValue != null);

  String? get presenceChipLabel {
    return switch (presence) {
      LibraryRatingPresence.withRating => "С рейтингом",
      LibraryRatingPresence.withoutRating => "Без рейтинга",
      LibraryRatingPresence.any => null,
    };
  }

  String? get boundChipLabel =>
      _boundLabel(boundCompare, boundValue, isRating: true);

  String get chipLabel {
    final parts = <String>[
      if (presenceChipLabel != null) presenceChipLabel!,
      if (boundChipLabel != null) boundChipLabel!,
    ];
    return parts.join(", ");
  }

  LibraryRatingCriteria copyWith({
    LibraryRatingPresence? presence,
    LibraryBoundCompare? boundCompare,
    double? boundValue,
    bool clearBound = false,
  }) {
    return LibraryRatingCriteria(
      presence: presence ?? this.presence,
      boundCompare: clearBound ? null : (boundCompare ?? this.boundCompare),
      boundValue: clearBound ? null : (boundValue ?? this.boundValue),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryRatingCriteria &&
        other.presence == presence &&
        other.boundCompare == boundCompare &&
        other.boundValue == boundValue;
  }

  @override
  int get hashCode => Object.hash(presence, boundCompare, boundValue);
}

/// Фильтр по просмотрам: наличие и/или граница по сумме просмотров.
class LibraryViewsCriteria {
  const LibraryViewsCriteria({
    this.presence = LibraryViewsPresence.any,
    this.boundCompare,
    this.boundValue,
  });

  final LibraryViewsPresence presence;
  final LibraryBoundCompare? boundCompare;
  final int? boundValue;

  static const any = LibraryViewsCriteria();

  bool get isActive =>
      presence != LibraryViewsPresence.any ||
      (boundCompare != null && boundValue != null);

  String? get presenceChipLabel {
    return switch (presence) {
      LibraryViewsPresence.withViews => "С просмотрами",
      LibraryViewsPresence.withoutViews => "Без просмотров",
      LibraryViewsPresence.any => null,
    };
  }

  String? get boundChipLabel =>
      _boundLabel(boundCompare, boundValue?.toDouble(), isRating: false);

  String get chipLabel {
    final parts = <String>[
      if (presenceChipLabel != null) presenceChipLabel!,
      if (boundChipLabel != null) boundChipLabel!,
    ];
    return parts.join(", ");
  }

  LibraryViewsCriteria copyWith({
    LibraryViewsPresence? presence,
    LibraryBoundCompare? boundCompare,
    int? boundValue,
    bool clearBound = false,
  }) {
    return LibraryViewsCriteria(
      presence: presence ?? this.presence,
      boundCompare: clearBound ? null : (boundCompare ?? this.boundCompare),
      boundValue: clearBound ? null : (boundValue ?? this.boundValue),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryViewsCriteria &&
        other.presence == presence &&
        other.boundCompare == boundCompare &&
        other.boundValue == boundValue;
  }

  @override
  int get hashCode => Object.hash(presence, boundCompare, boundValue);
}

String? _boundLabel(
  LibraryBoundCompare? compare,
  double? value, {
  required bool isRating,
}) {
  if (compare == null || value == null) {
    return null;
  }
  final formatted =
      isRating
          ? value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)
          : value.round().toString();
  if (isRating) {
    return switch (compare) {
      LibraryBoundCompare.greater => "Рейтинг > $formatted",
      LibraryBoundCompare.less => "Рейтинг < $formatted",
    };
  }
  return switch (compare) {
    LibraryBoundCompare.greater => "Просмотров > $formatted",
    LibraryBoundCompare.less => "Просмотров < $formatted",
  };
}

String labelForBoundCompare(LibraryBoundCompare compare) {
  return switch (compare) {
    LibraryBoundCompare.greater => "Больше",
    LibraryBoundCompare.less => "Меньше",
  };
}

/// Разбор порога рейтинга из поля ввода (1–5).
double? parseRatingBoundInput(String raw) {
  final normalized = raw.trim().replaceAll(",", ".");
  if (normalized.isEmpty) {
    return null;
  }
  final value = double.tryParse(normalized);
  if (value == null || value < 0 || value > 5) {
    return null;
  }
  return value;
}

/// Разбор порога просмотров из поля ввода (≥ 0).
int? parseViewsBoundInput(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final value = int.tryParse(normalized);
  if (value == null || value < 0) {
    return null;
  }
  return value;
}
