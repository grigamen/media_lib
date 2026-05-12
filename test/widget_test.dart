import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:media_lib/app/app.dart";

void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets("Shows auth route on startup", (WidgetTester tester) async {
    await tester.pumpWidget(const MediaLibApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text("MediaLib"), findsWidgets);
    expect(find.text("Вход"), findsOneWidget);
  });
}
