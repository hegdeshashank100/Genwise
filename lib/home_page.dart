import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import 'user_profile_page.dart';
import 'settings_page.dart';
import 'security_page.dart';
import 'tool_resume.dart';
import 'tool_card.dart';
import 'tool_chat_pdf.dart';
import 'tool_image_story.dart';
import 'tool_poster.dart';
import 'tool_ui.dart';
import 'tool_code_explainer.dart';
import 'tool_recipe.dart';
import 'tool_lyrics.dart';
import 'tool_question_paper.dart';
import 'tool_knowledge_duel.dart';
import 'tool_image_compress.dart';
import 'tool_image_upscaler.dart';
import 'communication_practice_tool.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late AnimationController _slideshowController;
  late PageController _pageController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _userRole;
  int _currentSlideIndex = 0;

  static final List<Map<String, dynamic>> _allTools = [
    {
      'title': 'Knowledge Duel',
      'desc': 'Challenge friends with trivia questions on various topics',
      'icon': Icons.sports_esports,
      'category': 'AI Assistant',
      'color': const Color.fromARGB(255, 212, 97, 97),
      'isPopular': true,
    },
    {
      'title': 'Practice Speaking',
      'desc': 'Improve speaking skills with AI',
      'icon': Icons.record_voice_over,
      'category': 'Education',
      'color': const Color(0xFF7C3AED),
      'isPopular': true,
    },
    {
      'title': 'Resume Builder',
      'desc': 'Generate professional resumes instantly',
      'icon': Icons.description,
      'category': 'Productivity',
      'color': const Color(0xFF6366F1),
      'isPopular': true,
    },
    {
      'title': 'Chat with PDF',
      'desc': 'Upload PDF and chat with its content',
      'icon': Icons.picture_as_pdf,
      'category': 'AI Assistant',
      'color': const Color(0xFFEF4444),
      'isPopular': true,
    },
    {
      'title': 'Image-to-Story',
      'desc': 'Transform any image into stories',
      'icon': Icons.auto_stories,
      'category': 'Creative',
      'color': const Color(0xFF10B981),
      'isPopular': false,
    },
    {
      'title': 'Poster Generator',
      'desc': 'Design event posters in minutes',
      'icon': Icons.campaign,
      'category': 'Design',
      'color': const Color(0xFFF59E0B),
      'isPopular': false,
    },
    {
      'title': 'UI Designer',
      'desc': 'Professional UI with drag-and-drop simplicity',
      'icon': Icons.design_services,
      'category': 'Design',
      'color': const Color(0xFF8B5CF6),
      'isPopular': true,
    },
    {
      'title': 'Code Explainer',
      'desc': 'Understand any code, find bugs easily',
      'icon': Icons.code,
      'category': 'Development',
      'color': const Color(0xFF06B6D4),
      'isPopular': false,
    },
    {
      'title': 'Recipe Generator',
      'desc': 'Create delicious recipes based on available ingredients',
      'icon': Icons.restaurant_menu,
      'category': 'Lifestyle',
      'color': const Color(0xFFF97316),
      'isPopular': false,
    },
    {
      'title': 'Lyrics Generator',
      'desc': 'Compose original song lyrics',
      'icon': Icons.music_note,
      'category': 'Creative',
      'color': const Color(0xFFEC4899),
      'isPopular': false,
    },
    {
      'title': 'Question Paper Gen',
      'desc': 'Generate MCQs and descriptive questions of any subject',
      'icon': Icons.quiz,
      'category': 'Education',
      'color': const Color(0xFF3B82F6),
      'isPopular': false,
    },
    {
      'title': 'Image Compress',
      'desc': 'Reduce image sizes while maintaining quality',
      'icon': Icons.compress,
      'category': 'Utility',
      'color': const Color(0xFF6B7280),
      'isPopular': false,
    },
    {
      'title': 'Image Upscaler',
      'desc': 'Enhance image quality and resolution',
      'icon': Icons.high_quality,
      'category': 'Utility',
      'color': const Color(0xFF059669),
      'isPopular': false,
    },
  ];

  static final List<Widget> _pages = [
    const ToolKnowledgeDuelPage(),
    const CommunicationPracticeTool(),
    const ToolResumePage(),
    const ToolChatPDFPage(),
    const ToolImageStoryPage(),
    const ToolPosterPage(),
    const ToolUIPage(),
    const ToolCodeExplainerPage(),
    const ToolRecipePage(),
    const ToolLyricsPage(),
    const ToolQuestionPaperPage(),
    const ToolImageCompressorPage(),
    const ToolImageUpscaler(),
  ];

  List<Map<String, dynamic>> get _filteredTools {
    if (_searchQuery.isEmpty) return _allTools;
    final query = _searchQuery.toLowerCase();
    return _allTools.where((tool) {
      final title = tool['title']!.toString().toLowerCase();
      final desc = tool['desc']!.toString().toLowerCase();
      final category = tool['category']!.toString().toLowerCase();
      return title.contains(query) ||
          desc.contains(query) ||
          category.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _roleSuggestions {
    final role = _userRole ?? 'General';
    switch (role) {
      case 'Student':
        return [
          {
            'title': '🎓 Master Presentations!',
            'subtitle':
                'Practice Speaking - Build confidence for interviews & presentations',
            'color': const Color(0xFF7C3AED),
            'tool': 'Practice Speaking',
          },
          {
            'title': '📝 Study Smarter!',
            'subtitle': 'Question Paper Gen - Create mock tests for exam prep',
            'color': const Color(0xFF3B82F6),
            'tool': 'Question Paper Gen',
          },
          {
            'title': '💼 Land Your Dream Job!',
            'subtitle':
                'Resume Builder - Create professional resumes that stand out',
            'color': const Color(0xFF6366F1),
            'tool': 'Resume Builder',
          },
          {
            'title': '🧠 Understand Code Better!',
            'subtitle': 'Code Explainer - Debug and learn programming concepts',
            'color': const Color(0xFF06B6D4),
            'tool': 'Code Explainer',
          },
          {
            'title': '📚 Interactive Learning!',
            'subtitle':
                'Knowledge Duel - Test knowledge with fun AI competitions',
            'color': const Color.fromARGB(255, 212, 97, 97),
            'tool': 'Knowledge Duel',
          },
        ];
      case 'Teacher':
        return [
          {
            'title': '🏆 Gamify Learning!',
            'subtitle':
                'Knowledge Duel - Engage students with interactive AI quizzes',
            'color': const Color.fromARGB(255, 212, 97, 97),
            'tool': 'Knowledge Duel',
          },
          {
            'title': '📋 Instant Assessment!',
            'subtitle':
                'Question Paper Gen - Create tests & quizzes in seconds',
            'color': const Color(0xFF3B82F6),
            'tool': 'Question Paper Gen',
          },
          {
            'title': '🗣️ Build Student Confidence!',
            'subtitle':
                'Practice Speaking - Help students improve presentation skills',
            'color': const Color(0xFF7C3AED),
            'tool': 'Practice Speaking',
          },
          {
            'title': '💻 Teach Programming!',
            'subtitle':
                'Code Explainer - Help students understand complex code',
            'color': const Color(0xFF06B6D4),
            'tool': 'Code Explainer',
          },
          {
            'title': '📄 Student Resources!',
            'subtitle':
                'Chat with PDF - Analyze educational documents instantly',
            'color': const Color(0xFFEF4444),
            'tool': 'Chat with PDF',
          },
        ];
      case 'Content Creator':
        return [
          {
            'title': '🎨 Eye-Catching Designs!',
            'subtitle':
                'Poster Generator - Create viral-worthy visuals in minutes',
            'color': const Color(0xFFF59E0B),
            'tool': 'Poster Generator',
          },
          {
            'title': '📖 Viral Storytelling!',
            'subtitle':
                'Image-to-Story - Transform photos into engaging narratives',
            'color': const Color(0xFF10B981),
            'tool': 'Image-to-Story',
          },
          {
            'title': '🎵 Original Music Content!',
            'subtitle': 'Lyrics Generator - Write catchy songs that resonate',
            'color': const Color(0xFFEC4899),
            'tool': 'Lyrics Generator',
          },
          {
            'title': '🎯 Professional UIs!',
            'subtitle':
                'UI Designer - Create stunning interfaces for your brand',
            'color': const Color(0xFF8B5CF6),
            'tool': 'UI Designer',
          },
          {
            'title': '📱 Optimize Content!',
            'subtitle': 'Image Compress - Perfect file sizes for social media',
            'color': const Color(0xFF6B7280),
            'tool': 'Image Compress',
          },
        ];
      default:
        return [
          {
            'title': '🚀 Most Popular!',
            'subtitle':
                'Knowledge Duel - Challenge friends with AI-powered trivia',
            'color': const Color.fromARGB(255, 212, 97, 97),
            'tool': 'Knowledge Duel',
          },
          {
            'title': '💬 Chat with Documents!',
            'subtitle': 'Chat with PDF - Get instant answers from any document',
            'color': const Color(0xFFEF4444),
            'tool': 'Chat with PDF',
          },
          {
            'title': '🎯 Boost Productivity!',
            'subtitle': 'Resume Builder - Professional resumes in minutes',
            'color': const Color(0xFF6366F1),
            'tool': 'Resume Builder',
          },
          {
            'title': '🗣️ Improve Communication!',
            'subtitle':
                'Practice Speaking - Build confidence in any conversation',
            'color': const Color(0xFF7C3AED),
            'tool': 'Practice Speaking',
          },
          {
            'title': '🎨 Creative Projects!',
            'subtitle': 'Poster Generator - Design anything you can imagine',
            'color': const Color(0xFFF59E0B),
            'tool': 'Poster Generator',
          },
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    // Initialize slideshow
    _slideshowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _pageController = PageController();
    _loadUserRole();
    _startSlideshow();
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await AuthService.instance.getUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (e) {
      // Role loading failed, will use default suggestions
      print('Failed to load user role: $e');
    }
  }

  void _startSlideshow() {
    _slideshowController.addListener(() {
      if (_slideshowController.isCompleted) {
        _nextSlide();
        _slideshowController.reset();
        _slideshowController.forward();
      }
    });
    _slideshowController.forward();
  }

  void _nextSlide() {
    if (mounted) {
      setState(() {
        _currentSlideIndex = (_currentSlideIndex + 1) % _roleSuggestions.length;
      });
      _pageController.animateToPage(
        _currentSlideIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideshowController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      drawer: _buildSidebar(context),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header Section
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -50 * (1 - _slideAnimation.value)),
                  child: Opacity(
                    opacity: _slideAnimation.value,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  theme.primaryColor.withOpacity(0.8),
                                  theme.primaryColor.withOpacity(0.6),
                                  const Color(0xFF8B5CF6).withOpacity(0.8),
                                ]
                              : [
                                  theme.primaryColor,
                                  theme.primaryColor.withOpacity(0.8),
                                  const Color(0xFF8B5CF6),
                                ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isTablet ? 32 : 18,
                          20,
                          isTablet ? 32 : 18,
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopBar(theme),
                            SizedBox(height: isTablet ? 28 : 18),
                            _buildWelcomeSection(theme, isTablet),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Scrollable Content Below Header
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Search Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search AI tools...',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[500],
                              fontSize: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: theme.primaryColor,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[400],
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Role-based Suggestions Slideshow
                    if (_searchQuery.isEmpty) ...[
                      Container(
                        height: 200,
                        margin: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _roleSuggestions.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentSlideIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final suggestion = _roleSuggestions[index];
                              return GestureDetector(
                                onTap: () {
                                  // Find the tool and navigate to it
                                  final toolName = suggestion['tool'];
                                  final toolIndex = _allTools.indexWhere(
                                    (tool) => tool['title'] == toolName,
                                  );
                                  if (toolIndex != -1) {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => _pages[toolIndex],
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        suggestion['color'].withOpacity(0.9),
                                        suggestion['color'].withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                suggestion['title'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                suggestion['subtitle'],
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'Try Now →',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.auto_awesome,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // Slide indicators
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_roleSuggestions.length, (
                            index,
                          ) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentSlideIndex == index ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentSlideIndex == index
                                    ? theme.primaryColor
                                    : theme.primaryColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                    // Tools Section Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.dashboard_customize,
                            color: theme.primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'AI Tools'
                                : 'Search Results',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                              fontSize: 19,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_filteredTools.length} Tools',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tools Grid
                    AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 34 * (1 - _slideAnimation.value)),
                          child: Opacity(
                            opacity: _slideAnimation.value,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Calculate the height needed for the grid
                                final crossAxisCount = isTablet ? 3 : 2;
                                final aspectRatio = constraints.maxWidth > 600
                                    ? 0.95
                                    : 0.7;
                                final itemWidth =
                                    (constraints.maxWidth -
                                        18 * 2 -
                                        14 * (crossAxisCount - 1)) /
                                    crossAxisCount;
                                final itemHeight = itemWidth / aspectRatio;
                                final rowCount =
                                    (_filteredTools.length / crossAxisCount)
                                        .ceil();
                                final gridHeight =
                                    rowCount * itemHeight +
                                    (rowCount - 1) * 14 +
                                    20; // Add padding

                                return SizedBox(
                                  height: gridHeight,
                                  child: GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      0,
                                      18,
                                      20,
                                    ),
                                    itemCount: _filteredTools.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          mainAxisSpacing: 14,
                                          crossAxisSpacing: 14,
                                          childAspectRatio: aspectRatio,
                                        ),
                                    itemBuilder: (context, index) {
                                      final tool = _filteredTools[index];
                                      final originalIndex = _allTools.indexOf(
                                        tool,
                                      );
                                      return ToolCard(
                                        title: tool['title']!,
                                        description: tool['desc']!,
                                        icon: tool['icon'],
                                        color: tool['color'],
                                        category: tool['category']!,
                                        isPopular: tool['isPopular'],
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _pages[originalIndex],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      child: Column(
        children: [
          // Profile Header
          Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  const Color(0xFF8B5CF6),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Picture
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 35,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // User Name
                    Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        user?.email?.split('@')[0] ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Email
                    Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.email,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // View Profile Button
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const UserProfilePage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'View Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Account Details',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserProfilePage(),
                      ),
                    );
                  },
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  icon: Icons.security,
                  title: 'Security & Privacy',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SecurityPage()),
                    );
                  },
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                  isDark: isDark,
                ),

                const Divider(),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    required bool isDark,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red
            : (isDark ? Colors.grey[300] : Colors.grey[700]),
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive
              ? Colors.red
              : (isDark ? Colors.grey[200] : Colors.grey[800]),
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      minLeadingWidth: 20,
      dense: true,
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GenWise',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'AI-Powered Toolkit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.79),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 20),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            tooltip: 'Menu',
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(ThemeData theme, bool isTablet) {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17) {
      greeting = 'Good Evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: isTablet ? 25 : 21,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ready to create something amazing?',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
            fontSize: isTablet ? 15.5 : 13.8,
          ),
        ),
      ],
    );
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 12),
              Text('Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from GenWise?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Logout'),
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.instance.signOut();
              },
            ),
          ],
        );
      },
    );
  }
}
