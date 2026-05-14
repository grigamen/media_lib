part of "book_reader_screen.dart";

/// Одна страница [PageView]: фрагмент полного текста и стиль; состояние держит жизнь виджета при листании.
class _BookReaderPage extends StatefulWidget {
  const _BookReaderPage({
    super.key,
    required this.slice,
    required this.textStyle,
  });

  final String slice;
  final TextStyle textStyle;

  @override
  State<_BookReaderPage> createState() => _BookReaderPageState();
}

/// [AutomaticKeepAliveClientMixin] сохраняет отрисованный текст при соседних страницах.
class _BookReaderPageState extends State<_BookReaderPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Align(
          alignment: Alignment.topLeft,
          child: SelectionArea(
            child: Text(
              widget.slice,
              style: widget.textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
