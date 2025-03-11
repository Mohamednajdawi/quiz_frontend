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
      print('Error: User not authenticated when fetching quiz history');
      throw Exception('User not authenticated');
    }

    return _withRetry(() async {
      print('Fetching quiz history for user: $userId');
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/user/$userId/quiz-history'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Quiz history request timed out');
            throw Exception('Request timed out');
          },
        );

        print('Quiz history response status: ${response.statusCode}');
        
        if (response.statusCode != 200) {
          print('Error response body: ${response.body}');
          throw Exception('Failed to get quiz history: ${response.body}');
        }

        final responseData = jsonDecode(response.body);
        print('Successfully decoded quiz history response');
        
        if (!responseData.containsKey('quiz_history')) {
          print('Error: quiz_history key not found in response: $responseData');
          return [];
        }
        
        final List<dynamic> historyList = responseData['quiz_history'];
        print('Found ${historyList.length} quiz history items');
        
        return historyList
            .map((item) => QuizResult.fromHistoryJson(item))
            .toList();
      } catch (e) {
        print('Exception in getQuizHistory: $e');
        rethrow;
      }
    });
  }

  // Get raw quiz history data with statistics
  Future<Map<String, dynamic>> getRawQuizHistory() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      print('Error: User not authenticated when fetching raw quiz history');
      throw Exception('User not authenticated');
    }

    return _withRetry(() async {
      print('Fetching raw quiz history for user: $userId');
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/user/$userId/quiz-history'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Raw quiz history request timed out');
            throw Exception('Request timed out');
          },
        );

        print('Raw quiz history response status: ${response.statusCode}');
        
        if (response.statusCode != 200) {
          print('Error response body: ${response.body}');
          throw Exception('Failed to get quiz history: ${response.body}');
        }

        final responseData = jsonDecode(response.body);
        print('Successfully decoded raw quiz history response');
        return responseData;
      } catch (e) {
        print('Exception in getRawQuizHistory: $e');
        rethrow;
      }
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