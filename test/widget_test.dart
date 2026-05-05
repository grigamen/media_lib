import "package:flutter_test/flutter_test.dart";
import "package:media_lib/app/app.dart";

void main() {
  testWidgets("Shows auth route on startup", (WidgetTester tester) async {
    await tester.pumpWidget(const MediaLibApp());

    expect(find.text("MediaLib Auth"), findsOneWidget);
    expect(find.text("Вход"), findsOneWidget);
  });
}
