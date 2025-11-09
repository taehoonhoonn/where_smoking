// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:api_test_app/mobile_app.dart';

void main() {
  testWidgets('앱 제목이 표시되는지 확인', (WidgetTester tester) async {
    await tester.pumpWidget(const MobileWebViewApp());

    expect(find.text('흡연구역 찾기'), findsOneWidget);
  });
}
