import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/question.dart';
import '../../services/quiz_service.dart';

class QuizScreen extends StatefulWidget {
  final List<Question> questions;
  final String category;
  final int? topicId;

  const QuizScreen({
    super.key,
    required this.questions,
    required this.category,
    this.topicId,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  List<int?> _answers = [];
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.questions.length, null);
    _stopwatch.start();
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _answers[_currentIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _finishQuiz() {
    _stopwatch.stop();
    final score = _calculateScore();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          score: score,
          totalQuestions: widget.questions.length,
          timeTaken: _stopwatch.elapsed,
          category: widget.category,
          questions: widget.questions,
          userAnswers: _answers,
          topicId: widget.topicId,
        ),
      ),
    );
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_answers[i] == widget.questions[i].correctOptionIndex) {
        score++;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} Quiz'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '${_currentIndex + 1}/${widget.questions.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.text,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (question.imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: question.imageUrl!,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ...List.generate(
              question.options.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Material(
                  color: _answers[_currentIndex] == index
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _selectAnswer(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _answers[_currentIndex] == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _answers[_currentIndex] == index
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade500,
                              ),
                              color: _answers[_currentIndex] == index
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            child: _answers[_currentIndex] == index
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${String.fromCharCode(65 + index)}. ${question.options[index]}',
                              style: TextStyle(
                                color: _answers[_currentIndex] == index
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentIndex > 0 ? _previousQuestion : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
                ElevatedButton.icon(
                  onPressed: _answers[_currentIndex] != null
                      ? _currentIndex < widget.questions.length - 1
                          ? _nextQuestion
                          : _finishQuiz
                      : null,
                  icon: Icon(
                    _currentIndex < widget.questions.length - 1
                        ? Icons.arrow_forward
                        : Icons.check,
                  ),
                  label: Text(
                    _currentIndex < widget.questions.length - 1
                        ? 'Next'
                        : 'Finish',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuizResultScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final Duration timeTaken;
  final String category;
  final List<Question> questions;
  final List<int?> userAnswers;
  final int? topicId;

  const QuizResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.timeTaken,
    required this.category,
    required this.questions,
    required this.userAnswers,
    this.topicId,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  final QuizService _quizService = QuizService();
  bool _attemptRecorded = false;
  DateTime? _attemptTimestamp;
  bool _showDetailsView = false;

  @override
  void initState() {
    super.initState();
    _recordQuizAttempt();
  }

  Future<void> _recordQuizAttempt() async {
    if (widget.topicId != null) {
      try {
        final timestamp = await _quizService.recordQuizAttempt(widget.topicId!);
        if (mounted) {
          setState(() {
            _attemptRecorded = true;
            _attemptTimestamp = timestamp;
          });
        }
      } catch (e) {
        // Handle error or just continue
        print('Failed to record quiz attempt: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.score / widget.totalQuestions) * 100;
    final minutes = widget.timeTaken.inMinutes;
    final seconds = widget.timeTaken.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      percentage >= 80
                          ? '🎉 Excellent!'
                          : percentage >= 60
                              ? '👍 Good Job!'
                              : '💪 Keep Practicing!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.score}/${widget.totalQuestions} correct (${percentage.round()}%)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: percentage >= 80
                                ? Colors.green
                                : percentage >= 60
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Time: $minutes:${seconds.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_attemptTimestamp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Completed on: ${_attemptTimestamp!.toLocal().toString().split('.')[0]}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showDetailsView = !_showDetailsView;
                });
              },
              icon: Icon(
                _showDetailsView ? Icons.visibility_off : Icons.visibility,
                size: 24,
              ),
              label: Text(
                _showDetailsView ? 'Hide Answer Details' : 'Show Answer Details',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_showDetailsView) ...[
              Text(
                'Question Review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ...List.generate(
                widget.questions.length,
                (index) => Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Question ${index + 1}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            widget.questions[index].text,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (widget.questions[index].imageUrl != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: widget.questions[index].imageUrl!,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                                        ? Icons.check_circle_outline
                                        : Icons.highlight_off,
                                    color: widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                                        ? Colors.green
                                        : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your Answer:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.userAnswers[index] != null
                                    ? widget.questions[index].options[widget.userAnswers[index]!]
                                    : 'Not answered',
                                style: TextStyle(
                                  color: widget.userAnswers[index] == widget.questions[index].correctOptionIndex
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Correct Answer:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.questions[index].options[widget.questions[index].correctOptionIndex],
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.purple.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Explanation:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.questions[index].explanation,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Tap "Show Answer Details" to review your answers',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 