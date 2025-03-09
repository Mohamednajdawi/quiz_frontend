import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class AvailableQuizzesScreen extends StatefulWidget {
  const AvailableQuizzesScreen({super.key});

  @override
  State<AvailableQuizzesScreen> createState() => _AvailableQuizzesScreenState();
}

class _AvailableQuizzesScreenState extends State<AvailableQuizzesScreen> {
  final _quizService = QuizService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableQuizzes = [];
  Map<String, List<String>> _categories = {};
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _error;
  Map<String, dynamic>? _selectedQuiz;
  bool _loadingQuiz = false;
  int _currentQuestionIndex = 0;
  List<int> _userAnswers = [];
  bool _showResults = false;
  bool _showAnswerDetails = false;
  final _stopwatch = Stopwatch();
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _fetchAvailableQuizzes();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await _quizService.getCategoriesAndSubcategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchAvailableQuizzes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quizzes = await _quizService.getAllAvailableQuizzes();
      setState(() {
        _availableQuizzes = quizzes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredQuizzes() {
    if (_selectedCategory == null) {
      return _availableQuizzes;
    }
    
    if (_selectedSubcategory == null) {
      return _availableQuizzes.where((quiz) => 
        quiz['category'] == _selectedCategory
      ).toList();
    }
    
    return _availableQuizzes.where((quiz) => 
      quiz['category'] == _selectedCategory && 
      quiz['subcategory'] == _selectedSubcategory
    ).toList();
  }

  Future<void> _loadQuiz(int topicId) async {
    setState(() {
      _loadingQuiz = true;
      _error = null;
    });

    try {
      final quiz = await _quizService.getQuizByTopicId(topicId);
      setState(() {
        _selectedQuiz = quiz;
        _loadingQuiz = false;
        _currentQuestionIndex = 0;
        _userAnswers = List.filled(quiz['questions'].length, -1);
        _showResults = false;
      });
      
      // Start the stopwatch
      _stopwatch.reset();
      _stopwatch.start();
      _startTime = DateTime.now();
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingQuiz = false;
      });
    }
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < (_selectedQuiz?['questions']?.length ?? 0) - 1) {
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

  void _submitQuiz() async {
    _stopwatch.stop();
    
    // Calculate score
    int score = 0;
    for (int i = 0; i < _userAnswers.length; i++) {
      // Convert letter-based right_option to numeric index (a=0, b=1, c=2, d=3)
      String rightOption = _selectedQuiz!['questions'][i]['right_option'];
      int correctIndex = rightOption.codeUnitAt(0) - 'a'.codeUnitAt(0);
      
      if (_userAnswers[i] == correctIndex) {
        score++;
      }
    }

    // Show results
    setState(() {
      _showResults = true;
    });

    // Record quiz attempt
    try {
      await _quizService.recordQuizAttempt(_selectedQuiz!['id']);
    } catch (e) {
      print('Failed to record quiz attempt: $e');
    }

    // Save results in the background
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await _quizService.saveQuizResult(
          userId: userId,
          topic: _selectedQuiz!['topic'],
          category: _selectedQuiz!['category'],
          subcategory: _selectedQuiz!['subcategory'],
          score: score,
          totalQuestions: _userAnswers.length,
          timeTaken: Duration(milliseconds: _stopwatch.elapsedMilliseconds),
        );
      } catch (e) {
        // Silently handle error
        debugPrint('Error saving quiz result: $e');
      }
    }
  }

  void _resetQuiz() {
    setState(() {
      _selectedQuiz = null;
      _currentQuestionIndex = 0;
      _userAnswers = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedQuiz != null) {
      // Show quiz questions
      return _buildQuizScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Quizzes'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchAvailableQuizzes,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Container(
                  color: Colors.black87,
                  child: Column(
                    children: [
                      // Category and subcategory filters
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filter by Category:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      inputDecorationTheme: InputDecorationTheme(
                                        filled: true,
                                        fillColor: Colors.grey.shade900,
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey.shade700),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey.shade700),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: Colors.purpleAccent),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      dropdownMenuTheme: DropdownMenuThemeData(
                                        textStyle: const TextStyle(color: Colors.white),
                                        menuStyle: MenuStyle(
                                          backgroundColor: MaterialStateProperty.all(Colors.grey.shade900),
                                        ),
                                      ),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Category',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: _selectedCategory,
                                      dropdownColor: Colors.grey.shade900,
                                      style: const TextStyle(color: Colors.white),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All Categories', style: TextStyle(color: Colors.white)),
                                        ),
                                        ..._categories.keys.map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category,
                                            child: Text(category, style: const TextStyle(color: Colors.white)),
                                          );
                                        }).toList(),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCategory = value;
                                          _selectedSubcategory = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      inputDecorationTheme: InputDecorationTheme(
                                        filled: true,
                                        fillColor: Colors.grey.shade900,
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey.shade700),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey.shade700),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: Colors.purpleAccent),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Subcategory',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: _selectedSubcategory,
                                      dropdownColor: Colors.grey.shade900,
                                      style: const TextStyle(color: Colors.white),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All Subcategories', style: TextStyle(color: Colors.white)),
                                        ),
                                        ...(_selectedCategory != null
                                            ? _categories[_selectedCategory]!.map((subcategory) {
                                                return DropdownMenuItem<String>(
                                                  value: subcategory,
                                                  child: Text(subcategory, style: const TextStyle(color: Colors.white)),
                                                );
                                              }).toList()
                                            : []),
                                      ],
                                      onChanged: _selectedCategory == null
                                          ? null
                                          : (value) {
                                              setState(() {
                                                _selectedSubcategory = value;
                                              });
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Quiz list
                      Expanded(
                        child: _getFilteredQuizzes().isEmpty
                            ? const Center(
                                child: Text(
                                  'No quizzes available for the selected filters',
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _getFilteredQuizzes().length,
                                itemBuilder: (context, index) {
                                  final quiz = _getFilteredQuizzes()[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    elevation: 4,
                                    color: Colors.grey.shade900,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () => _loadQuiz(quiz['id']),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              quiz['topic'],
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Chip(
                                                  label: Text(quiz['category']),
                                                  backgroundColor: Colors.deepPurple.shade900,
                                                  labelStyle: const TextStyle(color: Colors.white),
                                                ),
                                                const SizedBox(width: 8),
                                                Chip(
                                                  label: Text(quiz['subcategory']),
                                                  backgroundColor: Colors.deepPurple.shade800,
                                                  labelStyle: const TextStyle(color: Colors.white),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildQuizScreen() {
    if (_loadingQuiz) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_selectedQuiz!['topic']),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
          ),
        ),
        backgroundColor: Colors.black87,
      );
    }

    if (_showResults) {
      return _buildResultsScreen();
    }

    final currentQuestion = _selectedQuiz!['questions'][_currentQuestionIndex];
    final options = List<String>.from(currentQuestion['options']);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedQuiz!['topic']),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _resetQuiz,
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2), 
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
              ),
              child: LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _selectedQuiz!['questions'].length,
                backgroundColor: Colors.grey.shade800,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                minHeight: 6,
              ),
            ),
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.quiz, size: 16, color: Colors.purpleAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Q ${_currentQuestionIndex + 1}/${_selectedQuiz!['questions'].length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Colors.greenAccent),
                        const SizedBox(width: 4),
                        Text(
                          '${_userAnswers.where((a) => a != -1).length}/${_selectedQuiz!['questions'].length} answered',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade700),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${_currentQuestionIndex + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purpleAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Question',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purpleAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentQuestion['question'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Options
                    ...List.generate(
                      options.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _selectAnswer(index),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _userAnswers[_currentQuestionIndex] == index
                                  ? Colors.purpleAccent.withOpacity(0.3)
                                  : Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _userAnswers[_currentQuestionIndex] == index
                                    ? Colors.purpleAccent
                                    : Colors.grey.shade700,
                                width: 2,
                              ),
                              boxShadow: _userAnswers[_currentQuestionIndex] == index
                                  ? [
                                      BoxShadow(
                                        color: Colors.purpleAccent.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _userAnswers[_currentQuestionIndex] == index
                                        ? Colors.purpleAccent
                                        : Colors.grey.shade700,
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index), // A, B, C, D...
                                      style: TextStyle(
                                        color: _userAnswers[_currentQuestionIndex] == index
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    options[index],
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: _userAnswers[_currentQuestionIndex] == index
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (_userAnswers[_currentQuestionIndex] == index) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.purpleAccent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  if (_currentQuestionIndex == _selectedQuiz!['questions'].length - 1)
                    ElevatedButton.icon(
                      onPressed: _userAnswers.contains(-1) ? null : _submitQuiz,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade700,
                        disabledForegroundColor: Colors.grey.shade400,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _nextQuestion,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    // Calculate score
    int score = 0;
    for (int i = 0; i < _userAnswers.length; i++) {
      // Convert letter-based right_option to numeric index (a=0, b=1, c=2, d=3)
      String rightOption = _selectedQuiz!['questions'][i]['right_option'];
      int correctIndex = rightOption.codeUnitAt(0) - 'a'.codeUnitAt(0);
      
      if (_userAnswers[i] == correctIndex) {
        score++;
      }
    }

    final percentage = (score / _userAnswers.length) * 100;
    final timeTaken = _stopwatch.elapsed;
    final minutes = timeTaken.inMinutes;
    final seconds = timeTaken.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _resetQuiz,
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Score card
              Card(
                elevation: 4,
                color: Colors.grey.shade900,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        percentage >= 80
                            ? '🎉 Excellent!'
                            : percentage >= 60
                                ? '👍 Good Job!'
                                : '💪 Keep Practicing!',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$score/${_userAnswers.length} correct (${percentage.round()}%)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: percentage >= 80
                                  ? Colors.greenAccent
                                  : percentage >= 60
                                      ? Colors.orangeAccent
                                      : Colors.redAccent,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Time: $minutes:${seconds.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      if (_startTime != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Completed on: ${_startTime!.toLocal().toString().split('.')[0]}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAnswerDetails = !_showAnswerDetails;
                  });
                },
                icon: Icon(
                  _showAnswerDetails ? Icons.visibility_off : Icons.visibility,
                  size: 24,
                ),
                label: Text(
                  _showAnswerDetails ? 'Hide Answer Details' : 'Show Answer Details',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              if (_showAnswerDetails) ...[
                Text(
                  'Question Review',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  _selectedQuiz!['questions'].length,
                  (index) {
                    // Convert letter-based right_option to numeric index (a=0, b=1, c=2, d=3)
                    String rightOption = _selectedQuiz!['questions'][index]['right_option'];
                    int correctIndex = rightOption.codeUnitAt(0) - 'a'.codeUnitAt(0);
                    bool isCorrect = _userAnswers[index] == correctIndex;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
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
                                    color: isCorrect ? Colors.green.shade100 : Colors.red.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCorrect ? Icons.check_circle : Icons.cancel,
                                    color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
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
                                _selectedQuiz!['questions'][index]['question'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isCorrect ? Icons.check_circle_outline : Icons.highlight_off,
                                        color: isCorrect ? Colors.green : Colors.red,
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
                                    _userAnswers[index] >= 0 
                                        ? _selectedQuiz!['questions'][index]['options'][_userAnswers[index]] 
                                        : 'Not answered',
                                    style: TextStyle(
                                      color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
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
                                    _selectedQuiz!['questions'][index]['options'][correctIndex],
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedQuiz!['questions'][index]['explanation'] != null) ...[
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
                                      _selectedQuiz!['questions'][index]['explanation'],
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 14,
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
              
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Return to previous screen
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Back to Home'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _resetQuiz,
                child: const Text('Try Another Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 