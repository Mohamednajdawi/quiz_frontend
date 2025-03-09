import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/quiz_service.dart';
import 'dart:ui';
import 'dart:math' as math;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  bool _isLoading = true;
  Map<String, dynamic>? _analyticsData;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _loadAnalytics();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
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

      // Combine both histories
      final allHistory = [...history, ...urlHistory];
      
      // Sort history by timestamp first
      allHistory.sort((a, b) {
        final aTimestamp = a['timestamp'] is DateTime 
            ? a['timestamp'] as DateTime
            : DateTime.parse(a['timestamp'].toString());
        final bTimestamp = b['timestamp'] is DateTime 
            ? b['timestamp'] as DateTime
            : DateTime.parse(b['timestamp'].toString());
        return aTimestamp.compareTo(bTimestamp); // Oldest to newest for performance chart
      });

      // Calculate analytics data
      final totalQuizzes = allHistory.length;
      int totalScore = 0;
      int totalQuestions = 0;
      final Map<String, int> categoryAttempts = {};
      final Map<String, int> categoryCorrectAnswers = {};
      final Map<String, int> categoryTotalQuestions = {};
      final List<int> scores = [];
      
      for (final quiz in allHistory) {
        final score = quiz['score'] as int;
        final total = quiz['totalQuestions'] as int;
        
        // Ensure category is never "Unknown" by providing a meaningful default
        String category = quiz['category'] as String? ?? '';
        if (category.isEmpty || category == 'Unknown') {
          // Use topic or URL quiz as fallback
          category = quiz['topic'] as String? ?? 'URL Quiz';
        }
        
        totalScore += score;
        totalQuestions += total;
        scores.add((score / total * 100).round()); // Store percentage scores
        
        // Track attempts per category
        categoryAttempts[category] = (categoryAttempts[category] ?? 0) + 1;
        
        // Track correct answers and total questions per category for accurate percentage
        categoryCorrectAnswers[category] = (categoryCorrectAnswers[category] ?? 0) + score;
        categoryTotalQuestions[category] = (categoryTotalQuestions[category] ?? 0) + total;
      }

      // Calculate category accuracy based on total correct answers divided by total questions
      final Map<String, double> categoryAccuracy = {};
      for (final category in categoryAttempts.keys) {
        final correctAnswers = categoryCorrectAnswers[category] ?? 0;
        final totalCategoryQuestions = categoryTotalQuestions[category] ?? 1; // Avoid division by zero
        categoryAccuracy[category] = correctAnswers / totalCategoryQuestions;
      }

      // Sort recent history by newest first
      allHistory.sort((a, b) {
        final aTimestamp = a['timestamp'] is DateTime 
            ? a['timestamp'] as DateTime
            : DateTime.parse(a['timestamp'].toString());
        final bTimestamp = b['timestamp'] is DateTime 
            ? b['timestamp'] as DateTime
            : DateTime.parse(b['timestamp'].toString());
        return bTimestamp.compareTo(aTimestamp); // Most recent first for display
      });

      setState(() {
        _analyticsData = {
          'totalQuizzes': totalQuizzes,
          'averageScore': totalQuizzes > 0 ? (totalScore / totalQuestions) * 100 : 0,
          'categoryAttempts': categoryAttempts,
          'categoryAccuracy': categoryAccuracy,
          'scores': scores, // Now contains chronological percentage scores
          'recentHistory': allHistory.take(5).toList(),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAnalytics();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analyticsData == null || _analyticsData!['totalQuizzes'] == 0
              ? _buildEmptyState()
              : _buildAnalytics(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Quiz Data Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Take some quizzes to see your analytics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start a Quiz'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 24),
            _buildPerformanceChart(),
            const SizedBox(height: 24),
            _buildCategoryAnalysis(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final totalQuizzes = _analyticsData!['totalQuizzes'] as int;
    final averageScore = _analyticsData!['averageScore'] as double;
    final scores = _analyticsData!['scores'] as List<int>;
    
    // Calculate improvement using a more reliable method
    String improvementText = 'N/A';
    Color improvementColor = Colors.grey;
    IconData improvementIcon = Icons.trending_flat;
    
    if (scores.length >= 2) {
      // Calculate average of first 3 scores (or fewer if not available)
      final initialScoresCount = math.min(3, scores.length ~/ 2);
      final initialScores = scores.sublist(0, initialScoresCount);
      final initialAverage = initialScores.reduce((a, b) => a + b) / initialScoresCount;
      
      // Calculate average of last 3 scores (or fewer if not available)
      final recentScoresCount = math.min(3, scores.length ~/ 2);
      final recentScores = scores.sublist(scores.length - recentScoresCount);
      final recentAverage = recentScores.reduce((a, b) => a + b) / recentScoresCount;
      
      // Calculate improvement percentage
      final improvement = recentAverage - initialAverage;
      final improvementPercentage = improvement.round();
      
      if (improvementPercentage > 0) {
        improvementText = '+$improvementPercentage%';
        improvementColor = Colors.green;
        improvementIcon = Icons.trending_up;
      } else if (improvementPercentage < 0) {
        improvementText = '$improvementPercentage%';
        improvementColor = Colors.red;
        improvementIcon = Icons.trending_down;
      } else {
        improvementText = 'No change';
        improvementColor = Colors.orange;
        improvementIcon = Icons.trending_flat;
      }
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Quizzes',
          totalQuizzes.toString(),
          Icons.quiz,
          [Colors.blue.shade400, Colors.blue.shade700],
        ),
        _buildStatCard(
          'Average Score',
          '${averageScore.toStringAsFixed(1)}%',
          Icons.score,
          [Colors.purple.shade400, Colors.purple.shade700],
        ),
        _buildStatCard(
          'Best Score',
          scores.isEmpty ? 'N/A' : '${scores.reduce((a, b) => a > b ? a : b)}%',
          Icons.emoji_events,
          [Colors.amber.shade400, Colors.amber.shade700],
        ),
        _buildStatCard(
          'Improvement',
          improvementText,
          improvementIcon,
          [Colors.teal.shade400, Colors.teal.shade700],
          iconColor: improvementColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title, 
    String value, 
    IconData icon, 
    List<Color> gradient, 
    {Color? iconColor}
  ) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: iconColor ?? Colors.white,
                      size: 32 * _animation.value,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceChart() {
    final scores = _analyticsData!['scores'] as List<int>;
    if (scores.isEmpty) return const SizedBox.shrink();

    // If there's only one score, duplicate it to show a point
    final displayScores = scores.length == 1 ? [scores[0], scores[0]] : scores;
    
    // Calculate trend information
    String trendText = '';
    Color trendColor = Colors.grey;
    IconData trendIcon = Icons.trending_flat;
    
    if (scores.length >= 2) {
      final firstHalf = scores.sublist(0, scores.length ~/ 2);
      final secondHalf = scores.sublist(scores.length ~/ 2);
      
      final firstHalfAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondHalfAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
      
      final difference = secondHalfAvg - firstHalfAvg;
      
      if (difference > 5) {
        trendText = 'Improving';
        trendColor = Colors.green;
        trendIcon = Icons.trending_up;
      } else if (difference < -5) {
        trendText = 'Declining';
        trendColor = Colors.red;
        trendIcon = Icons.trending_down;
      } else {
        trendText = 'Stable';
        trendColor = Colors.orange;
        trendIcon = Icons.trending_flat;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance Trend',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (scores.isNotEmpty) Row(
                  children: [
                    if (scores.length >= 2) ...[
                      Icon(
                        trendIcon,
                        color: trendColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trendText,
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      'Latest: ${scores.last}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _getScoreColor(scores.last),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your quiz performance over time',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: PerformanceChartPainter(
                  scores: displayScores,
                  animation: _animation,
                  color: Theme.of(context).colorScheme.primary,
                  isSingleScore: scores.length == 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'First Quiz',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  'Latest Quiz',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildCategoryAnalysis() {
    final categoryAccuracy = _analyticsData!['categoryAccuracy'] as Map<String, double>;
    final categoryAttempts = _analyticsData!['categoryAttempts'] as Map<String, int>;
    if (categoryAccuracy.isEmpty) return const SizedBox.shrink();

    // Sort categories by accuracy
    final sortedEntries = categoryAccuracy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Performance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...sortedEntries.map((entry) {
          final category = entry.key;
          final accuracy = (entry.value * 100).roundToDouble();
          final attempts = categoryAttempts[category] ?? 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$attempts ${attempts == 1 ? 'quiz' : 'quizzes'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Accuracy',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '${(accuracy * _animation.value).round()}%',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getAccuracyColor(accuracy),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: accuracy / 100 * _animation.value,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(_getAccuracyColor(accuracy)),
                              minHeight: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 80) {
      return Colors.green;
    } else if (accuracy >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildRecentActivity() {
    final recentHistory = _analyticsData!['recentHistory'] as List;
    if (recentHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...recentHistory.map((quiz) {
          final score = quiz['score'] as int;
          final total = quiz['totalQuestions'] as int;
          final accuracy = (score / total * 100).round();
          
          // Get a meaningful category name
          String category = quiz['category'] as String? ?? '';
          if (category.isEmpty || category == 'Unknown') {
            // Use topic or URL quiz as fallback
            category = quiz['topic'] as String? ?? 'URL Quiz';
          }
          
          final timestamp = quiz['timestamp'] is DateTime 
              ? quiz['timestamp'] as DateTime
              : DateTime.parse(quiz['timestamp'].toString());

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getAccuracyColor(accuracy.toDouble()).withOpacity(0.2),
                  child: Text(
                    '$accuracy%',
                    style: TextStyle(
                      color: _getAccuracyColor(accuracy.toDouble()),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                title: Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Score: $score/$total • ${_formatDate(timestamp)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      accuracy >= 80 ? Icons.emoji_events : 
                      accuracy >= 60 ? Icons.thumb_up : Icons.score,
                      color: accuracy >= 80 ? Colors.amber : 
                             accuracy >= 60 ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class PerformanceChartPainter extends CustomPainter {
  final List<int> scores;
  final Animation<double> animation;
  final Color color;
  final bool isSingleScore;

  PerformanceChartPainter({
    required this.scores,
    required this.animation,
    required this.color,
    this.isSingleScore = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final width = size.width;
    final height = size.height;
    
    // Draw grid lines and labels
    _drawGrid(canvas, size);
    
    // Calculate min and max scores for better scaling
    // Use actual min score instead of fixed value, with a minimum of 0
    final maxScore = math.max(100, scores.reduce(math.max).toDouble());
    final minScore = math.max(0, scores.reduce(math.min).toDouble() - 10); // Add some padding
    final scoreRange = maxScore - minScore;
    
    final points = <Offset>[];
    
    // For single score, we'll show a point in the middle
    final horizontalStep = isSingleScore 
        ? width 
        : width / (scores.length - 1);

    for (var i = 0; i < scores.length; i++) {
      // For single score, center the point
      final x = isSingleScore 
          ? width / 2
          : i * horizontalStep;
      
      // Scale the y position based on the score range
      // Ensure we're using the full height of the chart
      final normalizedScore = scoreRange > 0 
          ? (scores[i] - minScore) / scoreRange 
          : 0.5; // Default to middle if all scores are the same
      
      final y = height - (normalizedScore * height * animation.value);
      
      points.add(Offset(x, y));
    }

    // Draw filled gradient area under the line
    if (!isSingleScore && points.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, height); // Start at the bottom left
      fillPath.lineTo(points.first.dx, points.first.dy); // Move to the first point
      
      // Add all points
      for (var i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      
      // Complete the path back to the bottom
      fillPath.lineTo(points.last.dx, height);
      fillPath.close();
      
      // Create gradient fill
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.5 * animation.value),
            color.withOpacity(0.1 * animation.value),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height));
      
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw the line with a smoother curve
    if (!isSingleScore && points.length > 1) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      
      // Use quadratic bezier curves for smoother lines
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        
        // Calculate control point for smooth curve
        final controlPointX = (p0.dx + p1.dx) / 2;
        
        path.quadraticBezierTo(
          controlPointX, p0.dy,
          p1.dx, p1.dy
        );
      }
      
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * animation.value
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      
      canvas.drawPath(path, linePaint);
    }

    // Draw dots for each data point
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      
      // Outer circle (white border)
      final outerCirclePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      // Inner circle (colored fill)
      final innerCirclePaint = Paint()
        ..color = _getScoreColor(scores[i])
        ..style = PaintingStyle.fill;
      
      // Draw the circles with animation
      final radius = isSingleScore ? 8 * animation.value : 6 * animation.value;
      canvas.drawCircle(point, radius, outerCirclePaint);
      canvas.drawCircle(point, radius * 0.7, innerCirclePaint);
      
      // Draw score label above each point
      _drawScoreLabel(canvas, point, scores[i]);
    }
  }
  
  void _drawScoreLabel(Canvas canvas, Offset point, int score) {
    final textSpan = TextSpan(
      text: '$score%',
      style: TextStyle(
        color: _getScoreColor(score),
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Position the text above the point
    final textOffset = Offset(
      point.dx - textPainter.width / 2,
      point.dy - textPainter.height - 8, // 8 pixels above the point
    );
    
    // Draw a small white background for better readability
    final bgRect = Rect.fromLTWH(
      textOffset.dx - 2,
      textOffset.dy - 2,
      textPainter.width + 4,
      textPainter.height + 4,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = Colors.white.withOpacity(0.7),
    );
    
    textPainter.paint(canvas, textOffset);
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Grid line paint
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2 * animation.value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw horizontal grid lines at 25%, 50%, 75% and 100%
    for (var i = 1; i <= 4; i++) {
      final y = height - (height * i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(width, y),
        gridPaint,
      );
      
      // Add percentage labels
      final textSpan = TextSpan(
        text: '${i * 25}%',
        style: TextStyle(
          color: Colors.grey.withOpacity(0.7 * animation.value),
          fontSize: 10,
        ),
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - textPainter.height / 2));
    }
  }
  
  Color _getScoreColor(int score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  bool shouldRepaint(covariant PerformanceChartPainter oldDelegate) {
    return oldDelegate.scores != scores ||
           oldDelegate.animation.value != animation.value ||
           oldDelegate.color != color ||
           oldDelegate.isSingleScore != isSingleScore;
  }
} 