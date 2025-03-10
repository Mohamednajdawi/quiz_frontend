import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/quiz_result.dart';
import '../services/quiz_result_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({Key? key}) : super(key: key);

  @override
  _QuizHistoryScreenState createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> with SingleTickerProviderStateMixin {
  final QuizResultService _quizResultService = QuizResultService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late Future<List<QuizResult>> _quizHistoryFuture;
  late TabController _tabController;
  Map<String, dynamic>? _statistics;
  
  @override
  void initState() {
    super.initState();
    _quizHistoryFuture = _fetchQuizHistory();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<List<QuizResult>> _fetchQuizHistory() async {
    // Ensure the user is logged in
    if (_auth.currentUser == null) {
      return [];
    }
    
    try {
      // First, sync the user profile
      await _quizResultService.syncUserProfile();
      
      // Then get quiz history
      final response = await _quizResultService.getQuizHistory();
      
      // Extract statistics if available
      Map<String, dynamic> responseData = await _quizResultService.getRawQuizHistory();
      if (responseData.containsKey('statistics')) {
        setState(() {
          _statistics = responseData['statistics'];
        });
      }
      
      return response;
    } catch (e) {
      print('Error fetching quiz history: $e');
      return [];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Statistics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }
  
  Widget _buildHistoryTab() {
    return FutureBuilder<List<QuizResult>>(
      future: _quizHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading quiz history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _quizHistoryFuture = _fetchQuizHistory();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
        
        final quizHistory = snapshot.data ?? [];
        
        if (quizHistory.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No Quiz History Yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete some quizzes to see your history here.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: quizHistory.length,
          itemBuilder: (context, index) {
            final result = quizHistory[index];
            // Format timestamp string
            final completedDate = result.completedAt != null 
                ? DateFormat.yMMMd().add_jm().format(DateTime.parse(result.completedAt!))
                : 'Unknown date';
                
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () => _showQuizResultDetails(result.id),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              result.topicName,
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getScoreColor(result.score),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${(result.score * 100).toInt()}%',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${result.category} > ${result.subcategory}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            icon: Icons.question_answer, 
                            label: '${result.correctAnswers}/${result.totalQuestions}',
                            color: Colors.blue,
                          ),
                          if (result.timeTaken != null)
                            _buildInfoChip(
                              icon: Icons.timer,
                              label: _formatDuration(result.timeTaken!),
                              color: Colors.purple,
                            ),
                          if (result.difficultyLevel != null)
                            _buildInfoChip(
                              icon: Icons.signal_cellular_alt,
                              label: result.difficultyLevel!,
                              color: _getDifficultyColor(result.difficultyLevel!),
                            ),
                          if (result.dayOfWeek != null)
                            _buildInfoChip(
                              icon: Icons.calendar_today,
                              label: result.dayOfWeek!,
                              color: Colors.teal,
                            ),
                          if (result.timeOfDay != null)
                            _buildInfoChip(
                              icon: _getTimeIcon(result.timeOfDay!),
                              label: result.timeOfDay!,
                              color: _getTimeColor(result.timeOfDay!),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            completedDate,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildStatisticsTab() {
    return _statistics == null
        ? const Center(child: Text('No statistics available yet'))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overview',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              context,
                              'Total Quizzes',
                              '${_statistics!['total_quizzes']}',
                              Icons.quiz,
                              Colors.blue,
                            ),
                            _buildStatItem(
                              context,
                              'Avg. Score',
                              '${(_statistics!['average_score'] * 100).toInt()}%',
                              Icons.score,
                              _getScoreColor(_statistics!['average_score']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Chart for days of the week
                if (_statistics!.containsKey('quizzes_by_day') && 
                    (_statistics!['quizzes_by_day'] as Map<String, dynamic>).isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quizzes by Day of Week',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _buildDayOfWeekChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Chart for time of day
                if (_statistics!.containsKey('quizzes_by_time') && 
                    (_statistics!['quizzes_by_time'] as Map<String, dynamic>).isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quizzes by Time of Day',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _buildTimeOfDayChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Chart for difficulty level
                if (_statistics!.containsKey('quizzes_by_difficulty') && 
                    (_statistics!['quizzes_by_difficulty'] as Map<String, dynamic>).isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quizzes by Difficulty',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _buildDifficultyChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
  }
  
  Widget _buildDayOfWeekChart() {
    final dayData = _statistics!['quizzes_by_day'] as Map<String, dynamic>;
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final data = <BarChartGroupData>[];
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final value = dayData[day] ?? 0;
      data.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              color: Colors.blue,
              width: 22,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: data.map((e) => e.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.2,
        barGroups: data,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(value.toInt().toString()),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(days[value.toInt()].substring(0, 3)), // Show first 3 letters
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
  
  Widget _buildTimeOfDayChart() {
    final timeData = _statistics!['quizzes_by_time'] as Map<String, dynamic>;
    final times = ['Morning', 'Afternoon', 'Evening', 'Night'];
    final data = <PieChartSectionData>[];
    final colors = [Colors.orange, Colors.blue, Colors.purple, Colors.indigo];
    double total = 0;
    
    for (final time in times) {
      total += (timeData[time] ?? 0).toDouble();
    }
    
    for (int i = 0; i < times.length; i++) {
      final time = times[i];
      final value = (timeData[time] ?? 0).toDouble();
      if (value > 0) {
        final percentage = total > 0 ? (value / total) * 100 : 0;
        data.add(
          PieChartSectionData(
            color: colors[i],
            value: value,
            title: '${percentage.toInt()}%',
            radius: 80,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }
    
    return data.isEmpty
        ? const Center(child: Text('No time data available'))
        : PieChart(
            PieChartData(
              sections: data,
              centerSpaceRadius: 0,
              sectionsSpace: 2,
            ),
          );
  }
  
  Widget _buildDifficultyChart() {
    final difficultyData = _statistics!['quizzes_by_difficulty'] as Map<String, dynamic>;
    final difficulties = ['Easy', 'Medium', 'Hard'];
    final data = <BarChartGroupData>[];
    final colors = [Colors.green, Colors.orange, Colors.red];
    
    for (int i = 0; i < difficulties.length; i++) {
      final difficulty = difficulties[i];
      final value = difficultyData[difficulty] ?? 0;
      data.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              color: colors[i],
              width: 40,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: data.map((e) => e.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.2,
        barGroups: data,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(value.toInt().toString()),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(difficulties[value.toInt()]),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
  
  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
  
  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  
  // Get color based on score percentage
  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.blue;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }
  
  // Get color based on difficulty level
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'Hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  // Get icon based on time of day
  IconData _getTimeIcon(String timeOfDay) {
    switch (timeOfDay) {
      case 'Morning':
        return Icons.wb_sunny;
      case 'Afternoon':
        return Icons.wb_cloudy;
      case 'Evening':
        return Icons.wb_twilight;
      case 'Night':
        return Icons.nightlight_round;
      default:
        return Icons.access_time;
    }
  }
  
  // Get color based on time of day
  Color _getTimeColor(String timeOfDay) {
    switch (timeOfDay) {
      case 'Morning':
        return Colors.orange;
      case 'Afternoon':
        return Colors.blue;
      case 'Evening':
        return Colors.purple;
      case 'Night':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
  
  // Format seconds to mm:ss
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$secs';
  }
  
  // Show quiz result details
  void _showQuizResultDetails(int resultId) async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final result = await _quizResultService.getQuizResult(resultId);
      Navigator.pop(context); // Close the loading dialog
      
      // Show detailed results
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _buildQuizResultDetailsSheet(result),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close the loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading quiz details: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Widget _buildQuizResultDetailsSheet(QuizResult result) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        // Format timestamps
        final startedAt = result.startedAt != null 
            ? DateFormat.yMMMd().add_jm().format(DateTime.parse(result.startedAt!))
            : 'Unknown';
        final completedAt = result.completedAt != null 
            ? DateFormat.yMMMd().add_jm().format(DateTime.parse(result.completedAt!))
            : 'Unknown';
            
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                result.topicName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${result.category} > ${result.subcategory}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (result.dayOfWeek != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${result.dayOfWeek}, ${result.timeOfDay}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Score summary card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _scoreSummaryItem(
                            context,
                            'Score',
                            '${(result.score * 100).toInt()}%',
                            _getScoreColor(result.score),
                          ),
                          _scoreSummaryItem(
                            context,
                            'Correct',
                            '${result.correctAnswers}/${result.totalQuestions}',
                            Colors.blue,
                          ),
                          if (result.timeTaken != null)
                            _scoreSummaryItem(
                              context,
                              'Time',
                              _formatDuration(result.timeTaken!),
                              Colors.purple,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Additional metrics
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (result.difficultyLevel != null)
                            _scoreSummaryItem(
                              context, 
                              'Difficulty',
                              result.difficultyLevel!,
                              _getDifficultyColor(result.difficultyLevel!),
                            ),
                          if (result.averageTimePerQuestion != null)
                            _scoreSummaryItem(
                              context,
                              'Avg Time',
                              '${result.averageTimePerQuestion!.toStringAsFixed(1)}s',
                              Colors.teal,
                            ),
                          if (result.streak != null && result.streak! > 0)
                            _scoreSummaryItem(
                              context,
                              'Streak',
                              '${result.streak}',
                              Colors.amber,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Started: $startedAt',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Completed: $completedAt',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Quiz context notes if available
              if (result.quizContext != null && result.quizContext!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Card(
                    color: Colors.yellow[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.note, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'Notes:',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.quizContext!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
              const SizedBox(height: 16),
              Text(
                'Question Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (result.answers == null || result.answers!.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      'No detailed answer data available',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: result.answers!.length,
                    itemBuilder: (context, index) {
                      final answer = result.answers![index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: answer.isCorrect ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      answer.questionText,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Display confidence level if available
                              if (answer.confidenceLevel != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Confidence: ',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      Row(
                                        children: List.generate(5, (i) {
                                          return Icon(
                                            i < answer.confidenceLevel! ? Icons.star : Icons.star_border,
                                            color: i < answer.confidenceLevel! ? Colors.amber : Colors.grey,
                                            size: 18,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                                
                              // Display time taken if available
                              if (answer.timeTaken != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Time: ${answer.timeTaken} seconds',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              
                              const SizedBox(height: 16),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: answer.options.length,
                                itemBuilder: (context, optionIndex) {
                                  final option = answer.options[optionIndex].toString();
                                  final isCorrectOption = option == answer.correctAnswer;
                                  final isUserOption = option == answer.userAnswer;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isUserOption
                                            ? (isCorrectOption ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2))
                                            : isCorrectOption
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isUserOption
                                              ? (isCorrectOption ? Colors.green : Colors.red)
                                              : isCorrectOption
                                                  ? Colors.green
                                                  : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (isUserOption && !isCorrectOption)
                                            const Icon(Icons.close, color: Colors.red)
                                          else if (isCorrectOption)
                                            const Icon(Icons.check, color: Colors.green),
                                          if (isUserOption || isCorrectOption)
                                            const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                fontWeight: isUserOption || isCorrectOption
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isUserOption
                                                    ? (isCorrectOption ? Colors.green[800] : Colors.red[800])
                                                    : isCorrectOption
                                                        ? Colors.green[800]
                                                        : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _scoreSummaryItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
} 