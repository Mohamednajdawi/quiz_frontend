import 'dart:convert';
import 'dart:async'; // Add this for timeout support
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/quiz_result.dart';
import 'package:intl/intl.dart';

class QuizResultService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get base URL for API calls
  String get baseUrl {
    // Use Heroku URL in production
    return 'https://quiz-maker-api-88ed1bfabc1c.herokuapp.com';
  }
  
  // Add a timeout duration
  final Duration _timeout = const Duration(seconds: 10);

  // Helper method to handle retries for API calls
  Future<T> _withRetry<T>(Future<T> Function() operation, {int maxRetries = 2}) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts > maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempts));
      }
    }
  }
  
  // Update or create user profile in backend
  Future<void> syncUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.uid,
          'display_name': user.displayName ?? '',
          'email': user.email ?? '',
          'photo_url': user.photoURL ?? '',
        }),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Connection timeout while syncing user profile');
      });
      
      print('User profile synced with backend: ${user.uid}');
    } catch (e) {
      print('Error syncing user profile: $e');
      throw Exception('Failed to sync user profile: $e');
    }
  }

  // Get quiz history for logged in user
  Future<List<QuizResult>> getQuizHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/quiz-history'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout, onTimeout: () {
        print('Quiz history request timed out');
        throw TimeoutException('Connection timeout while fetching quiz history');
      });

      print('Quiz history response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Error response body: ${response.body}');
        throw Exception('Failed to get quiz history. Server returned ${response.statusCode}');
      }

      print('Quiz history response received');
      final List<dynamic> jsonData = jsonDecode(response.body);
      print('Quiz history JSON parsed: ${jsonData.length} items');
      
      // Map to QuizResult objects
      return jsonData
          .map((item) => QuizResult.fromJson(item))
          .toList();
    } on TimeoutException catch (e) {
      print('Timeout Error: ${e.message}');
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    } catch (e) {
      print('Exception in getQuizHistory: $e');
      throw Exception('Failed to get quiz history: $e');
    }
  }
  
  // Get raw quiz history data including statistics
  Future<Map<String, dynamic>> getRawQuizHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/quiz-history'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout, onTimeout: () {
        print('Raw quiz history request timed out');
        throw TimeoutException('Connection timeout while fetching raw quiz history');
      });

      print('Raw quiz history response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Error response body: ${response.body}');
        throw Exception('Failed to get quiz history. Server returned ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);
      print('Successfully decoded raw quiz history response');
      return responseData;
    } on TimeoutException catch (e) {
      print('Timeout Error: ${e.message}');
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    } catch (e) {
      print('Exception in getRawQuizHistory: $e');
      throw Exception('Failed to get raw quiz history: $e');
    }
  }
  
  // Get a specific quiz result by ID
  Future<QuizResult> getQuizResult(String resultId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/quiz-result/$resultId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Connection timeout while getting quiz result');
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to get quiz result. Server returned ${response.statusCode}');
      }

      return QuizResult.fromJson(jsonDecode(response.body));
    } catch (e) {
      print('Exception in getQuizResult: $e');
      throw Exception('Failed to get quiz result: $e');
    }
  }
  
  // Submit quiz results to backend
  Future<bool> submitQuizResult(QuizResult result) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      await syncUserProfile();
      
      final response = await http.post(
        Uri.parse('$baseUrl/quiz-results'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          ...result.toJson(),
          'user_id': user.uid,
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error submitting quiz result: $e');
      return false;
    }
  }

  // Format date for display
  String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }
} 