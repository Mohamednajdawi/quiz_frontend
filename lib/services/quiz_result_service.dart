import 'dart:convert';
import 'dart:async'; // Add this for timeout support
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/quiz_result.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

class QuizResultService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get base URL for API calls
  String get baseUrl {
    // Use Heroku URL in production
    return 'https://quiz-maker-api-88ed1bfabc1c.herokuapp.com';
  }
  
  // Alternative endpoint formats to test
  List<String> get alternativeEndpoints {
    return [
      '$baseUrl/users/$_getCurrentUserId()/quiz-history',
      '$baseUrl/quiz-history',
      '$baseUrl/user/$_getCurrentUserId()/quizzes',
      '$baseUrl/quiz-history/user/$_getCurrentUserId()',
    ];
  }
  
  // Add a timeout duration
  final Duration _timeout = const Duration(seconds: 15); // Increased timeout

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
  
  // Get current user ID (helper method)
  String? _getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
  
  // Test basic API connection
  Future<bool> testApiConnection() async {
    try {
      developer.log('Testing connection to $baseUrl', name: 'QuizResultService');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(_timeout);
      
      developer.log('API base connection response: ${response.statusCode}', name: 'QuizResultService');
      developer.log('Response body: ${response.body.substring(0, min(100, response.body.length))}...', name: 'QuizResultService');
      
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      developer.log('API connection test failed: $e', name: 'QuizResultService', error: e);
      return false;
    }
  }
  
  // Test all possible endpoints
  Future<void> testAllEndpoints(String userId) async {
    developer.log('Testing all possible endpoints for user $userId', name: 'QuizResultService');
    
    // Test regular endpoint first
    await _testEndpoint('$baseUrl/user/$userId/quiz-history', 'Standard endpoint');
    
    // Test variations
    for (final endpoint in alternativeEndpoints) {
      await _testEndpoint(endpoint.replaceAll('()', ''), 'Alternative endpoint');
    }
    
    developer.log('Endpoint testing complete', name: 'QuizResultService');
  }
  
  Future<void> _testEndpoint(String url, String description) async {
    try {
      developer.log('Testing $description: $url', name: 'QuizResultService');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      developer.log('$description response: ${response.statusCode}', name: 'QuizResultService');
      if (response.statusCode == 200) {
        final responseData = response.body.substring(0, min(200, response.body.length));
        developer.log('Response preview: $responseData', name: 'QuizResultService');
      } else {
        developer.log('Error response: ${response.body}', name: 'QuizResultService');
      }
    } catch (e) {
      developer.log('$description test failed: $e', name: 'QuizResultService', error: e);
    }
  }
  
  // Update or create user profile in backend
  Future<void> syncUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      developer.log('Syncing user profile for ${user.uid}', name: 'QuizResultService');
      
      final response = await http.post(
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
      
      developer.log('User profile sync response: ${response.statusCode}', name: 'QuizResultService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        developer.log('User profile synced successfully', name: 'QuizResultService');
      } else {
        developer.log('User profile sync failed with status ${response.statusCode}', name: 'QuizResultService');
        developer.log('Response: ${response.body}', name: 'QuizResultService');
      }
    } catch (e) {
      developer.log('Error syncing user profile: $e', name: 'QuizResultService', error: e);
      throw Exception('Failed to sync user profile: $e');
    }
  }

  // Get quiz history for logged in user
  Future<List<QuizResult>> getQuizHistory(String userId) async {
    try {
      developer.log('Fetching quiz history for user: $userId', name: 'QuizResultService');
      
      // Try to sync user profile first
      try {
        await syncUserProfile();
      } catch (e) {
        developer.log('Warning: Failed to sync user profile: $e', name: 'QuizResultService');
        // Continue anyway
      }
      
      final url = '$baseUrl/user/$userId/quiz-history';
      developer.log('Making request to: $url', name: 'QuizResultService');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout, onTimeout: () {
        developer.log('Quiz history request timed out after ${_timeout.inSeconds} seconds', name: 'QuizResultService');
        throw TimeoutException('Connection timeout while fetching quiz history');
      });

      developer.log('Quiz history response status: ${response.statusCode}', name: 'QuizResultService');
      
      if (response.statusCode != 200) {
        developer.log('Error response body: ${response.body}', name: 'QuizResultService');
        throw Exception('Failed to get quiz history. Server returned ${response.statusCode}');
      }

      developer.log('Quiz history response received, length: ${response.body.length}', name: 'QuizResultService');
      
      // Log raw response for debugging
      if (response.body.length < 1000) {
        developer.log('Raw response: ${response.body}', name: 'QuizResultService');
      } else {
        developer.log('Raw response (truncated): ${response.body.substring(0, 1000)}...', name: 'QuizResultService');
      }
      
      // Try to parse response
      try {
        final dynamic jsonData = jsonDecode(response.body);
        
        // Check if response is an object with a specific key for quiz history
        if (jsonData is Map<String, dynamic>) {
          developer.log('Detected object response with keys: ${jsonData.keys.join(', ')}', name: 'QuizResultService');
          
          // Check for various possible structure patterns
          if (jsonData.containsKey('quiz_history')) {
            final historyList = jsonData['quiz_history'] as List<dynamic>;
            developer.log('Found quiz_history key with ${historyList.length} items', name: 'QuizResultService');
            return historyList.map((item) => QuizResult.fromJson(item)).toList();
          } else if (jsonData.containsKey('history')) {
            final historyList = jsonData['history'] as List<dynamic>;
            developer.log('Found history key with ${historyList.length} items', name: 'QuizResultService');
            return historyList.map((item) => QuizResult.fromJson(item)).toList();
          } else if (jsonData.containsKey('quizzes')) {
            final historyList = jsonData['quizzes'] as List<dynamic>;
            developer.log('Found quizzes key with ${historyList.length} items', name: 'QuizResultService');
            return historyList.map((item) => QuizResult.fromJson(item)).toList();
          } else if (jsonData.containsKey('results')) {
            final historyList = jsonData['results'] as List<dynamic>;
            developer.log('Found results key with ${historyList.length} items', name: 'QuizResultService');
            return historyList.map((item) => QuizResult.fromJson(item)).toList();
          }
          
          // If no specific key, see if the entire object is a quiz result (single result)
          try {
            developer.log('Attempting to parse entire object as a single quiz result', name: 'QuizResultService');
            final singleResult = QuizResult.fromJson(jsonData);
            return [singleResult];
          } catch (e) {
            developer.log('Failed to parse as single result: $e', name: 'QuizResultService');
          }
        }
        
        // If it's a direct list
        if (jsonData is List<dynamic>) {
          developer.log('Detected list response with ${jsonData.length} items', name: 'QuizResultService');
          return jsonData.map((item) => QuizResult.fromJson(item)).toList();
        }
        
        // If we get here, something unexpected happened
        developer.log('Unexpected response format: ${jsonData.runtimeType}', name: 'QuizResultService');
        throw FormatException('Unexpected response format: ${jsonData.runtimeType}');
      } catch (e) {
        developer.log('JSON parsing error: $e', name: 'QuizResultService', error: e);
        throw FormatException('Failed to parse quiz history response: $e');
      }
    } on TimeoutException catch (e) {
      developer.log('Timeout Error: ${e.message}', name: 'QuizResultService', error: e);
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    } catch (e) {
      developer.log('Exception in getQuizHistory: $e', name: 'QuizResultService', error: e);
      throw Exception('Failed to get quiz history: $e');
    }
  }
  
  // Get raw quiz history data including statistics
  Future<Map<String, dynamic>> getRawQuizHistory(String userId) async {
    try {
      developer.log('Fetching raw quiz history for user: $userId', name: 'QuizResultService');
      
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/quiz-history'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout, onTimeout: () {
        developer.log('Raw quiz history request timed out', name: 'QuizResultService');
        throw TimeoutException('Connection timeout while fetching raw quiz history');
      });

      developer.log('Raw quiz history response status: ${response.statusCode}', name: 'QuizResultService');
      
      if (response.statusCode != 200) {
        developer.log('Error response body: ${response.body}', name: 'QuizResultService');
        throw Exception('Failed to get quiz history. Server returned ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);
      developer.log('Successfully decoded raw quiz history response', name: 'QuizResultService');
      return responseData is Map<String, dynamic> 
          ? responseData 
          : {'raw_data': responseData};
    } on TimeoutException catch (e) {
      developer.log('Timeout Error: ${e.message}', name: 'QuizResultService', error: e);
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    } catch (e) {
      developer.log('Exception in getRawQuizHistory: $e', name: 'QuizResultService', error: e);
      throw Exception('Failed to get raw quiz history: $e');
    }
  }
  
  // Get a specific quiz result by ID
  Future<QuizResult> getQuizResult(String resultId) async {
    try {
      developer.log('Getting quiz result: $resultId', name: 'QuizResultService');
      
      final response = await http.get(
        Uri.parse('$baseUrl/quiz-result/$resultId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Connection timeout while getting quiz result');
      });

      if (response.statusCode != 200) {
        developer.log('Error getting quiz result: ${response.body}', name: 'QuizResultService');
        throw Exception('Failed to get quiz result. Server returned ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);
      developer.log('Successfully retrieved quiz result', name: 'QuizResultService');
      
      // Check if the response has a nested structure
      if (responseData is Map<String, dynamic> && responseData.containsKey('quiz_result')) {
        return QuizResult.fromJson(responseData['quiz_result']);
      }
      
      return QuizResult.fromJson(responseData);
    } catch (e) {
      developer.log('Exception in getQuizResult: $e', name: 'QuizResultService', error: e);
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
      developer.log('Submitting quiz result for user: ${user.uid}', name: 'QuizResultService');
      
      // Ensure user profile is synced before submitting quiz
      await syncUserProfile();
      
      final payload = {
        ...result.toJson(),
        'firebase_uid': user.uid,
      };
      
      developer.log('Quiz result payload: $payload', name: 'QuizResultService');
      
      final response = await http.post(
        Uri.parse('$baseUrl/quiz/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(_timeout);
      
      developer.log('Quiz result submission response: ${response.statusCode}', name: 'QuizResultService');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        developer.log('Quiz result submitted successfully', name: 'QuizResultService');
        return true;
      } else {
        developer.log('Quiz result submission failed: ${response.body}', name: 'QuizResultService');
        return false;
      }
    } catch (e) {
      developer.log('Error submitting quiz result: $e', name: 'QuizResultService', error: e);
      return false;
    }
  }

  // Format date for display
  String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }
  
  // Helper function for min value (used in string truncation)
  int min(int a, int b) {
    return a < b ? a : b;
  }
} 