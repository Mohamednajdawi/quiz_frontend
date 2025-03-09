import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class URLQuizScreen extends StatefulWidget {
  final String? initialUrl;
  final String? initialDifficulty;
  final int? initialNumQuestions;
  
  const URLQuizScreen({
    super.key,
    this.initialUrl,
    this.initialDifficulty,
    this.initialNumQuestions,
  });

  @override
  State<URLQuizScreen> createState() => _URLQuizScreenState();
}

class _URLQuizScreenState extends State<URLQuizScreen> {
  final _urlController = TextEditingController();
  final _quizService = QuizService();
  final _stopwatch = Stopwatch();
  Map<String, dynamic>? _quizData;
  bool _isLoading = false;
  String? _error;
  int _currentQuestionIndex = 0;
  List<int> _userAnswers = [];
  bool _showResults = false;
  DateTime? _startTime;
  bool _showMoreDetails = false;
  
  // Added state variables for difficulty and number of questions
  String _selectedDifficulty = 'medium';
  int _numQuestions = 5;
  
  // List of available difficulty levels
  final List<String> _difficultyLevels = ['easy', 'medium', 'hard'];

  @override
  void initState() {
    super.initState();
    if (widget.initialDifficulty != null) {
      _selectedDifficulty = widget.initialDifficulty!;
    }
    if (widget.initialNumQuestions != null) {
      _numQuestions = widget.initialNumQuestions!;
    }
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _generateQuiz();
    }
  }

  Future<void> _generateQuiz() async {
    if (_urlController.text.isEmpty) {
      setState(() => _error = 'Please enter a URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _quizData = null;
      _showResults = false;
    });

    try {
      final quiz = await _quizService.generateQuiz(
        _urlController.text,
        numQuestions: _numQuestions,
        difficulty: _selectedDifficulty,
      );
      setState(() {
        _quizData = quiz;
        _isLoading = false;
        _currentQuestionIndex = 0;
        _userAnswers = List.filled(quiz['questions'].length, -1);
      });
      _stopwatch.reset();
      _stopwatch.start();
      _startTime = DateTime.now();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < (_quizData?['questions']?.length ?? 0) - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitQuiz() async {
    // Show results immediately
    setState(() {
      _showResults = true;
    });

    // Save results in the background
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results not saved - please sign in to save your progress')),
      );
      return;
    }

    try {
      final score = _calculateScore();
      final timeTaken = DateTime.now().difference(_startTime!);
      
      // Save complete quiz data including questions and answers
      await _quizService.saveURLQuizResult(
        userId: userId,
        quizData: {
          ..._quizData!,
          'url': _urlController.text,
          'difficulty': _selectedDifficulty,
          'num_questions': _numQuestions,
        },
        userAnswers: _userAnswers,
        score: score,
        timeTaken: timeTaken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz saved successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save quiz'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _submitQuiz,
            ),
          ),
        );
      }
    }
  }

  int _calculateScore() {
    if (_quizData == null) return 0;
    int score = 0;
    for (int i = 0; i < _quizData!['questions'].length; i++) {
      final question = _quizData!['questions'][i];
      final rightOption = question['right_option'];
      if (rightOption != null && _userAnswers[i] == _letterToIndex(rightOption)) {
        score++;
      }
    }
    return score;
  }

  String _getOptionText(int questionIndex, int optionIndex) {
    try {
      final options = _quizData?['questions']?[questionIndex]?['options'];
      if (options != null && optionIndex >= 0 && optionIndex < options.length) {
        final fullText = options[optionIndex].toString();
        return fullText.substring(fullText.indexOf('.') + 2);
      }
      return 'Option not available';
    } catch (e) {
      return 'Option not available';
    }
  }

  String _getFullOptionText(int questionIndex, int optionIndex) {
    try {
      final options = _quizData?['questions']?[questionIndex]?['options'];
      if (options != null && optionIndex >= 0 && optionIndex < options.length) {
        return options[optionIndex].toString();
      }
      return 'Option not available';
    } catch (e) {
      return 'Option not available';
    }
  }

  bool _isAnswerCorrect(int questionIndex) {
    try {
      final rightOption = _quizData?['questions']?[questionIndex]?['right_option'];
      return rightOption != null && _userAnswers[questionIndex] == _letterToIndex(rightOption);
    } catch (e) {
      return false;
    }
  }

  int _letterToIndex(String letter) {
    return letter.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
  }

  String _indexToLetter(int index) {
    return String.fromCharCode('a'.codeUnitAt(0) + index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Quiz Generator'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'Enter URL',
                          hintText: 'https://example.com',
                          errorText: _error,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Difficulty dropdown
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.trending_up),
                        ),
                        value: _selectedDifficulty,
                        items: _difficultyLevels.map((String difficulty) {
                          return DropdownMenuItem<String>(
                            value: difficulty,
                            child: Text(
                              difficulty[0].toUpperCase() + difficulty.substring(1),
                              style: const TextStyle(fontSize: 16),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedDifficulty = newValue;
                            });
                          }
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Number of questions slider
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              'Number of Questions: $_numQuestions',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Slider(
                            value: _numQuestions.toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: _numQuestions.toString(),
                            onChanged: (double value) {
                              setState(() {
                                _numQuestions = value.round();
                              });
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateQuiz,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isLoading ? 'Generating...' : 'Generate Quiz'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_quizData != null && !_showResults) ...[
                const SizedBox(height: 24),
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_quizData!['questions'].length}',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          _quizData!['questions'][_currentQuestionIndex]['question'] ?? 'Question not available',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(
                          _quizData!['questions'][_currentQuestionIndex]['options']?.length ?? 0,
                          (index) => RadioListTile(
                            title: Text(_getFullOptionText(_currentQuestionIndex, index)),
                            value: index,
                            groupValue: _userAnswers[_currentQuestionIndex],
                            onChanged: (value) => _selectAnswer(value as int),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                    if (_currentQuestionIndex == _quizData!['questions'].length - 1)
                      ElevatedButton.icon(
                        onPressed: _userAnswers.contains(-1) ? null : _submitQuiz,
                        icon: const Icon(Icons.check),
                        label: const Text('Submit'),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _currentQuestionIndex < (_quizData!['questions'].length - 1)
                            ? _nextQuestion
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
                  ],
                ),
              ],
              if (_showResults && _quizData != null) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Link Quiz Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.link_rounded,
                              color: Colors.blue.shade700,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Link Quiz Results',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        // URL
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            _urlController.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Score Circle
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _calculateScorePercentage() >= 70
                                  ? [Colors.green.shade300, Colors.green.shade700]
                                  : _calculateScorePercentage() >= 40
                                      ? [Colors.orange.shade300, Colors.orange.shade700]
                                      : [Colors.red.shade300, Colors.red.shade700],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _calculateScorePercentage() >= 70
                                    ? Colors.green.shade200
                                    : _calculateScorePercentage() >= 40
                                        ? Colors.orange.shade200
                                        : Colors.red.shade200,
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            '${_calculateScore()}/${_quizData!['questions'].length}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Percentage
                        Text(
                          '${_calculateScorePercentage().toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Performance Text
                        Text(
                          _calculateScorePercentage() >= 70
                              ? 'Excellent!'
                              : _calculateScorePercentage() >= 40
                                  ? 'Good effort!'
                                  : 'Keep practicing!',
                          style: TextStyle(
                            fontSize: 18,
                            color: _calculateScorePercentage() >= 70
                                ? Colors.green.shade700
                                : _calculateScorePercentage() >= 40
                                    ? Colors.orange.shade700
                                    : Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Time Taken
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 20, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Time: ${(_stopwatch.elapsed.inMinutes).toString().padLeft(2, '0')}:${(_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Quiz Summary Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quiz Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryItem(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: _quizData!['category'] ?? 'Web Content',
                        ),
                        _buildSummaryItem(
                          icon: Icons.topic_outlined,
                          label: 'Topic',
                          value: _quizData!['topic'] ?? 'URL Quiz',
                        ),
                        _buildSummaryItem(
                          icon: Icons.quiz_outlined,
                          label: 'Questions',
                          value: _quizData!['questions'].length.toString(),
                        ),
                        _buildSummaryItem(
                          icon: Icons.check_circle_outline,
                          label: 'Correct Answers',
                          value: _calculateScore().toString(),
                        ),
                        _buildSummaryItem(
                          icon: Icons.percent_outlined,
                          label: 'Accuracy',
                          value: '${_calculateScorePercentage().toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Show More Details Button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showMoreDetails = !_showMoreDetails;
                    });
                  },
                  icon: Icon(_showMoreDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                  label: Text(_showMoreDetails ? 'Hide Details' : 'Show More Details'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                
                // Detailed Question Analysis
                if (_showMoreDetails) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Question Analysis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(
                            _quizData!['questions'].length,
                            (index) {
                              final question = _quizData!['questions'][index];
                              final userAnswer = _userAnswers[index];
                              final correctAnswerLetter = question['right_option'];
                              final correctAnswerIndex = _letterToIndex(correctAnswerLetter);
                              final isCorrect = userAnswer == correctAnswerIndex;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isCorrect ? Colors.green.shade100 : Colors.red.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            question['question'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isCorrect ? Icons.check_circle : Icons.cancel,
                                          color: isCorrect ? Colors.green : Colors.red,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Your answer:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            userAnswer == -1 ? 'Not answered' : '${String.fromCharCode('A'.codeUnitAt(0) + userAnswer)}. ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: userAnswer == -1 ? Colors.grey.shade700 : (isCorrect ? Colors.green.shade800 : Colors.red.shade800),
                                            ),
                                          ),
                                          if (userAnswer != -1) ...[
                                            Expanded(
                                              child: Text(
                                                _getOptionText(index, userAnswer),
                                                style: TextStyle(
                                                  color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (!isCorrect) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Correct answer:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${correctAnswerLetter.toUpperCase()}. ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                _getOptionText(index, correctAnswerIndex),
                                                style: TextStyle(
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (question['explanation'] != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Explanation:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          question['explanation'],
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _quizData = null;
                            _userAnswers = [];
                            _showResults = false;
                            _showMoreDetails = false;
                            _urlController.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Start New Quiz'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.home),
                        label: const Text('Back to Home'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to calculate score percentage
  double _calculateScorePercentage() {
    if (_quizData == null || _quizData!['questions'].isEmpty) return 0;
    return (_calculateScore() / _quizData!['questions'].length) * 100;
  }
  
  // Helper method to build summary items
  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _stopwatch.stop();
    super.dispose();
  }
} 