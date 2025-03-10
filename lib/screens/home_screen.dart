import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'url_quiz_screen.dart';
import 'quiz_history_screen.dart';
import 'dart:ui';
import 'analytics_screen.dart';
import 'available_quizzes_screen.dart';
import 'pdf_quiz_screen.dart';
import 'profile_screen.dart';

class FootballPlayer {
  final String name;
  final String url;

  const FootballPlayer({required this.name, required this.url});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  FootballPlayer? _selectedPlayer;

  final List<FootballPlayer> footballPlayers = const [
    FootballPlayer(
      name: "Lionel Messi",
      url: "https://en.wikipedia.org/wiki/Lionel_Messi",
    ),
    FootballPlayer(
      name: "Cristiano Ronaldo",
      url: "https://en.wikipedia.org/wiki/Cristiano_Ronaldo",
    ),
    FootballPlayer(
      name: "Erling Haaland",
      url: "https://en.wikipedia.org/wiki/Erling_Haaland",
    ),
    FootballPlayer(
      name: "Kylian Mbappé",
      url: "https://en.wikipedia.org/wiki/Kylian_Mbapp%C3%A9",
    ),
    FootballPlayer(
      name: "Mohamed Salah",
      url: "https://en.wikipedia.org/wiki/Mohamed_Salah",
    ),
    FootballPlayer(
      name: "Kevin De Bruyne",
      url: "https://en.wikipedia.org/wiki/Kevin_De_Bruyne",
    ),
    FootballPlayer(
      name: "Robert Lewandowski",
      url: "https://en.wikipedia.org/wiki/Robert_Lewandowski",
    ),
    FootballPlayer(
      name: "Virgil van Dijk",
      url: "https://en.wikipedia.org/wiki/Virgil_van_Dijk",
    ),
    FootballPlayer(
      name: "Luka Modrić",
      url: "https://en.wikipedia.org/wiki/Luka_Modri%C4%87",
    ),
    FootballPlayer(
      name: "Neymar",
      url: "https://en.wikipedia.org/wiki/Neymar",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_isLoading) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  void _onPlayerSelected(FootballPlayer? player) {
    setState(() => _selectedPlayer = player);
    if (player != null) {
      _showQuizOptionsDialog(player);
    }
  }

  void _showQuizOptionsDialog(FootballPlayer player) {
    String selectedDifficulty = 'medium';
    int numQuestions = 5;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Quiz Options for ${player.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Difficulty:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      value: selectedDifficulty,
                      items: ['easy', 'medium', 'hard'].map((String difficulty) {
                        return DropdownMenuItem<String>(
                          value: difficulty,
                          child: Text(
                            difficulty[0].toUpperCase() + difficulty.substring(1),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedDifficulty = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Number of Questions:'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: numQuestions.toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: numQuestions.toString(),
                            onChanged: (double value) {
                              setState(() {
                                numQuestions = value.round();
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            numQuestions.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => URLQuizScreen(
                          initialUrl: player.url,
                          initialDifficulty: selectedDifficulty,
                          initialNumQuestions: numQuestions,
                        ),
                      ),
                    );
                  },
                  child: const Text('Generate Quiz'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Quiz App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _isLoading ? null : _signOut,
          ),
        ],
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Welcome Section with Glassmorphism
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary.withOpacity(0.8),
                            Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'avatar',
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  FirebaseAuth.instance.currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  FirebaseAuth.instance.currentUser?.email ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Football Players Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'Quick Quiz',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                          ],
                        ),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<FootballPlayer>(
                                  isExpanded: true,
                                  value: _selectedPlayer,
                                  hint: Row(
                                    children: [
                                      Icon(
                                        Icons.sports_soccer,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Select a Football Player',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  items: footballPlayers.map((player) {
                                    return DropdownMenuItem(
                                      value: player,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              color: Theme.of(context).colorScheme.primary,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            player.name,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onBackground,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _onPlayerSelected,
                                  icon: AnimatedRotation(
                                    duration: const Duration(milliseconds: 200),
                                    turns: _selectedPlayer != null ? 0.5 : 0,
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  dropdownColor: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                                  menuMaxHeight: 300,
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Quick Actions Title with Animation
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Actions Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                  children: [
                    _QuickActionButton(
                      icon: Icons.add_rounded,
                      label: 'Generate',
                      description: 'Create quiz from URL',
                      gradient: [Colors.blue.shade400, Colors.blue.shade700],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const URLQuizScreen()),
                      ),
                    ),
                    _QuickActionButton(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF Quiz',
                      description: 'Create quiz from PDF',
                      gradient: [Colors.red.shade400, Colors.red.shade700],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PDFQuizScreen()),
                      ),
                    ),
                    _QuickActionButton(
                      icon: Icons.quiz_rounded,
                      label: 'Available',
                      description: 'Select from quizzes',
                      gradient: [Colors.green.shade400, Colors.green.shade700],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AvailableQuizzesScreen()),
                      ),
                    ),
                    _QuickActionButton(
                      icon: Icons.history_rounded,
                      label: 'History',
                      description: 'View past attempts',
                      gradient: [Colors.purple.shade400, Colors.purple.shade700],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QuizHistoryScreen()),
                      ),
                    ),
                    _QuickActionButton(
                      icon: Icons.analytics_rounded,
                      label: 'Analytics',
                      description: 'Track progress',
                      gradient: [Colors.orange.shade400, Colors.orange.shade700],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                      ),
                    ),
                    _QuickActionButton(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      description: 'View your profile',
                      gradient: [Colors.teal.shade400, Colors.teal.shade700],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.gradient,
    this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.gradient.first.withOpacity(_isHovered ? 0.9 : 0.8),
                    widget.gradient.last.withOpacity(_isHovered ? 1 : 0.9),
                  ],
                ),
                boxShadow: [
                  // Base shadow
                  BoxShadow(
                    color: widget.gradient.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  // Hover glow effect
                  if (_isHovered)
                    BoxShadow(
                      color: widget.gradient.first.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.identity()
                            ..scale(_isHovered ? 1.1 : 1.0),
                          transformAlignment: Alignment.center,
                          child: Icon(
                            widget.icon,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: _isHovered ? 17 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          child: Text(widget.label),
                        ),
                        const SizedBox(height: 4),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _isHovered ? 1 : 0.8,
                          child: Text(
                            widget.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 