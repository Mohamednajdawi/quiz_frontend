class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctOptionIndex;
  final String? imageUrl;
  final String explanation;
  final List<String> tags;
  final String category;
  final int difficulty;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctOptionIndex,
    this.imageUrl,
    required this.explanation,
    required this.tags,
    required this.category,
    required this.difficulty,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      text: json['text'] as String,
      options: List<String>.from(json['options'] as List),
      correctOptionIndex: json['correctOptionIndex'] as int,
      imageUrl: json['imageUrl'] as String?,
      explanation: json['explanation'] as String,
      tags: List<String>.from(json['tags'] as List),
      category: json['category'] as String,
      difficulty: json['difficulty'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'imageUrl': imageUrl,
      'explanation': explanation,
      'tags': tags,
      'category': category,
      'difficulty': difficulty,
    };
  }
} 