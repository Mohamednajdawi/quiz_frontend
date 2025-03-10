import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/quiz_result.dart';

class QuizResultService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Update baseUrl to match the quiz service
  static String get baseUrl {
    return 'https://quiz-maker-api-88ed1bfabc1c.herokuapp.com';
  }

  // Helper method to handle retries for API calls
  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          throw Exception('Failed after $maxRetries attempts: ${e.toString()}');
        }
        await Future.delayed(retryDelay * attempts);
      }
    }
    throw Exception('Failed after $maxRetries attempts');
  }

  // Get the current user's Firebase UID
  String? _getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Register or update user profile with the backend
  Future<void> syncUserProfile() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not found');
    }

    return _withRetry(() async {
      final response = await http.post(
        Uri.parse('$baseUrl/user/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': userId,
          'username': user.displayName,
          'email': user.email,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to sync user profile: ${response.body}');
      }
    });
  }

  // Start a new quiz and get the quiz result ID
  Future<Map<String, dynamic>> startQuiz(int topicId) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _withRetry(() async {
      final response = await http.post(
        Uri.parse('$baseUrl/quiz/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': userId,
          'topic_id': topicId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to start quiz: ${response.body}');
      }

      return jsonDecode(response.body);
    });
  }

  // Submit quiz results
  Future<QuizResult> submitQuizResult({
    required int topicId,
    required double score,
    required int totalQuestions,
    required int correctAnswers,
    int? timeTaken,
    required List<QuestionAnswer> answers,
    String? quizContext,
  }) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _withRetry(() async {
      final response = await http.post(
        Uri.parse('$baseUrl/quiz/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': userId,
          'topic_id': topicId,
          'score': score,
          'total_questions': totalQuestions,
          'correct_answers': correctAnswers,
          'time_taken': timeTaken,
          'completed': true,
          'started_at': DateTime.now().toIso8601String(),
          'answers': answers.map((answer) => answer.toJson()).toList(),
          'quiz_context': quizContext,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to submit quiz result: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      
      // Get the complete quiz result details
      return await getQuizResult(responseData['quiz_result_id']);
    });
  }

  // Get user's quiz history
  Future<List<QuizResult>> getQuizHistory() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _withRetry(() async {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/quiz-history'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get quiz history: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      final List<dynamic> historyList = responseData['quiz_history'];
      
      return historyList
          .map((item) => QuizResult.fromHistoryJson(item))
          .toList();
    });
  }

  // Get raw quiz history data with statistics
  Future<Map<String, dynamic>> getRawQuizHistory() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _withRetry(() async {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/quiz-history'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get quiz history: ${response.body}');
      }

      return jsonDecode(response.body);
    });
  }

  // Get detailed quiz result by ID
  Future<QuizResult> getQuizResult(int resultId) async {
    return _withRetry(() async {
      final response = await http.get(
        Uri.parse('$baseUrl/quiz-result/$resultId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get quiz result: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      return QuizResult.fromJson(responseData['quiz_result']);
    });
  }
} 