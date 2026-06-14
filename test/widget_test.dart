import 'package:cairn/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CairnApp shows the dashboard', (tester) async {
    await tester.pumpWidget(const CairnApp());

    expect(find.text('Cairn'), findsWidgets);
  });
}
