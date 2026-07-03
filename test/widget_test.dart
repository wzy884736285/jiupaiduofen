// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mini_game/main.dart';

void main() {
  testWidgets('App opens on the mode chooser', (WidgetTester tester) async {
    await tester.pumpWidget(const NumberBattleApp(onlineEnabled: false));

    expect(find.text('选择模式'), findsOneWidget);
    expect(find.text('本机同屏游戏'), findsOneWidget);
    expect(find.text('线上房间'), findsOneWidget);
  });
}
