import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pnumadesk_manager/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PnumaDeskApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
