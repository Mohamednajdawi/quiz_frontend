import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/quiz_service.dart';

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  final _quizService = QuizService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _urlQuizHistory = [];
  String? _error;
  Map<String, bool> _expandedItems = {}; // Track which items are expanded

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Load both regular and URL quiz history
      final [history, urlHistory] = await Future.wait([
        _quizService.getUserQuizHistory(userId),
        _quizService.getUserURLQuizHistory(userId),
      ]);

      setState(() {
        _history = history;
        _urlQuizHistory = urlHistory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showQuizDetails(Map<String, dynamic> quiz) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quiz['topic'] ?? quiz['category'] ?? 'Quiz',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(color: Colors.grey.shade700),
                if (quiz['sourceType'] == 'pdf' && quiz['sourceInfo'] != null) ...[
                  Text(
                    'PDF File:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red.shade300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quiz['sourceInfo'],
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else if (quiz['sourceType'] == 'url' && quiz['sourceInfo'] != null) ...[
                  Text(
                    'Source URL:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quiz['sourceInfo'],
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                ] else if (quiz['sourceUrl'] != null) ...[
                  // Legacy support for older quiz records
                  Text(
                    'Source URL:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quiz['sourceUrl'],
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Questions:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.purpleAccent,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  (quiz['questions'] as List).length,
                  (index) {
                    final question = quiz['questions'][index];
                    final userAnswer = quiz['userAnswers'][index];
                    final correctAnswer = _letterToIndex(question['right_option']);
                    final isCorrect = userAnswer == correctAnswer;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isCorrect
                          ? Colors.green.shade900.withOpacity(0.4)
                          : Colors.red.shade900.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCorrect ? Icons.check_circle : Icons.cancel,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Question ${index + 1}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
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
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                question['question'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCorrect ? Colors.green.shade900.withOpacity(0.3) : Colors.red.shade900.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Answer:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    question['options'][userAnswer],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isCorrect) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade900.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade700),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Correct Answer:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      question['options'][correctAnswer],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _letterToIndex(String letter) {
    return letter.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Duration _getDurationFromQuiz(Map<String, dynamic> quiz) {
    // The timeTaken field is stored in seconds in the database
    final timeTakenSeconds = quiz['timeTaken'] as int;
    
    // Handle different time formats
    if (timeTakenSeconds < 3600) {  // If less than an hour, it's likely stored correctly
      return Duration(seconds: timeTakenSeconds);
    } else if (timeTakenSeconds < 24 * 3600) {  // If less than a day but more than an hour, check if it's milliseconds
      // If it seems like milliseconds were stored as seconds (too large for a typical quiz)
      return Duration(milliseconds: timeTakenSeconds);
    } else {
      // Fall back to seconds if we can't determine the format
      return Duration(seconds: timeTakenSeconds);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final allHistory = [..._history, ..._urlQuizHistory]
      ..sort((a, b) => (b['timestamp'] as DateTime)
          .compareTo(a['timestamp'] as DateTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black87,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
            ))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : allHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No quiz history yet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete some quizzes to see them here',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: Colors.purpleAccent,
                      backgroundColor: Colors.grey.shade900,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: allHistory.length,
                        itemBuilder: (context, index) {
                          final quiz = allHistory[index];
                          final score = quiz['score'] as int;
                          final total = quiz['totalQuestions'] as int;
                          final percentage = (score / total * 100).round();
                          final timeTaken = _getDurationFromQuiz(quiz);
                          final timestamp = quiz['timestamp'] as DateTime;
                          final isUrlQuiz = quiz['questions'] != null;
                          final quizId = quiz['id'] ?? '${quiz['topic']}_${quiz['timestamp'].millisecondsSinceEpoch}';
                          
                          // Check if this item is expanded
                          _expandedItems.putIfAbsent(quizId, () => false);
                          final isExpanded = _expandedItems[quizId]!;
                          
                          // Determine quiz type icon
                          IconData quizTypeIcon;
                          Color quizTypeColor;
                          if (quiz['type'] == 'pdf' || quiz['sourceType'] == 'pdf') {
                            quizTypeIcon = Icons.picture_as_pdf_rounded;
                            quizTypeColor = Colors.red.shade700;
                          } else if (quiz['type'] == 'url' || quiz['sourceType'] == 'url' || quiz['sourceUrl'] != null) {
                            quizTypeIcon = Icons.link_rounded;
                            quizTypeColor = Colors.blue.shade700;
                          } else {
                            quizTypeIcon = Icons.quiz_rounded;
                            quizTypeColor = Colors.purple.shade700;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: Colors.grey.shade900,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        percentage >= 80
                                            ? Icons.star
                                            : percentage >= 50
                                                ? Icons.star_half
                                                : Icons.star_border,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          quiz['topic'] ?? quiz['category'] ?? 'Quiz',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Icon(quizTypeIcon, size: 20, color: quizTypeColor),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Score: $score/$total ($percentage%)',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: percentage >= 80
                                              ? Colors.greenAccent
                                              : percentage >= 50
                                                  ? Colors.orangeAccent
                                                  : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.timer_outlined, size: 16, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Time: ${_formatDuration(timeTaken)}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(timestamp),
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _expandedItems[quizId] = !isExpanded;
                                      });
                                    },
                                    icon: Icon(
                                      isExpanded ? Icons.visibility_off : Icons.visibility,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isExpanded ? 'Hide Details' : 'Show Details',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purpleAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      minimumSize: const Size(double.infinity, 36),
                                    ),
                                  ),
                                  if (isExpanded) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade800,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade700),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Quiz Details',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purpleAccent,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Category: ${quiz['category'] ?? 'N/A'}',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          if (quiz['subcategory'] != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Subcategory: ${quiz['subcategory']}',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            'Performance: ${percentage >= 80 ? 'Excellent' : percentage >= 60 ? 'Good' : 'Needs Improvement'}',
                                            style: TextStyle(
                                              color: percentage >= 80
                                                  ? Colors.greenAccent
                                                  : percentage >= 60
                                                      ? Colors.orangeAccent
                                                      : Colors.redAccent,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isUrlQuiz && quiz['questions'] != null) ...[
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () => _showQuizDetails(quiz),
                                        icon: const Icon(Icons.question_answer),
                                        label: const Text('View Question Details'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey.shade800,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          minimumSize: const Size(double.infinity, 36),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
} 