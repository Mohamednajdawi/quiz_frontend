import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/quiz_result_service.dart';
import '../models/quiz_result.dart';
import 'dart:math';
import 'package:intl/intl.dart';

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({Key? key}) : super(key: key);

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  final QuizResultService _quizResultService = QuizResultService();
  List<QuizResult>? _quizResults;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuizHistory();
  }

  Future<void> _loadQuizHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You need to be logged in to view quiz history';
        });
        return;
      }

      // Log useful information for debugging
      print('Fetching quiz history for user: $userId');
      
      final results = await _quizResultService.getQuizHistory(userId);
      
      setState(() {
        _quizResults = results;
        _isLoading = false;
      });
      
      print('Successfully loaded ${_quizResults?.length ?? 0} quiz results');
    } catch (e) {
      print('Error loading quiz history: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load quiz history: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuizHistory,
            tooltip: 'Refresh quiz history',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading quiz history...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadQuizHistory,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_quizResults == null || _quizResults!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No quiz history found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Complete a quiz to see your results here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quizResults!.length,
      itemBuilder: (context, index) {
        final result = _quizResults![index];
        return _buildQuizResultCard(result);
      },
    );
  }

  Widget _buildQuizResultCard(QuizResult result) {
    // Calculate percentage score
    final percentScore = ((result.correctAnswers / max(result.totalQuestions, 1)) * 100).round();
    
    // Format the date
    final formattedDate = result.completedAt != null 
        ? DateFormat('MMM d, yyyy - h:mm a').format(result.completedAt!)
        : 'Date not available';
    
    // Determine score color
    Color scoreColor;
    if (percentScore >= 80) {
      scoreColor = Colors.green;
    } else if (percentScore >= 60) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    result.topicName ?? 'Unknown Topic',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$percentScore%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Time: ${_formatTime(result.timeTaken)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  Icons.check_circle_outline,
                  'Score',
                  '${result.correctAnswers}/${result.totalQuestions}',
                ),
                if (result.averageTimePerQuestion != null)
                  _buildStatItem(
                    Icons.timer_outlined,
                    'Avg Time',
                    '${result.averageTimePerQuestion!.toStringAsFixed(1)}s',
                  ),
                if (result.dayOfWeek != null)
                  _buildStatItem(
                    Icons.calendar_today,
                    'Day',
                    result.dayOfWeek!,
                  ),
              ],
            ),
            if (result.difficultyLevel != null || result.streak != null || result.timeOfDay != null)
              const SizedBox(height: 10),
            if (result.difficultyLevel != null || result.streak != null || result.timeOfDay != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (result.difficultyLevel != null)
                    _buildStatItem(
                      Icons.speed,
                      'Difficulty',
                      result.difficultyLevel!,
                    ),
                  if (result.streak != null)
                    _buildStatItem(
                      Icons.flash_on,
                      'Streak',
                      result.streak.toString(),
                    ),
                  if (result.timeOfDay != null)
                    _buildStatItem(
                      Icons.access_time,
                      'Time of Day',
                      result.timeOfDay!,
                    ),
                ],
              ),
            if (result.quizContext != null && result.quizContext!.isNotEmpty)
              const SizedBox(height: 12),
            if (result.quizContext != null && result.quizContext!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Context:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.quizContext!,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  // Get color based on score percentage
  Color _getScoreColor(double score) {
    final percentage = score * 100;
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 60) {
      return Colors.orange;
    }
    return Colors.red;
  }
} 