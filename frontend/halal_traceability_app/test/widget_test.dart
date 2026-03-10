import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halal_traceability_app/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders core fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    expect(find.text('Partner Sign In'), findsOneWidget);
    expect(find.text('Corporate Email'), findsWidgets);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });
}
