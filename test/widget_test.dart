
import 'package:flutter_test/flutter_test.dart';
import 'package:novispot/main.dart';

void main() {
  testWidgets('Novispot app starts', (WidgetTester tester) async {
    await tester.pumpWidget(NovispotApp());

    expect(find.text('Novispot'), findsWidgets);
  });
}
