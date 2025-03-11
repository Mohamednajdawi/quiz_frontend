class QuizResult {
  final String? id;
  final String? userId;
  final int? topicId;
  final String? topicName;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final int timeTaken;
  final bool completed;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? dayOfWeek;
  final String? timeOfDay;
  final double? averageTimePerQuestion;
  final String? difficultyLevel;
  final int? streak;
  final String? quizContext;
  final List<QuestionAnswer>? answers;

  QuizResult({
    this.id,
    this.userId,
    this.topicId,
    this.topicName,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.timeTaken,
    required this.completed,
    this.startedAt,
    this.completedAt,
    this.dayOfWeek,
    this.timeOfDay,
    this.averageTimePerQuestion,
    this.difficultyLevel,
    this.streak,
    this.quizContext,
    this.answers,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    try {
      List<QuestionAnswer>? answers;
      if (json['answers'] != null) {
        answers = List<QuestionAnswer>.from(
          (json['answers'] as List).map((x) => QuestionAnswer.fromJson(x)),
        );
      }

      // Parse dates safely
      DateTime? startedAt;
      if (json['started_at'] != null && json['started_at'].toString().isNotEmpty) {
        try {
          startedAt = DateTime.parse(json['started_at']);
        } catch (e) {
          print('Error parsing started_at: $e');
        }
      }
      
      DateTime? completedAt;
      if (json['completed_at'] != null && json['completed_at'].toString().isNotEmpty) {
        try {
          completedAt = DateTime.parse(json['completed_at']);
        } catch (e) {
          print('Error parsing completed_at: $e');
        }
      }

      return QuizResult(
        id: json['id']?.toString(),
        userId: json['user_id']?.toString(),
        topicId: json['topic_id'],
        topicName: json['topic_name'],
        score: json['score'] is double 
          ? (json['score'] * 100).round() 
          : (json['correct_answers'] / json['total_questions'] * 100).round(),
        totalQuestions: json['total_questions'] ?? 0,
        correctAnswers: json['correct_answers'] ?? 0,
        timeTaken: json['time_taken'] ?? 0,
        completed: json['completed'] ?? false,
        startedAt: startedAt,
        completedAt: completedAt,
        dayOfWeek: json['day_of_week'],
        timeOfDay: json['time_of_day'],
        averageTimePerQuestion: json['average_time_per_question']?.toDouble(),
        difficultyLevel: json['difficulty_level'],
        streak: json['streak'],
        quizContext: json['quiz_context'],
        answers: answers,
      );
    } catch (e) {
      print('Error parsing quiz result: $e');
      // Return a default object with error handling
      return QuizResult(
        score: 0,
        totalQuestions: 0,
        correctAnswers: 0,
        timeTaken: 0,
        completed: false,
        topicName: 'Error loading quiz',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'topic_id': topicId,
      'score': score / 100.0, // Convert back to decimal
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'time_taken': timeTaken,
      'completed': completed,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'day_of_week': dayOfWeek,
      'time_of_day': timeOfDay,
      'average_time_per_question': averageTimePerQuestion,
      'difficulty_level': difficultyLevel,
      'streak': streak,
      'quiz_context': quizContext,
    };
  }
}

class QuestionAnswer {
  final String questionText;
  final List<dynamic> options;
  final String correctAnswer;
  final String userAnswer;
  final bool isCorrect;
  final int? timeTaken;
  final int? confidenceLevel;

  QuestionAnswer({
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.userAnswer,
    required this.isCorrect,
    this.timeTaken,
    this.confidenceLevel,
  });

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) {
    return QuestionAnswer(
      questionText: json['question_text'] ?? '',
      options: json['options'] ?? [],
      correctAnswer: json['correct_answer'] ?? '',
      userAnswer: json['user_answer'] ?? '',
      isCorrect: json['is_correct'] ?? false,
      timeTaken: json['time_taken'],
      confidenceLevel: json['confidence_level'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_text': questionText,
      'options': options,
      'correct_answer': correctAnswer,
      'user_answer': userAnswer,
      'is_correct': isCorrect,
      'time_taken': timeTaken,
      'confidence_level': confidenceLevel,
    };
  }
} 