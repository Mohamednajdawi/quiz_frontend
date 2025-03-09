import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Update baseUrl to work in both web and native environments
  static String get baseUrl {
    // Use the Heroku API URL for both web and native environments
    return 'https://quiz-maker-api-88ed1bfabc1c.herokuapp.com';
  }

  // Enable persistence
  static Future<void> initialize() async {
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
  }

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

  // Get all categories
  Future<List<String>> getCategories() async {
    return _withRetry(() async {
      final snapshot = await _firestore
          .collection('categories')
          .get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  // Get questions by category
  Future<List<Question>> getQuestionsByCategory(String category, {int? limit}) async {
    return _withRetry(() async {
      var query = _firestore
          .collection('questions')
          .where('category', isEqualTo: category);
      
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs
          .map((doc) => Question.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Get questions by tags
  Future<List<Question>> getQuestionsByTags(List<String> tags) async {
    final snapshot = await _firestore
        .collection('questions')
        .where('tags', arrayContainsAny: tags)
        .get();
    return snapshot.docs
        .map((doc) => Question.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  // Add a new question
  Future<String> addQuestion(Question question) async {
    final docRef = await _firestore.collection('questions').add(question.toJson());
    return docRef.id;
  }

  // Update an existing question
  Future<void> updateQuestion(Question question) async {
    await _firestore
        .collection('questions')
        .doc(question.id)
        .update(question.toJson());
  }

  // Delete a question
  Future<void> deleteQuestion(String questionId) async {
    await _firestore.collection('questions').doc(questionId).delete();
  }

  // Get random questions from a category
  Future<List<Question>> getRandomQuestions(String category, int count) async {
    return _withRetry(() async {
      final snapshot = await _firestore
          .collection('questions')
          .where('category', isEqualTo: category)
          .limit(count)
          .get(const GetOptions(source: Source.serverAndCache));
      
      return snapshot.docs
          .map((doc) => Question.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Get user's quiz history
  Future<List<Map<String, dynamic>>> getUserQuizHistory(String userId) async {
    return _withRetry(() async {
      final snapshot = await _firestore
          .collection('results')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
                'timestamp': (doc.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              })
          .toList();
    });
  }

  // Get user's URL quiz history
  Future<List<Map<String, dynamic>>> getUserURLQuizHistory(String userId) async {
    return _withRetry(() async {
      final snapshot = await _firestore
          .collection('url_quizzes')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
                'timestamp': (doc.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              })
          .toList();
    });
  }

  // Generate quiz from URL
  Future<Map<String, dynamic>> generateQuiz(String url, {int numQuestions = 5, String difficulty = 'medium'}) async {
    try {
      final response = await http.post(
        Uri.parse('${QuizService.baseUrl}/generate-quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          'num_questions': numQuestions,
          'difficulty': difficulty,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to generate quiz: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error generating quiz: $e');
    }
  }

  // Generate quiz from PDF
  Future<Map<String, dynamic>> generateQuizFromPDF(dynamic pdfFile, {int numQuestions = 5, String difficulty = 'medium'}) async {
    try {
      if (kIsWeb) {
        // Web implementation
        // For web, pdfFile should be a Uint8List (bytes)
        Uint8List pdfBytes;
        String fileName;
        
        if (pdfFile is Map) {
          // If we're receiving a map with bytes and filename (from file_picker on web)
          pdfBytes = pdfFile['bytes'] as Uint8List;
          fileName = pdfFile['name'] as String;
        } else {
          // If we're just receiving bytes directly
          pdfBytes = pdfFile as Uint8List;
          fileName = 'document.pdf';
        }
        
        // Create a multipart request for web
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${QuizService.baseUrl}/generate-quiz-from-pdf'),
        );
        
        // Add PDF file as bytes
        request.files.add(
          http.MultipartFile.fromBytes(
            'pdf_file',
            pdfBytes,
            filename: fileName,
            contentType: MediaType('application', 'pdf'),
          ),
        );
        
        // Add other fields
        request.fields['num_questions'] = numQuestions.toString();
        request.fields['difficulty'] = difficulty;
        
        // Send the request
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          throw Exception('Failed to generate quiz from PDF: ${response.body}');
        }
      } else {
        // Native implementation (Android, iOS, desktop)
        // For native platforms, pdfFile should be a File
        File nativePdfFile = pdfFile as File;
        
        // Create a multipart request
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${QuizService.baseUrl}/generate-quiz-from-pdf'),
        );
        
        // Add PDF file to the request
        request.files.add(
          await http.MultipartFile.fromPath(
            'pdf_file',
            nativePdfFile.path,
            contentType: MediaType('application', 'pdf'),
          ),
        );
        
        // Add other fields
        request.fields['num_questions'] = numQuestions.toString();
        request.fields['difficulty'] = difficulty;
        
        // Send the request
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          throw Exception('Failed to generate quiz from PDF: ${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Error generating quiz from PDF: $e');
    }
  }

  // Get specific URL quiz details
  Future<Map<String, dynamic>?> getURLQuizDetails(String quizId) async {
    return _withRetry(() async {
      final doc = await _firestore
          .collection('url_quizzes')
          .doc(quizId)
          .get();

      if (!doc.exists) return null;

      return {
        'id': doc.id,
        ...doc.data()!,
        'timestamp': (doc.data()!['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      };
    });
  }

  // Save URL quiz result
  Future<void> saveURLQuizResult({
    required String userId,
    required Map<String, dynamic> quizData,
    required List<int> userAnswers,
    required int score,
    required Duration timeTaken,
  }) async {
    return _withRetry(() async {
      // Determine the quiz type (url or pdf)
      final String quizType = quizData['sourceType'] == 'pdf' ? 'pdf' : 'url';
      final String sourceInfo = quizType == 'pdf' 
          ? (quizData['sourceFileName'] ?? 'Unknown PDF')
          : (quizData['url'] ?? '');
      
      final quizDoc = await _firestore.collection('url_quizzes').add({
        'userId': userId,
        'topic': quizData['topic'] ?? (quizType == 'pdf' ? 'PDF Quiz' : 'URL Quiz'),
        'category': quizData['category'] ?? 'General Knowledge',
        'subcategory': quizData['subcategory'] ?? 'Miscellaneous',
        'questions': quizData['questions'],
        'userAnswers': userAnswers,
        'score': score,
        'totalQuestions': quizData['questions'].length,
        'timeTaken': timeTaken.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
        'sourceType': quizType,
        'sourceInfo': sourceInfo,
      });

      await quizDoc.get();

      final resultDoc = await _firestore.collection('results').add({
        'userId': userId,
        'category': quizData['category'] ?? 'General Knowledge',
        'subcategory': quizData['subcategory'] ?? 'Miscellaneous',
        'topic': quizData['topic'] ?? (quizType == 'pdf' ? 'PDF Quiz' : 'URL Quiz'),
        'score': score,
        'totalQuestions': quizData['questions'].length,
        'timeTaken': timeTaken.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
        'quizRef': quizDoc.id,
        'type': quizType,
      });

      await resultDoc.get();
    });
  }

  // Save quiz result
  Future<void> saveQuizResult({
    required String userId,
    required String topic,
    required String category,
    required String subcategory,
    required int score,
    required int totalQuestions,
    required Duration timeTaken,
  }) async {
    return _withRetry(() async {
      final docRef = await _firestore.collection('results').add({
        'userId': userId,
        'topic': topic,
        'category': category,
        'subcategory': subcategory,
        'score': score,
        'totalQuestions': totalQuestions,
        'timeTaken': timeTaken.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await docRef.get();
    });
  }

  // Get all available quizzes from the backend
  Future<List<Map<String, dynamic>>> getAllAvailableQuizzes() async {
    try {
      final response = await http.get(
        Uri.parse('${QuizService.baseUrl}/topics'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch quizzes: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching quizzes: $e');
    }
  }
  
  // Get a specific quiz by topic ID
  Future<Map<String, dynamic>> getQuizByTopicId(int topicId) async {
    try {
      final response = await http.get(
        Uri.parse('${QuizService.baseUrl}/quiz/$topicId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch quiz: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching quiz: $e');
    }
  }
  
  // Get all categories and subcategories from the backend
  Future<Map<String, List<String>>> getCategoriesAndSubcategories() async {
    try {
      final response = await http.get(
        Uri.parse('${QuizService.baseUrl}/categories'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        Map<String, List<String>> result = {};
        
        data.forEach((key, value) {
          result[key] = List<String>.from(value);
        });
        
        return result;
      } else {
        throw Exception('Failed to fetch categories: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }
  
  // Record a quiz attempt
  Future<DateTime> recordQuizAttempt(int topicId) async {
    try {
      final response = await http.post(
        Uri.parse('${QuizService.baseUrl}/record-quiz-attempt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic_id': topicId,
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return DateTime.parse(data['timestamp']);
      } else {
        throw Exception('Failed to record quiz attempt: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error recording quiz attempt: $e');
    }
  }
  
  // Get quiz attempts for a specific topic
  Future<List<DateTime>> getQuizAttempts(int topicId) async {
    try {
      final response = await http.get(
        Uri.parse('${QuizService.baseUrl}/quiz-attempts/$topicId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> attempts = data['attempts'];
        return attempts.map((attempt) => DateTime.parse(attempt)).toList();
      } else {
        throw Exception('Failed to fetch quiz attempts: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching quiz attempts: $e');
    }
  }
} 