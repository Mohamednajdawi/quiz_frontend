import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quiz_app/main.dart' as app;
import 'package:firebase_core/firebase_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Quiz Flow Test', () {
    setUpAll(() async {
      await Firebase.initializeApp();
    });

    testWidgets('Complete quiz flow test', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Verify home screen
      expect(find.text('Categories'), findsOneWidget);

      // Start a quiz
      await tester.tap(find.text('Flutter'));
      await tester.pumpAndSettle();

      // Answer questions
      for (var i = 0; i < 10; i++) {
        expect(find.byType(OutlinedButton), findsWidgets);
        await tester.tap(find.byType(OutlinedButton).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      // Verify results screen
      expect(find.text('Quiz Results'), findsOneWidget);
      expect(find.text('Question Review'), findsOneWidget);

      // Return to home
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      // Verify back on home screen
      expect(find.text('Categories'), findsOneWidget);
    });
  });
} 