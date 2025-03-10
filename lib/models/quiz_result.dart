class QuizResult {
  final int id;
  final int topicId;
  final String topicName;
  final String category;
  final String subcategory;
  final double score;
  final int correctAnswers;
  final int totalQuestions;
  final int? timeTaken;
  final String? startedAt;
  final String? completedAt;
  final List<QuestionAnswer>? answers;
  
  // Enhanced date fields
  final String? dayOfWeek;
  final String? timeOfDay;
  
  // Enhanced quiz metrics
  final double? averageTimePerQuestion;
  final String? difficultyLevel;
  final int? streak;
  final String? quizContext;

  QuizResult({
    required this.id,
    required this.topicId,
    required this.topicName,
    required this.category,
    required this.subcategory, 
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    this.timeTaken,
    this.startedAt,
    this.completedAt,
    this.answers,
    this.dayOfWeek,
    this.timeOfDay,
    this.averageTimePerQuestion,
    this.difficultyLevel,
    this.streak,
    this.quizContext,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    List<QuestionAnswer>? answersList;
    
    if (json['answers'] != null) {
      answersList = (json['answers'] as List)
          .map((answer) => QuestionAnswer.fromJson(answer))
          .toList();
    }

    return QuizResult(
      id: json['id'] as int,
      topicId: json['topic_id'] as int,
      topicName: json['topic_name'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      score: (json['score'] as num).toDouble(),
      correctAnswers: json['correct_answers'] as int,
      totalQuestions: json['total_questions'] as int,
      timeTaken: json['time_taken'] as int?,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      answers: answersList,
      dayOfWeek: json['day_of_week'] as String?,
      timeOfDay: json['time_of_day'] as String?,
      averageTimePerQuestion: json['average_time_per_question'] != null 
          ? (json['average_time_per_question'] as num).toDouble() 
          : null,
      difficultyLevel: json['difficulty_level'] as String?,
      streak: json['streak'] as int?,
      quizContext: json['quiz_context'] as String?,
    );
  }

  // Summary representation for listing in history
  factory QuizResult.fromHistoryJson(Map<String, dynamic> json) {
    return QuizResult(
      id: json['quiz_result_id'] as int,
      topicId: json['topic_id'] as int,
      topicName: json['topic_name'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      score: (json['score'] as num).toDouble(),
      correctAnswers: json['correct_answers'] as int,
      totalQuestions: json['total_questions'] as int,
      timeTaken: json['time_taken'] as int?,
      completedAt: json['completed_at'] as String?,
      dayOfWeek: json['day_of_week'] as String?,
      timeOfDay: json['time_of_day'] as String?,
      averageTimePerQuestion: json['average_time_per_question'] != null 
          ? (json['average_time_per_question'] as num).toDouble() 
          : null,
      difficultyLevel: json['difficulty_level'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic_id': topicId,
      'topic_name': topicName,
      'category': category,
      'subcategory': subcategory,
      'score': score,
      'correct_answers': correctAnswers,
      'total_questions': totalQuestions,
      'time_taken': timeTaken,
      'started_at': startedAt,
      'completed_at': completedAt,
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
  final int questionId;
  final String questionText;
  final List<dynamic> options;
  final String correctAnswer;
  final String? userAnswer;
  final bool isCorrect;
  final int? timeTaken;
  final int? confidenceLevel;  // 1-5 rating

  QuestionAnswer({
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.userAnswer,
    required this.isCorrect,
    this.timeTaken,
    this.confidenceLevel,
  });

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) {
    return QuestionAnswer(
      questionId: json['question_id'] as int,
      questionText: json['question_text'] as String,
      options: json['options'] as List<dynamic>,
      correctAnswer: json['correct_answer'] as String,
      userAnswer: json['user_answer'] as String?,
      isCorrect: json['is_correct'] as bool,
      timeTaken: json['time_taken'] as int?,
      confidenceLevel: json['confidence_level'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'user_answer': userAnswer,
      'is_correct': isCorrect,
      'time_taken': timeTaken,
      'confidence_level': confidenceLevel,
    };
  }
} 