import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app/models/question.dart';

void main() {
  group('Question Model Tests', () {
    test('should create Question instance from constructor', () {
      final question = Question(
        id: '1',
        text: 'What is Flutter?',
        options: ['A framework', 'A language', 'An IDE', 'A database'],
        correctOptionIndex: 0,
        explanation: 'Flutter is a UI framework by Google',
        tags: ['flutter', 'mobile'],
        category: 'Flutter',
        difficulty: 1,
      );

      expect(question.id, '1');
      expect(question.text, 'What is Flutter?');
      expect(question.options.length, 4);
      expect(question.correctOptionIndex, 0);
      expect(question.imageUrl, null);
      expect(question.explanation, 'Flutter is a UI framework by Google');
      expect(question.tags, ['flutter', 'mobile']);
      expect(question.category, 'Flutter');
      expect(question.difficulty, 1);
    });

    test('should create Question from JSON', () {
      final json = {
        'id': '1',
        'text': 'What is Flutter?',
        'options': ['A framework', 'A language', 'An IDE', 'A database'],
        'correctOptionIndex': 0,
        'imageUrl': 'https://example.com/image.png',
        'explanation': 'Flutter is a UI framework by Google',
        'tags': ['flutter', 'mobile'],
        'category': 'Flutter',
        'difficulty': 1,
      };

      final question = Question.fromJson(json);

      expect(question.id, json['id']);
      expect(question.text, json['text']);
      expect(question.options, json['options']);
      expect(question.correctOptionIndex, json['correctOptionIndex']);
      expect(question.imageUrl, json['imageUrl']);
      expect(question.explanation, json['explanation']);
      expect(question.tags, json['tags']);
      expect(question.category, json['category']);
      expect(question.difficulty, json['difficulty']);
    });

    test('should convert Question to JSON', () {
      final question = Question(
        id: '1',
        text: 'What is Flutter?',
        options: ['A framework', 'A language', 'An IDE', 'A database'],
        correctOptionIndex: 0,
        imageUrl: 'https://example.com/image.png',
        explanation: 'Flutter is a UI framework by Google',
        tags: ['flutter', 'mobile'],
        category: 'Flutter',
        difficulty: 1,
      );

      final json = question.toJson();

      expect(json['id'], question.id);
      expect(json['text'], question.text);
      expect(json['options'], question.options);
      expect(json['correctOptionIndex'], question.correctOptionIndex);
      expect(json['imageUrl'], question.imageUrl);
      expect(json['explanation'], question.explanation);
      expect(json['tags'], question.tags);
      expect(json['category'], question.category);
      expect(json['difficulty'], question.difficulty);
    });
  });
} 