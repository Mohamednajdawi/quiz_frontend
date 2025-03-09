import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app/screens/auth/auth_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';

// Mock Firebase Auth
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('AuthScreen Widget Tests', () {
    testWidgets('should display login form initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Don\'t have an account? Register'), findsOneWidget);
    });

    testWidgets('should switch to register form when register link is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

      await tester.tap(find.text('Don\'t have an account? Register'));
      await tester.pumpAndSettle();

      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Already have an account? Login'), findsOneWidget);
    });

    testWidgets('should show error when submitting empty form',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('should show error for invalid email',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'invalid-email');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('should show error for short password',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '12345');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(
          find.text('Password must be at least 6 characters'), findsOneWidget);
    });
  });
}

// Mock setup for Firebase
void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
} 