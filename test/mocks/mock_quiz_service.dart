import 'package:mockito/mockito.dart';
import 'package:quiz_app/services/quiz_service.dart';
import 'package:quiz_app/models/question.dart';

class MockQuizService extends Mock implements QuizService {
  final List<Question> _mockQuestions = [
    Question(
      id: '1',
      text: 'What is Flutter?',
      options: ['A framework', 'A language', 'An IDE', 'A database'],
      correctOptionIndex: 0,
      explanation: 'Flutter is a UI framework by Google',
      tags: ['flutter', 'mobile'],
      category: 'Flutter',
      difficulty: 1,
    ),
    Question(
      id: '2',
      text: 'What is Dart?',
      options: [
        'A programming language',
        'A database',
        'A design pattern',
        'A testing framework'
      ],
      correctOptionIndex: 0,
      explanation: 'Dart is the programming language used for Flutter development',
      tags: ['dart', 'programming'],
      category: 'Flutter',
      difficulty: 1,
    ),
  ];

  final List<String> _mockCategories = ['Flutter', 'Dart', 'Firebase'];

  @override
  Future<List<String>> getCategories() async {
    return _mockCategories;
  }

  @override
  Future<List<Question>> getQuestionsByCategory(String category,
      {int? limit}) async {
    return _mockQuestions
        .where((q) => q.category == category)
        .take(limit ?? _mockQuestions.length)
        .toList();
  }

  @override
  Future<List<Question>> getRandomQuestions(String category, int count) async {
    return _mockQuestions
        .where((q) => q.category == category)
        .take(count)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getUserQuizHistory(String userId) async {
    return [
      {
        'id': '1',
        'userId': userId,
        'category': 'Flutter',
        'score': 8,
        'totalQuestions': 10,
        'timeTaken': 300,
        'timestamp': DateTime.now(),
      }
    ];
  }
} 