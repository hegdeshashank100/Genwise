import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'gemini_api.dart';
import 'theme_provider.dart';

class CommunicationPracticeTool extends StatefulWidget {
  const CommunicationPracticeTool({super.key});

  @override
  State<CommunicationPracticeTool> createState() =>
      _CommunicationPracticeToolState();
}

class _CommunicationPracticeToolState extends State<CommunicationPracticeTool>
    with TickerProviderStateMixin {
  // Core Components
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  // Animation Controllers
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // State Variables
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isSpeaking = false;
  bool _isProcessingResponse = false;
  bool _isRealTimeMode = false;
  bool _autoRestartListening = true;
  bool _permissionGranted = false;
  bool _manualStop = false;
  bool _isConnected = true; // New: Connection state
  bool _apiCallInProgress = false; // New: API call tracking

  // Content Variables
  String _userSpeech = "";
  String _currentAiResponse = "";
  String _selectedMode = "Interview";
  double _confidence = 0.0;
  String _lastError = ""; // New: Track last error

  // Collections
  final List<Map<String, dynamic>> _conversationHistory = [];
  final PageController _pageController = PageController();
  Timer? _silenceTimer;
  Timer? _connectionTimer; // New: Connection check timer
  int _retryCount = 0; // New: Retry counter
  static const int maxRetries = 3; // New: Max retry attempts

  // Practice Modes Configuration
  final List<Map<String, dynamic>> _modes = [
    {
      'name': 'Interview',
      'icon': Icons.work_outline,
      'color': const Color(0xFF6366F1),
      'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      'description': 'Practice job interviews with AI feedback',
      'subtitle': 'Professional interview simulation',
      'prompt':
          '''You are an experienced HR interviewer conducting a job interview. 
Keep responses conversational and brief (1-2 sentences). 
Ask relevant follow-up questions about experience, skills, and motivations. 
Provide constructive feedback on communication style when appropriate.''',
    },
    // ... (other modes remain the same)
    {
      'name': 'Presentation',
      'icon': Icons.present_to_all,
      'color': const Color(0xFFEF4444),
      'gradient': [const Color(0xFFEF4444), const Color(0xFFDC2626)],
      'description': 'Improve public speaking and presentation skills',
      'subtitle': 'Master the art of presentation',
      'prompt':
          '''You are a presentation coach helping improve public speaking skills.
Give brief, encouraging feedback and suggestions.
Ask questions about clarity, engagement, and presentation structure.
Help build confidence in public speaking.''',
    },
    {
      'name': 'Casual Chat',
      'icon': Icons.chat_bubble_outline,
      'color': const Color(0xFF10B981),
      'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
      'description': 'Practice everyday conversations naturally',
      'subtitle': 'Natural conversation practice',
      'prompt':
          '''You are a friendly conversation partner for casual chat practice.
Respond naturally and keep the conversation flowing.
Gently correct grammar mistakes when needed.
Ask interesting questions to continue the dialogue.''',
    },
    {
      'name': 'Business Meeting',
      'icon': Icons.business_center_outlined,
      'color': const Color(0xFFF59E0B),
      'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      'description': 'Professional meeting communication',
      'subtitle': 'Corporate communication skills',
      'prompt': '''You are facilitating a professional business meeting.
Keep responses professional yet approachable.
Ask about project details, deadlines, and team collaboration.
Provide feedback on professional communication style.''',
    },
    {
      'name': 'Phone Call',
      'icon': Icons.phone_outlined,
      'color': const Color(0xFF8B5CF6),
      'gradient': [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      'description': 'Telephone communication skills',
      'subtitle': 'Master phone conversations',
      'prompt': '''You are having a professional phone conversation.
Speak clearly and ask for clarification when needed.
Practice telephone etiquette and professional phone manners.
Keep responses brief and to the point as in real phone calls.''',
    },
    {
      'name': 'Customer Service',
      'icon': Icons.support_agent,
      'color': const Color(0xFF06B6D4),
      'gradient': [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      'description': 'Customer service communication practice',
      'subtitle': 'Professional customer interactions',
      'prompt':
          '''You are a customer with various service requests or complaints.
Present different customer service scenarios.
Help practice patience, problem-solving, and professional responses.
Provide feedback on empathy and solution-oriented communication.''',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeComponents();
    _startConnectionMonitoring(); // New: Start connection monitoring
  }

  // New: Connection monitoring
  void _startConnectionMonitoring() {
    _connectionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkInternetConnection();
    });
    _checkInternetConnection(); // Initial check
  }

  // New: Check internet connection
  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  Future<void> _initializeComponents() async {
    await _initializeSpeech();
    await _initializeTts();
    _setupAnimations();
    await _checkPermissions();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _speechEnabled = false;
      _showSnackBar('Speech recognition initialization failed', Colors.orange);
    }
  }

  Future<void> _initializeTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.6);
      await _flutterTts.setVolume(1.0);

      _flutterTts.setStartHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = true);
        }
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
          _handleTtsCompletion();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        if (mounted) {
          setState(() => _isSpeaking = false);
          _showSnackBar('Text-to-speech error: $msg', Colors.orange);
        }
      });
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      _showSnackBar('Text-to-speech initialization failed', Colors.orange);
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;

    debugPrint('Speech status: $status');

    if (status == 'done' || status == 'notListening') {
      if (_isListening) {
        setState(() {
          _isListening = false;
          _animationController.stop();
          _waveController.stop();
        });

        if (_userSpeech.trim().isNotEmpty) {
          _processUserSpeech(_userSpeech);
        } else if (_autoRestartListening && !_manualStop) {
          _scheduleListeningRestart(1500); // Increased delay
        }
      }
    }
  }

  void _handleSpeechError(dynamic error) {
    if (!mounted) return;

    debugPrint('Speech error: ${error.errorMsg}');

    setState(() {
      _isListening = false;
      _animationController.stop();
      _waveController.stop();
      _lastError = 'Speech: ${error.errorMsg}';
    });

    _showSnackBar('Speech recognition error: ${error.errorMsg}', Colors.red);

    if (_autoRestartListening && !_manualStop) {
      _scheduleListeningRestart(3000); // Longer delay after error
    }
  }

  void _handleTtsCompletion() {
    if (_autoRestartListening && !_manualStop && !_isProcessingResponse) {
      _scheduleListeningRestart(1500); // Increased delay
      _showSnackBar(
        'Microphone restarted - Ready for your response',
        Colors.green,
      );
    }
  }

  void _scheduleListeningRestart(int delayMs) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_autoRestartListening &&
          !_isSpeaking &&
          !_isProcessingResponse &&
          !_manualStop &&
          !_apiCallInProgress && // New: Don't restart if API call in progress
          mounted) {
        _startListening();
      }
    });
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    setState(() {
      _permissionGranted = status.isGranted;
    });
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _connectionTimer?.cancel(); // New: Cancel connection timer
    _animationController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    _speech.cancel();
    _flutterTts.stop();
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _requestMicrophonePermission() async {
    if (_permissionGranted) return true;

    final status = await Permission.microphone.status;

    if (status.isGranted) {
      setState(() => _permissionGranted = true);
      return true;
    } else if (status.isDenied) {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        setState(() => _permissionGranted = true);
        return true;
      } else if (result.isPermanentlyDenied) {
        _showPermissionDialog();
        return false;
      }
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
      return false;
    }

    return false;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.mic_off, color: Colors.red.shade600),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Permission Required',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: const Text(
            'This app needs microphone access for speech recognition. '
            'Please enable microphone permission in your device settings.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
                await Future.delayed(const Duration(seconds: 2));
                await _checkPermissions();
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleRealTimeMode() {
    setState(() {
      _isRealTimeMode = !_isRealTimeMode;
      _autoRestartListening = true;
      _manualStop = false;
      _retryCount = 0; // Reset retry count
    });

    if (_isRealTimeMode) {
      _showSnackBar('Enhanced real-time mode activated', Colors.green);
      if (!_isListening && !_isSpeaking && !_isProcessingResponse) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _startListening();
        });
      }
    } else {
      _showSnackBar('Standard mode activated', Colors.orange);
      if (_isListening) {
        _stopListening();
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      _showSnackBar('Speech recognition not available', Colors.orange);
      return;
    }

    if (!await _requestMicrophonePermission()) return;

    // New: Check connection before starting
    if (!_isConnected) {
      await _checkInternetConnection();
      if (!_isConnected) {
        _showSnackBar(
          'No internet connection. Please check your network.',
          Colors.red,
        );
        return;
      }
    }

    setState(() {
      _isListening = true;
      _userSpeech = '';
      _confidence = 0.0;
      _manualStop = false;
      _lastError = ''; // Clear previous errors
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _userSpeech = result.recognizedWords;
              _confidence = result.confidence;
            });
          }
        },
        listenFor: Duration(seconds: _isRealTimeMode ? 8 : 30),
        pauseFor: Duration(seconds: _isRealTimeMode ? 2 : 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      // Start animations only after successful listen start
      if (_isListening) {
        _animationController.repeat(reverse: true);
        _waveController.repeat(reverse: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _lastError = 'Listen start: $e';
        });
        _animationController.stop();
        _waveController.stop();
        _showSnackBar('Error starting speech recognition: $e', Colors.red);
      }
    }
  }

  Future<void> _stopListening() async {
    setState(() => _manualStop = true);
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }

    if (mounted) {
      setState(() => _isListening = false);
      _animationController.stop();
      _waveController.stop();
    }
  }

  // Enhanced processUserSpeech with retry logic and better error handling
  Future<void> _processUserSpeech(String userInput) async {
    if (userInput.trim().isEmpty || _isProcessingResponse || _apiCallInProgress)
      return;

    setState(() {
      _isProcessingResponse = true;
      _apiCallInProgress = true;
      _lastError = '';
    });

    try {
      // Check connection before making API call
      if (!_isConnected) {
        await _checkInternetConnection();
        if (!_isConnected) {
          throw Exception('No internet connection available');
        }
      }

      final selectedModeData = _modes.firstWhere(
        (mode) => mode['name'] == _selectedMode,
        orElse: () => _modes.first,
      );

      final recentHistory = _conversationHistory.length > 4
          ? _conversationHistory.sublist(_conversationHistory.length - 4)
          : _conversationHistory;

      final conversationContext = recentHistory.isNotEmpty
          ? recentHistory
                .map((msg) => "${msg['type']}: ${msg['message']}")
                .join('\n')
          : '';

      final prompt =
          '''
${selectedModeData['prompt']}

${conversationContext.isNotEmpty ? 'Recent conversation:\n$conversationContext\n' : ''}

User just said: "$userInput"

Respond naturally and keep it brief (1-2 sentences max). Ask a follow-up question to keep the conversation flowing. Be encouraging and provide gentle feedback when appropriate.
''';

      // Call API with timeout and retry logic
      final response = await _callApiWithRetry(prompt);

      if (mounted && response.isNotEmpty) {
        setState(() {
          _currentAiResponse = response;
          _conversationHistory.add({
            'type': 'user',
            'message': userInput,
            'timestamp': DateTime.now(),
            'confidence': _confidence,
          });
          _conversationHistory.add({
            'type': 'ai',
            'message': response,
            'timestamp': DateTime.now(),
          });
          _userSpeech = '';
          _retryCount = 0; // Reset retry count on success
        });

        await _speakAIResponse(response);
      }
    } catch (e) {
      debugPrint('Processing error: $e');
      if (mounted) {
        setState(() {
          _lastError = 'API: $e';
        });

        // Provide fallback response
        final fallbackResponse = _getFallbackResponse();
        setState(() {
          _currentAiResponse = fallbackResponse;
          _conversationHistory.add({
            'type': 'user',
            'message': userInput,
            'timestamp': DateTime.now(),
            'confidence': _confidence,
          });
          _conversationHistory.add({
            'type': 'ai',
            'message': fallbackResponse,
            'timestamp': DateTime.now(),
            'isFallback': true,
          });
          _userSpeech = '';
        });

        _showSnackBar(
          'AI temporarily unavailable. Using fallback response.',
          Colors.orange,
        );
        await _speakAIResponse(fallbackResponse);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingResponse = false;
          _apiCallInProgress = false;
        });
      }
    }
  }

  // New: API call with retry logic
  Future<String> _callApiWithRetry(String prompt) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        // Add timeout to API call
        final response = await Future.any([
          GeminiApi.callGemini(prompt: prompt),
          Future.delayed(
            const Duration(seconds: 30),
            () => throw TimeoutException(
              'API timeout',
              const Duration(seconds: 30),
            ),
          ),
        ]);

        if (response.trim().isNotEmpty) {
          return response;
        } else {
          throw Exception('Empty response from API');
        }
      } catch (e) {
        debugPrint('API attempt ${attempt + 1} failed: $e');

        if (attempt == maxRetries) {
          // Last attempt failed
          rethrow;
        }

        // Wait before retry with exponential backoff
        final waitTime = Duration(seconds: (attempt + 1) * 2);
        await Future.delayed(waitTime);

        // Check connection before retry
        await _checkInternetConnection();
        if (!_isConnected) {
          throw Exception('Connection lost during retry');
        }
      }
    }
    throw Exception('All retry attempts failed');
  }

  // New: Provide fallback responses when AI fails
  String _getFallbackResponse() {
    final fallbackResponses = {
      'Interview': [
        "I understand. Could you tell me more about your experience in this area?",
        "That's interesting. What challenges have you faced in similar situations?",
        "Thank you for sharing. How would you handle a difficult situation at work?",
      ],
      'Presentation': [
        "That's a good point. How would you explain this to a different audience?",
        "Interesting perspective. Could you provide an example to illustrate that?",
        "I see. What would be the key takeaway for your audience?",
      ],
      'Casual Chat': [
        "That sounds interesting! Tell me more about that.",
        "I see what you mean. What do you think about it?",
        "That's nice to hear. How was your experience with that?",
      ],
      'Business Meeting': [
        "Thank you for that input. What are the next steps you'd recommend?",
        "That's a valid concern. How should we address this issue?",
        "Good point. What timeline are we looking at for this?",
      ],
      'Phone Call': [
        "I understand. Could you please clarify what you need help with?",
        "Thank you for calling. How can I assist you today?",
        "I see. Let me make sure I understand your request correctly.",
      ],
      'Customer Service': [
        "I appreciate your patience. How can I help resolve this for you?",
        "I understand your concern. Let me see what options we have.",
        "Thank you for bringing this to my attention. What would be your preferred solution?",
      ],
    };

    final responses =
        fallbackResponses[_selectedMode] ?? fallbackResponses['Casual Chat']!;
    final randomIndex =
        DateTime.now().millisecondsSinceEpoch % responses.length;
    return responses[randomIndex];
  }

  Future<void> _speakAIResponse(String text) async {
    if (text.trim().isEmpty) return;

    try {
      debugPrint(
        'Starting TTS for: ${text.substring(0, text.length > 50 ? 50 : text.length)}...',
      );

      await _flutterTts.stop();
      await Future.delayed(
        const Duration(milliseconds: 200),
      ); // Increased delay

      final result = await _flutterTts.speak(text);

      if (result == 1) {
        debugPrint('TTS started successfully');
      } else {
        debugPrint('TTS failed to start, result: $result');
        _showSnackBar('Text-to-speech failed to start', Colors.orange);
        // Still continue with the flow even if TTS fails
        if (mounted) {
          setState(() => _isSpeaking = false);
          _handleTtsCompletion();
        }
      }
    } catch (e) {
      debugPrint('TTS Error: $e');
      _showSnackBar('Error with text-to-speech: $e', Colors.orange);
      if (mounted) {
        setState(() => _isSpeaking = false);
        _handleTtsCompletion(); // Continue flow even if TTS fails
      }
    }
  }

  // New: Manual retry function
  Future<void> _retryLastMessage() async {
    if (_conversationHistory.isEmpty) return;

    // Find the last user message
    for (int i = _conversationHistory.length - 1; i >= 0; i--) {
      if (_conversationHistory[i]['type'] == 'user') {
        final lastUserMessage = _conversationHistory[i]['message'];

        // Remove the failed AI response if it exists
        if (i + 1 < _conversationHistory.length) {
          _conversationHistory.removeAt(i + 1);
        }

        // Retry processing
        _retryCount = 0;
        await _processUserSpeech(lastUserMessage);
        break;
      }
    }
  }

  // New: Reset app state
  void _resetAppState() {
    setState(() {
      _isListening = false;
      _isSpeaking = false;
      _isProcessingResponse = false;
      _apiCallInProgress = false;
      _manualStop = false;
      _retryCount = 0;
      _lastError = '';
      _userSpeech = '';
      _currentAiResponse = '';
    });

    _silenceTimer?.cancel();
    _animationController.stop();
    _waveController.stop();
    _flutterTts.stop();
    _speech.cancel();

    _showSnackBar('App state reset successfully', Colors.green);
  }

  void _clearConversation() {
    setState(() {
      _conversationHistory.clear();
      _userSpeech = '';
      _currentAiResponse = '';
      _confidence = 0.0;
      _lastError = '';
      _retryCount = 0;
    });
    _showSnackBar('Conversation cleared', Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                  ? Icons.error
                  : Icons.info,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(
          seconds: 4,
        ), // Longer duration for important messages
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode =
            themeProvider.themeMode == ThemeMode.dark ||
            (themeProvider.themeMode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: isDarkMode
              ? Colors.grey.shade900
              : Colors.grey.shade50,
          appBar: _buildAppBar(themeProvider, isDarkMode),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // New: Connection status indicator
                  if (!_isConnected) _buildConnectionStatusIndicator(),
                  if (_isRealTimeMode) _buildRealTimeModeIndicator(),
                  // New: Error display section
                  if (_lastError.isNotEmpty) _buildErrorSection(isDarkMode),
                  _buildModeSelector(),
                  _buildPageIndicator(),
                  const SizedBox(height: 16),
                  _buildVoiceControlSection(isDarkMode),
                  const SizedBox(height: 16),
                  _buildConversationSection(isDarkMode),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // New: Connection status indicator
  Widget _buildConnectionStatusIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.red),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text(
            'No internet connection',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _checkInternetConnection,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New: Error section
  Widget _buildErrorSection(bool isDarkMode) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.red.shade900.withOpacity(0.3)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.red.shade700 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'Last Error:',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _lastError = ''),
                child: const Text('Dismiss'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _lastError,
            style: TextStyle(color: Colors.red.shade600, fontSize: 12),
          ),
          if (_lastError.contains('API')) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _retryLastMessage,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry AI Response'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeProvider themeProvider,
    bool isDarkMode,
  ) {
    return AppBar(
      title: const Text(
        'Communication Practice',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: isDarkMode
          ? Colors.grey.shade800
          : Colors.deepPurple.shade600,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // New: Connection indicator
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: _isConnected ? Colors.white : Colors.red.shade200,
            size: 20,
          ),
        ),
        // New: Theme toggle button
        IconButton(
          icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
          tooltip: isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          onPressed: () {
            final newMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
            themeProvider.setThemeMode(newMode);
          },
        ),
        IconButton(
          icon: Icon(
            _isRealTimeMode ? Icons.auto_awesome : Icons.auto_awesome_outlined,
          ),
          tooltip: _isRealTimeMode
              ? 'Disable Enhanced Mode'
              : 'Enable Enhanced Mode',
          onPressed: _toggleRealTimeMode,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'clear':
                if (_conversationHistory.isNotEmpty) _clearConversation();
                break;
              case 'stop_speaking':
                _flutterTts.stop();
                break;
              case 'toggle_auto':
                setState(() {
                  _autoRestartListening = !_autoRestartListening;
                  _manualStop = false;
                });
                _showSnackBar(
                  _autoRestartListening
                      ? 'Auto-microphone enabled'
                      : 'Auto-microphone disabled',
                  _autoRestartListening ? Colors.green : Colors.orange,
                );
                break;
              case 'reset_state': // New: Reset app state option
                _resetAppState();
                break;
              case 'retry_api': // New: Retry API option
                _retryLastMessage();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'toggle_auto',
              child: Row(
                children: [
                  Icon(_autoRestartListening ? Icons.mic : Icons.mic_off),
                  const SizedBox(width: 8),
                  Text(
                    _autoRestartListening
                        ? 'Disable Auto-Mic'
                        : 'Enable Auto-Mic',
                  ),
                ],
              ),
            ),
            if (_lastError.contains('API'))
              const PopupMenuItem<String>(
                value: 'retry_api',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Retry AI Response'),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
              value: 'reset_state',
              child: Row(
                children: [
                  Icon(Icons.restart_alt),
                  SizedBox(width: 8),
                  Text('Reset App State'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'clear',
              enabled: _conversationHistory.isNotEmpty,
              child: const Row(
                children: [
                  Icon(Icons.clear_all),
                  SizedBox(width: 8),
                  Text('Clear Conversation'),
                ],
              ),
            ),
            if (_isSpeaking)
              const PopupMenuItem<String>(
                value: 'stop_speaking',
                child: Row(
                  children: [
                    Icon(Icons.stop),
                    SizedBox(width: 8),
                    Text('Stop Speaking'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRealTimeModeIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Enhanced mode: Auto-microphone after AI response',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SizedBox(
      height: 140,
      child: PageView.builder(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        itemCount: _modes.length,
        onPageChanged: (index) {
          setState(() {
            _selectedMode = _modes[index]['name'];
          });
        },
        itemBuilder: (context, index) {
          final mode = _modes[index];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: mode['gradient'],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: mode['color'].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              mode['icon'],
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mode['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  mode['subtitle'],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: Text(
                          mode['description'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageIndicator() {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _modes.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _selectedMode == _modes[index]['name'] ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _selectedMode == _modes[index]['name']
                  ? _modes[index]['color']
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceControlSection(bool isDarkMode) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDarkMode ? Colors.grey.shade800 : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.grey.shade800, Colors.grey.shade700]
                : [Colors.white, Colors.deepPurple.shade50],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRecordingButton(),
            const SizedBox(height: 16),
            _buildStatusText(isDarkMode),
            if (_confidence > 0) ...[
              const SizedBox(height: 12),
              _buildConfidenceIndicator(),
            ],
            if (_userSpeech.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildCurrentSpeechDisplay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingButton() {
    return GestureDetector(
      onTap: () {
        if (_isListening) {
          _stopListening();
        } else {
          setState(() => _manualStop = false);
          _startListening();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getButtonGradientColors(),
              ),
              boxShadow: [
                BoxShadow(
                  color: _getButtonShadowColor().withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(_getButtonIcon(), size: 50, color: Colors.white),
          ),
          if (_isProcessingResponse || _apiCallInProgress)
            SizedBox(
              width: 110,
              height: 110,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.deepPurple.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Color> _getButtonGradientColors() {
    if (_isListening) {
      return [Colors.red.shade400, Colors.red.shade600];
    } else if (_autoRestartListening || _isRealTimeMode) {
      return [Colors.green.shade400, Colors.green.shade600];
    } else {
      return [Colors.deepPurple.shade400, Colors.deepPurple.shade600];
    }
  }

  Color _getButtonShadowColor() {
    if (_isListening) {
      return Colors.red;
    } else if (_autoRestartListening || _isRealTimeMode) {
      return Colors.green;
    } else {
      return Colors.deepPurple;
    }
  }

  IconData _getButtonIcon() {
    if (_isListening) {
      return Icons.mic;
    } else if (_manualStop) {
      return Icons.play_arrow;
    } else {
      return Icons.mic_none;
    }
  }

  Widget _buildStatusText(bool isDarkMode) {
    String statusText;
    if (_apiCallInProgress) {
      statusText =
          'Connecting to AI... (${_retryCount > 0 ? 'Retry ${_retryCount}' : 'Please wait'})';
    } else if (_isProcessingResponse) {
      statusText = 'Processing your response...';
    } else if (_isListening) {
      statusText = 'Listening... Tap to stop';
    } else if (_isSpeaking) {
      statusText = 'AI is speaking... Mic will auto-restart';
    } else if (_manualStop) {
      statusText = 'Microphone paused - Tap to restart';
    } else if (_autoRestartListening) {
      statusText = 'Ready - Auto-microphone enabled';
    } else {
      statusText = 'Tap the microphone to start speaking';
    }

    return Text(
      statusText,
      style: TextStyle(
        fontSize: 14,
        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildConfidenceIndicator() {
    final confidencePercent = (_confidence * 100).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confidencePercent > 80
                ? Icons.signal_cellular_4_bar
                : Icons.network_cell,
            color: Colors.green.shade700,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Confidence: $confidencePercent%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSpeechDisplay() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 100),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over,
                color: Colors.blue.shade600,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'You said:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              _userSpeech,
              style: const TextStyle(fontSize: 14, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationSection(bool isDarkMode) {
    return Container(
      height: 300,
      margin: EdgeInsets.zero,
      child: Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDarkMode ? Colors.grey.shade800 : null,
        child: Column(
          children: [
            _buildConversationHeader(isDarkMode),
            Expanded(child: _buildConversationList(isDarkMode)),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.grey.shade700, Colors.grey.shade800]
              : [Colors.deepPurple.shade600, Colors.deepPurple.shade700],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversation History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_conversationHistory.isNotEmpty)
                  Text(
                    '${_conversationHistory.length ~/ 2} exchanges',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(bool isDarkMode) {
    if (_conversationHistory.isEmpty) {
      return _buildEmptyConversationState(isDarkMode);
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _conversationHistory.length,
      itemBuilder: (context, index) {
        final message = _conversationHistory[index];
        final isUser = message['type'] == 'user';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildMessageBubble(message, isUser, isDarkMode),
        );
      },
    );
  }

  Widget _buildEmptyConversationState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 60,
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to Practice!',
              style: TextStyle(
                fontSize: 20,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                _isRealTimeMode
                    ? 'Enhanced mode active.\nJust start speaking naturally!'
                    : 'Tap the microphone to begin your\n${_selectedMode.toLowerCase()} practice session',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isUser,
    bool isDarkMode,
  ) {
    final isFallback = message['isFallback'] == true;

    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: isFallback
                ? (isDarkMode
                      ? Colors.orange.shade900.withOpacity(0.3)
                      : Colors.orange.shade100)
                : (isDarkMode
                      ? Colors.deepPurple.shade800
                      : Colors.deepPurple.shade100),
            child: Icon(
              isFallback ? Icons.warning_amber : Icons.smart_toy,
              color: isFallback
                  ? Colors.orange.shade600
                  : Colors.deepPurple.shade600,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser
                  ? (isDarkMode
                        ? Colors.deepPurple.shade800.withOpacity(0.3)
                        : Colors.deepPurple.shade100)
                  : (isFallback
                        ? (isDarkMode
                              ? Colors.orange.shade900.withOpacity(0.3)
                              : Colors.orange.shade50)
                        : (isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade100)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: isFallback
                  ? Border.all(
                      color: isDarkMode
                          ? Colors.orange.shade700
                          : Colors.orange.shade200,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFallback) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 12,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Fallback response',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message['message'],
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.87)
                        : Colors.black87,
                    height: 1.3,
                  ),
                ),
                if (isUser &&
                    message['confidence'] != null &&
                    message['confidence'] > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.graphic_eq,
                        size: 12,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(message['confidence'] * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: isDarkMode
                ? Colors.deepPurple.shade700
                : Colors.deepPurple.shade600,
            child: const Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ],
      ],
    );
  }
}
