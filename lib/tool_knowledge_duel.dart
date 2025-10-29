import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:io' show Platform;
import 'gemini_api.dart';

class ToolKnowledgeDuelPage extends StatefulWidget {
  const ToolKnowledgeDuelPage({super.key});
  @override
  State<ToolKnowledgeDuelPage> createState() => _ToolKnowledgeDuelPageState();
}

class DuelCharacter {
  final String name;
  final String stance;
  final String personality;
  final Color color;
  final IconData avatar;
  final String description;

  const DuelCharacter({
    required this.name,
    required this.stance,
    required this.personality,
    required this.color,
    required this.avatar,
    required this.description,
  });
}

class DuelMessage {
  final String character;
  final String message;
  final DateTime timestamp;
  final Color characterColor;
  final IconData characterAvatar;
  final int roundNumber;
  final bool isUserIntervention;
  final String? targetedCharacter;

  DuelMessage({
    required this.character,
    required this.message,
    required this.timestamp,
    required this.characterColor,
    required this.characterAvatar,
    required this.roundNumber,
    this.isUserIntervention = false,
    this.targetedCharacter,
  });
}

class _ToolKnowledgeDuelPageState extends State<ToolKnowledgeDuelPage>
    with TickerProviderStateMixin {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _interventionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _interventionFocusNode = FocusNode();

  // Voice Integration
  FlutterTts? flutterTts;
  stt.SpeechToText? speech;
  bool _speechEnabled = false;
  bool _ttsInitialized = false;

  // TTS completion management - SIMPLIFIED
  bool _isSpeaking = false;
  bool _ttsInProgress = false;

  List<DuelMessage> _duelMessages = [];
  bool _isDuelActive = false;
  bool _isGenerating = false;
  bool _isListening = false;
  bool _isProcessingIntervention = false;
  int _currentRound = 0;
  int _maxRounds = 6;
  Timer? _duelTimer;
  String? _lastUserIntervention;
  String? _targetedCharacterName;

  // Performance optimization
  bool _isAutoScrollEnabled = true;
  bool _isTTSEnabled = true;
  double _speechRate = 0.5;

  // Enhanced user feedback
  String _currentStatus = '';
  int _userInterventionCount = 0;
  DateTime? _duelStartTime;
  DateTime? _lastInterventionTime;

  DuelCharacter? _character1;
  DuelCharacter? _character2;
  String _currentSpeaker = '';

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Pre-defined battle topics
  final List<Map<String, dynamic>> _quickTopics = [
    {
      'title': 'AI in Education',
      'description': 'Should AI replace traditional teaching methods?',
      'icon': Icons.school,
      'color': Colors.blue,
    },
    {
      'title': 'Remote Work vs Office',
      'description': 'Is remote work the future or just a trend?',
      'icon': Icons.home_work,
      'color': Colors.green,
    },
    {
      'title': 'Social Media Impact',
      'description': 'Is social media helping or harming society?',
      'icon': Icons.share,
      'color': Colors.purple,
    },
    {
      'title': 'Climate Change Solutions',
      'description': 'Technology vs lifestyle changes approach',
      'icon': Icons.eco,
      'color': Colors.teal,
    },
    {
      'title': 'Cryptocurrency Future',
      'description': 'Revolutionary currency or speculative bubble?',
      'icon': Icons.currency_bitcoin,
      'color': Colors.orange,
    },
    {
      'title': 'Space Exploration',
      'description': 'Priority spending or Earth-first approach?',
      'icon': Icons.rocket_launch,
      'color': Colors.indigo,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTTS();
    _initializeSpeech();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  // SIMPLIFIED TTS initialization
  Future<void> _initializeTTS() async {
    try {
      flutterTts = FlutterTts();

      if (Platform.isAndroid) {
        await flutterTts!.setSharedInstance(true);
      }

      await flutterTts!.awaitSpeakCompletion(true);
      await flutterTts!.setLanguage("en-US");
      await flutterTts!.setSpeechRate(_speechRate);
      await flutterTts!.setVolume(0.7);
      await flutterTts!.setPitch(1.0);

      flutterTts!.setStartHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = true;
            _ttsInProgress = true;
          });
        }
      });

      flutterTts!.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _ttsInProgress = false;
          });
          // FIXED: Continue duel flow after TTS completes
          _continueDuelAfterSpeech();
        }
      });

      flutterTts!.setErrorHandler((msg) {
        print('TTS Error: $msg');
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _ttsInProgress = false;
          });
          _continueDuelAfterSpeech();
        }
        _showSnackBar('Voice error: $msg', Colors.orange);
      });

      List<dynamic> languages = await flutterTts!.getLanguages;
      if (languages.isNotEmpty) {
        _ttsInitialized = true;
        print('TTS initialized successfully');
      }
    } catch (e) {
      print('TTS initialization error: $e');
      _ttsInitialized = false;
      if (mounted) {
        _showSnackBar('Voice feature unavailable', Colors.orange);
      }
    }
  }

  // FIXED: New method to continue duel flow after TTS
  void _continueDuelAfterSpeech() {
    if (!_isDuelActive) return;

    // Wait a bit, then continue
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_isDuelActive && !_isProcessingIntervention && mounted) {
        // Switch speaker and continue
        if (_currentSpeaker == _character1!.name) {
          setState(() {
            _currentSpeaker = _character2!.name;
            _currentStatus = 'Switching to ${_character2!.name}...';
          });
        } else {
          setState(() {
            _currentSpeaker = _character1!.name;
            _currentRound++;
            _currentStatus = _currentRound <= _maxRounds
                ? 'Moving to round $_currentRound...'
                : 'Final round completed...';
          });
        }

        // Continue the duel
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (_isDuelActive && mounted) {
            setState(() => _currentStatus = '');
            _continueDuel();
          }
        });
      }
    });
  }

  Future<void> _initializeSpeech() async {
    try {
      speech = stt.SpeechToText();

      _speechEnabled = await speech!.initialize(
        onStatus: (val) {
          if (mounted && (val == 'done' || val == 'notListening')) {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          if (mounted) {
            setState(() => _isListening = false);
            _showSnackBar(
              'Speech recognition error: ${val.errorMsg}',
              Colors.red,
            );
          }
        },
      );

      if (!_speechEnabled && mounted) {
        _showSnackBar('Speech recognition not available', Colors.orange);
      }
    } catch (e) {
      _speechEnabled = false;
      if (mounted) {
        _showSnackBar('Microphone feature unavailable', Colors.orange);
      }
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _interventionController.dispose();
    _scrollController.dispose();
    _interventionFocusNode.dispose();
    _duelTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();

    if (_ttsInitialized && flutterTts != null) {
      flutterTts!.stop();
    }

    if (_speechEnabled && speech != null) {
      speech!.stop();
    }

    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_speechEnabled || speech == null) {
      _showSnackBar('Speech recognition not available', Colors.orange);
      return;
    }

    try {
      if (_isListening) {
        await speech!.stop();
        setState(() => _isListening = false);
      } else {
        setState(() => _isListening = true);

        bool available = await speech!.initialize();
        if (!available) {
          setState(() => _isListening = false);
          _showSnackBar('Speech recognition unavailable', Colors.red);
          return;
        }

        await speech!.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _interventionController.text = result.recognizedWords;
              });
            }
          },
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 2),
          partialResults: true,
          cancelOnError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isListening = false);
        _showSnackBar('Speech recognition failed', Colors.red);
      }
    }
  }

  void _generateCharacters(String topic) {
    final characters = _createOpposingCharacters(topic);
    setState(() {
      _character1 = characters[0];
      _character2 = characters[1];
    });
  }

  List<DuelCharacter> _createOpposingCharacters(String topic) {
    final characterPairs = {
      'AI in Education': [
        DuelCharacter(
          name: 'Alex',
          stance: 'AI will revolutionize education for everyone',
          personality: 'Enthusiastic tech advocate',
          color: Colors.blue,
          avatar: Icons.psychology,
          description: 'Believes AI personalizes learning perfectly',
        ),
        DuelCharacter(
          name: 'Sam',
          stance: 'Human teachers are irreplaceable in education',
          personality: 'Experienced educator',
          color: Colors.red,
          avatar: Icons.favorite,
          description: 'Champions human connection in learning',
        ),
      ],
      'Remote Work vs Office': [
        DuelCharacter(
          name: 'Maya',
          stance: 'Remote work is the future of productivity',
          personality: 'Work-life balance advocate',
          color: Colors.green,
          avatar: Icons.home,
          description: 'Proven remote work success stories',
        ),
        DuelCharacter(
          name: 'Carlos',
          stance: 'In-person collaboration drives innovation',
          personality: 'Team collaboration expert',
          color: Colors.orange,
          avatar: Icons.groups,
          description: 'Believes in face-to-face creativity',
        ),
      ],
      'Social Media Impact': [
        DuelCharacter(
          name: 'Luna',
          stance: 'Social media connects and empowers people',
          personality: 'Digital connection advocate',
          color: Colors.purple,
          avatar: Icons.share,
          description: 'Sees social media as a force for good',
        ),
        DuelCharacter(
          name: 'Max',
          stance: 'Social media harms mental health and society',
          personality: 'Digital wellness expert',
          color: Colors.red,
          avatar: Icons.warning,
          description: 'Warns about social media dangers',
        ),
      ],
      'Climate Change Solutions': [
        DuelCharacter(
          name: 'Eco',
          stance: 'Technology will solve climate change',
          personality: 'Innovation optimist',
          color: Colors.teal,
          avatar: Icons.eco,
          description: 'Believes in tech solutions',
        ),
        DuelCharacter(
          name: 'Green',
          stance: 'We need lifestyle changes, not just technology',
          personality: 'Sustainable living advocate',
          color: Colors.green,
          avatar: Icons.nature,
          description: 'Champions behavioral change',
        ),
      ],
      'Cryptocurrency Future': [
        DuelCharacter(
          name: 'Crypto',
          stance: 'Cryptocurrency is the future of money',
          personality: 'Blockchain enthusiast',
          color: Colors.orange,
          avatar: Icons.currency_bitcoin,
          description: 'Sees unlimited potential in crypto',
        ),
        DuelCharacter(
          name: 'Stable',
          stance: 'Traditional currency is more reliable',
          personality: 'Financial conservative',
          color: Colors.blue,
          avatar: Icons.account_balance,
          description: 'Prefers proven financial systems',
        ),
      ],
      'Space Exploration': [
        DuelCharacter(
          name: 'Star',
          stance: 'Space exploration is humanity\'s priority',
          personality: 'Space exploration dreamer',
          color: Colors.indigo,
          avatar: Icons.rocket_launch,
          description: 'Dreams of colonizing other planets',
        ),
        DuelCharacter(
          name: 'Earth',
          stance: 'We should fix Earth\'s problems first',
          personality: 'Earth-first advocate',
          color: Colors.brown,
          avatar: Icons.public,
          description: 'Believes in solving earthly issues first',
        ),
      ],
    };

    return characterPairs[topic] ??
        [
          DuelCharacter(
            name: 'Pro',
            stance: 'Strong supporter of the topic',
            personality: 'Passionate advocate',
            color: Colors.blue,
            avatar: Icons.thumb_up,
            description: 'Presents compelling arguments in favor',
          ),
          DuelCharacter(
            name: 'Con',
            stance: 'Critical analyst of the topic',
            personality: 'Skeptical analyst',
            color: Colors.red,
            avatar: Icons.thumb_down,
            description: 'Raises important concerns and counterpoints',
          ),
        ];
  }

  String? _parseTargetedCharacter(String input) {
    final mentionRegex = RegExp(r'@(\w+)', caseSensitive: false);
    final match = mentionRegex.firstMatch(input);
    if (match != null) {
      String mentionedName = match.group(1)!.toLowerCase();

      if (_character1?.name.toLowerCase() == mentionedName) {
        return _character1!.name;
      }
      if (_character2?.name.toLowerCase() == mentionedName) {
        return _character2!.name;
      }

      if (_character1?.name.toLowerCase().contains(mentionedName) == true) {
        return _character1!.name;
      }
      if (_character2?.name.toLowerCase().contains(mentionedName) == true) {
        return _character2!.name;
      }
    }
    return null;
  }

  String _cleanUserInput(String input) {
    return input.replaceAll(RegExp(r'@\w+\s*'), '').trim();
  }

  Future<void> _startDuel() async {
    if (_topicController.text.trim().isEmpty) {
      _showSnackBar('Please enter a debate topic!', Colors.orange);
      return;
    }

    final topic = _topicController.text.trim();
    _generateCharacters(topic);

    setState(() {
      _isDuelActive = true;
      _currentRound = 1;
      _duelMessages.clear();
      _currentSpeaker = _character1!.name;
      _lastUserIntervention = null;
      _targetedCharacterName = null;
      _userInterventionCount = 0;
      _duelStartTime = DateTime.now();
      _currentStatus = 'Battle Starting...';
      _ttsInProgress = false;
      _isProcessingIntervention = false;
    });

    _fadeController.forward();
    _addSystemMessage('🔥 BATTLE BEGINS! Topic: "$topic"');
    _addSystemMessage(
      '⚡ ${_character1!.name} (${_character1!.stance}) VS ${_character2!.name} (${_character2!.stance})',
    );
    _addSystemMessage(
      '💡 Use @${_character1!.name} or @${_character2!.name} to target specific characters!',
    );

    await Future.delayed(const Duration(milliseconds: 1000));
    _continueDuel();
  }

  Future<void> _continueDuel() async {
    if (!_isDuelActive || _currentRound > _maxRounds) {
      _endDuel();
      return;
    }

    // FIXED: Prevent multiple simultaneous calls
    if (_isGenerating || _ttsInProgress || _isProcessingIntervention) {
      print('Duel cycle already in progress, skipping...');
      return;
    }

    // Check for targeted intervention
    if (_targetedCharacterName != null && _lastUserIntervention != null) {
      setState(() {
        _currentSpeaker = _targetedCharacterName!;
        _currentStatus = 'Targeted response from $_targetedCharacterName...';
      });
    }

    setState(() {
      _isGenerating = true;
      _currentStatus = 'Generating response for $_currentSpeaker...';
    });

    _pulseController.repeat(reverse: true);

    try {
      final currentCharacter = _currentSpeaker == _character1!.name
          ? _character1!
          : _character2!;
      final opponent = _currentSpeaker == _character1!.name
          ? _character2!
          : _character1!;

      final previousMessages = _duelMessages
          .where((msg) => msg.character != 'System')
          .take(3) // Reduced context
          .map((msg) => '${msg.character}: ${msg.message}')
          .join('\n');

      final userInterventionContext = _lastUserIntervention != null
          ? '\n\nUser just said: "$_lastUserIntervention"${_targetedCharacterName != null ? ' (targeting ${currentCharacter.name})' : ''}\nAcknowledge this briefly.'
          : '';

      // FIXED: Much shorter AI responses (40-80 words)
      final prompt =
          '''
You are ${currentCharacter.name}, debating "${_topicController.text.trim()}".
Your stance: ${currentCharacter.stance}
Your personality: ${currentCharacter.personality}

Round: $_currentRound of $_maxRounds
Opponent: ${opponent.name} (${opponent.stance})

Previous conversation:
$previousMessages$userInterventionContext

Generate a SHORT, punchy argument (40-80 words max) that:
1. Stays true to your character
2. Makes ONE clear point
3. ${_lastUserIntervention != null ? 'Acknowledges the user\'s point briefly' : 'Counters opponent effectively'}
4. Uses conversational tone
5. No formatting - just natural speech

Keep it brief and impactful!
${_targetedCharacterName == currentCharacter.name ? 'Start with "Thanks for asking me about that..."' : ''}
''';

      final response = await Future.any([
        GeminiApi.callGemini(prompt: prompt),
        Future.delayed(
          const Duration(seconds: 25),
          () => throw TimeoutException(
            'AI response timeout',
            const Duration(seconds: 25),
          ),
        ),
      ]);

      final cleanedResponse = response.trim().isEmpty
          ? "That's a great point. Here's my perspective on this."
          : response.trim();

      setState(() {
        _isGenerating = false;
        _currentStatus = 'Response generated, starting TTS...';
        _duelMessages.add(
          DuelMessage(
            character: currentCharacter.name,
            message: cleanedResponse,
            timestamp: DateTime.now(),
            characterColor: currentCharacter.color,
            characterAvatar: currentCharacter.avatar,
            roundNumber: _currentRound,
            targetedCharacter: _targetedCharacterName,
          ),
        );
      });

      // FIXED: Clear intervention BEFORE TTS to prevent double responses
      if (_lastUserIntervention != null) {
        _lastUserIntervention = null;
        _targetedCharacterName = null;
      }

      _pulseController.stop();
      if (_isAutoScrollEnabled) {
        _scrollToBottom();
      }

      // Start TTS
      await _speakResponse(cleanedResponse, currentCharacter);
    } catch (e) {
      print('Error in _continueDuel: $e');
      setState(() {
        _isGenerating = false;
        _ttsInProgress = false;
        _currentStatus = 'Error occurred, retrying...';
      });
      _pulseController.stop();

      _addSystemMessage('⚠️ Connection issue - retrying shortly...');
      _showSnackBar('Retrying in 2 seconds...', Colors.orange);

      Timer(const Duration(seconds: 2), () {
        if (_isDuelActive) _continueDuel();
      });
    }
  }

  // SIMPLIFIED TTS function
  Future<void> _speakResponse(String text, DuelCharacter character) async {
    if (!_isTTSEnabled || !_ttsInitialized || flutterTts == null) {
      _continueDuelAfterSpeech();
      return;
    }

    try {
      setState(() {
        _ttsInProgress = true;
        _currentStatus = 'Speaking for ${character.name}...';
      });

      await flutterTts!.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      // Set voice characteristics
      if (character.name == _character1?.name) {
        await flutterTts!.setPitch(0.8);
        await flutterTts!.setSpeechRate(_speechRate * 0.9);
      } else if (character.name == _character2?.name) {
        await flutterTts!.setPitch(1.2);
        await flutterTts!.setSpeechRate(_speechRate * 1.1);
      } else {
        await flutterTts!.setPitch(1.0);
        await flutterTts!.setSpeechRate(_speechRate);
      }

      await flutterTts!.speak(text);
      // TTS completion handler will call _continueDuelAfterSpeech()
    } catch (e) {
      print('TTS error: $e');
      setState(() {
        _ttsInProgress = false;
        _isSpeaking = false;
      });
      _continueDuelAfterSpeech();
    }
  }

  // FIXED: Intervention with proper flow control
  Future<void> _intervene() async {
    if (_interventionController.text.trim().isEmpty) {
      _showSnackBar('Please enter your intervention point!', Colors.orange);
      return;
    }

    if (_isProcessingIntervention) {
      _showSnackBar('Already processing your intervention...', Colors.orange);
      return;
    }

    if (_lastInterventionTime != null) {
      final timeSinceLastIntervention = DateTime.now().difference(
        _lastInterventionTime!,
      );
      if (timeSinceLastIntervention.inSeconds < 3) {
        _showSnackBar(
          'Please wait ${3 - timeSinceLastIntervention.inSeconds} more seconds before intervening again',
          Colors.orange,
        );
        return;
      }
    }

    print('Starting user intervention...');
    _lastInterventionTime = DateTime.now();

    setState(() {
      _isProcessingIntervention = true;
    });

    try {
      // FIXED: Stop current TTS immediately
      if (_ttsInProgress && flutterTts != null) {
        await flutterTts!.stop();
        setState(() {
          _ttsInProgress = false;
          _isSpeaking = false;
        });
      }

      final originalInterventionText = _interventionController.text.trim();
      final targetedCharacter = _parseTargetedCharacter(
        originalInterventionText,
      );
      final cleanedInterventionText = _cleanUserInput(originalInterventionText);

      final intervention = DuelMessage(
        character: '🎤 You',
        message: originalInterventionText,
        timestamp: DateTime.now(),
        characterColor: Colors.purple,
        characterAvatar: Icons.person,
        roundNumber: _currentRound,
        isUserIntervention: true,
        targetedCharacter: targetedCharacter,
      );

      setState(() {
        _duelMessages.add(intervention);
        _lastUserIntervention = cleanedInterventionText;
        _targetedCharacterName = targetedCharacter;
        _userInterventionCount++;
        _interventionController.clear();
        _isListening = false;
        _currentStatus = targetedCharacter != null
            ? 'Your point added - $targetedCharacter will respond next'
            : 'Your point added - AI will respond next';
      });

      _interventionFocusNode.unfocus();
      FocusScope.of(context).unfocus();

      if (_isAutoScrollEnabled) {
        _scrollToBottom();
      }

      // Quick TTS feedback
      if (_isTTSEnabled && _ttsInitialized && flutterTts != null) {
        try {
          await flutterTts!.setPitch(1.0);
          await flutterTts!.setSpeechRate(_speechRate);
          await flutterTts!.speak(
            targetedCharacter != null
                ? "Got your point for $targetedCharacter!"
                : "Got your point!",
          );
        } catch (e) {
          print('TTS feedback error: $e');
        }
      }

      final feedbackMessage = targetedCharacter != null
          ? 'Great targeting! $targetedCharacter will address your point directly...'
          : 'Excellent point! AI will respond...';

      _showSnackBar(feedbackMessage, Colors.green);

      setState(() {
        _isProcessingIntervention = false;
        _currentStatus = 'Intervention received - continuing duel';
      });

      // FIXED: Wait longer before continuing to prevent issues
      await Future.delayed(const Duration(milliseconds: 1500));

      if (_isDuelActive && mounted) {
        setState(() => _currentStatus = '');
        _continueDuel();
      }
    } catch (e) {
      print('Error during intervention: $e');
      setState(() {
        _isProcessingIntervention = false;
        _ttsInProgress = false;
        _isSpeaking = false;
        _currentStatus = 'Intervention error - resuming duel';
      });
      _showSnackBar('Intervention received - continuing duel', Colors.orange);

      await Future.delayed(const Duration(milliseconds: 1000));
      if (_isDuelActive && mounted) {
        setState(() => _currentStatus = '');
        _continueDuel();
      }
    }
  }

  void _endDuel() {
    final duelDuration = _duelStartTime != null
        ? DateTime.now().difference(_duelStartTime!).inMinutes
        : 0;

    setState(() {
      _isDuelActive = false;
      _isGenerating = false;
      _currentRound = 0;
      _lastUserIntervention = null;
      _targetedCharacterName = null;
      _currentStatus = '';
      _ttsInProgress = false;
      _isProcessingIntervention = false;
    });

    _pulseController.stop();
    _duelTimer?.cancel();

    _addSystemMessage('🏆 DUEL COMPLETE! What an engaging battle of ideas!');

    if (_userInterventionCount > 0) {
      _addSystemMessage(
        '👏 Amazing! You made $_userInterventionCount intervention(s) in this ${duelDuration}min debate.',
      );
    } else {
      _addSystemMessage(
        '💡 Next time, try using @Alex or @Sam to target specific characters!',
      );
    }
  }

  void _stopDuel() {
    _duelTimer?.cancel();
    if (flutterTts != null) {
      flutterTts!.stop();
    }
    setState(() {
      _ttsInProgress = false;
      _isProcessingIntervention = false;
    });
    _endDuel();
  }

  void _emergencyReset() {
    print('EMERGENCY RESET: Clearing all stuck states');

    _duelTimer?.cancel();
    if (flutterTts != null) {
      flutterTts!.stop();
    }

    if (mounted) {
      setState(() {
        _isGenerating = false;
        _isSpeaking = false;
        _ttsInProgress = false;
        _isProcessingIntervention = false;
        _currentStatus = 'Emergency reset - resuming duel';
      });
    }

    _pulseController.stop();
    _showSnackBar(
      'System reset - duel resuming in 2 seconds...',
      Colors.orange,
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (_isDuelActive && mounted) {
        setState(() => _currentStatus = '');
        _continueDuel();
      }
    });
  }

  void _addSystemMessage(String message) {
    setState(() {
      _duelMessages.add(
        DuelMessage(
          character: 'System',
          message: message,
          timestamp: DateTime.now(),
          characterColor: Colors.grey,
          characterAvatar: Icons.info,
          roundNumber: 0,
        ),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_isAutoScrollEnabled) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyDuelTranscript() {
    final transcript = _duelMessages
        .where((msg) => msg.character != 'System')
        .map((msg) => '${msg.character}: ${msg.message}\n')
        .join('\n');

    Clipboard.setData(ClipboardData(text: transcript));
    _showSnackBar('Duel transcript copied to clipboard!', Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  Widget _buildQuickTopicCard(Map<String, dynamic> topic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _topicController.text = topic['title'],
      child: Container(
        width: 160,
        constraints: const BoxConstraints(minHeight: 120, maxHeight: 140),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: topic['color'].withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: topic['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(topic['icon'], color: topic['color'], size: 24),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                topic['title'],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                topic['description'],
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterCard(DuelCharacter character, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: character.color.withOpacity(isActive ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: character.color, width: isActive ? 3 : 2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: character.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isActive && _isGenerating ? _pulseAnimation.value : 1.0,
                child: CircleAvatar(
                  backgroundColor: character.color,
                  radius: 24,
                  child: Icon(character.avatar, color: Colors.white, size: 24),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: character.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              character.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: character.color,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              character.stance,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status indicators
          if (isActive && _targetedCharacterName == character.name) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🎯 TARGETED',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else if (isActive && _isGenerating) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(character.color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Thinking...',
              style: TextStyle(
                fontSize: 8,
                color: character.color.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (isActive && (_isSpeaking || _ttsInProgress)) ...[
            const SizedBox(height: 4),
            Icon(Icons.volume_up, color: character.color, size: 16),
            const SizedBox(height: 2),
            Text(
              'Speaking...',
              style: TextStyle(
                fontSize: 8,
                color: character.color.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (isActive && _isProcessingIntervention) ...[
            const SizedBox(height: 4),
            Icon(Icons.person_add, color: character.color, size: 16),
            const SizedBox(height: 2),
            Text(
              'User Point...',
              style: TextStyle(
                fontSize: 8,
                color: character.color.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DuelMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSystem = message.character == 'System';
    final isUser = message.isUserIntervention;
    final hasTargeting = message.targetedCharacter != null;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: message.characterColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  backgroundColor: message.characterColor,
                  radius: 16,
                  child: Icon(
                    message.characterAvatar,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: message.characterColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: message.characterColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            message.character,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: message.characterColor,
                            ),
                          ),
                        ),
                        if (message.roundNumber > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Round ${message.roundNumber}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'INTERVENTION',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (hasTargeting)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isUser
                                  ? 'TARGETED @${message.targetedCharacter}'
                                  : 'TARGETED RESPONSE',
                              style: const TextStyle(
                                fontSize: 8,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser
                  ? Colors.purple.withOpacity(0.1)
                  : hasTargeting && !isUser
                  ? Colors.orange.withOpacity(0.1)
                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUser
                    ? Colors.purple.withOpacity(0.4)
                    : hasTargeting && !isUser
                    ? Colors.orange.withOpacity(0.4)
                    : message.characterColor.withOpacity(0.3),
                width: isUser || hasTargeting ? 2 : 1,
              ),
              boxShadow: (isUser || hasTargeting)
                  ? [
                      BoxShadow(
                        color: (isUser ? Colors.purple : Colors.orange)
                            .withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: SelectableText(
              message.message,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: (isUser || hasTargeting)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🥊 AI Knowledge Duel'),
            if (_currentStatus.isNotEmpty)
              Text(
                _currentStatus,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: _isProcessingIntervention
                      ? Colors.purple
                      : _ttsInProgress
                      ? Colors.blue
                      : _isGenerating
                      ? Colors.orange
                      : null,
                ),
              ),
          ],
        ),
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'toggle_tts':
                    _isTTSEnabled = !_isTTSEnabled;
                    _showSnackBar(
                      _isTTSEnabled ? 'Voice enabled' : 'Voice disabled',
                      _isTTSEnabled ? Colors.green : Colors.grey,
                    );
                    break;
                  case 'toggle_scroll':
                    _isAutoScrollEnabled = !_isAutoScrollEnabled;
                    _showSnackBar(
                      _isAutoScrollEnabled
                          ? 'Auto-scroll enabled'
                          : 'Auto-scroll disabled',
                      _isAutoScrollEnabled ? Colors.green : Colors.grey,
                    );
                    break;
                  case 'speed_slow':
                    _speechRate = 0.3;
                    _showSnackBar('Speech rate: Slow', Colors.blue);
                    break;
                  case 'speed_normal':
                    _speechRate = 0.5;
                    _showSnackBar('Speech rate: Normal', Colors.blue);
                    break;
                  case 'speed_fast':
                    _speechRate = 0.8;
                    _showSnackBar('Speech rate: Fast', Colors.blue);
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_tts',
                child: Row(
                  children: [
                    Icon(_isTTSEnabled ? Icons.volume_up : Icons.volume_off),
                    const SizedBox(width: 12),
                    Text(_isTTSEnabled ? 'Disable Voice' : 'Enable Voice'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_scroll',
                child: Row(
                  children: [
                    Icon(
                      _isAutoScrollEnabled
                          ? Icons.vertical_align_bottom
                          : Icons.pan_tool,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isAutoScrollEnabled ? 'Manual Scroll' : 'Auto Scroll',
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'speed_slow',
                child: Row(
                  children: [
                    Icon(Icons.speed, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Slow Speech'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'speed_normal',
                child: Row(
                  children: [
                    Icon(Icons.speed, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Normal Speech'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'speed_fast',
                child: Row(
                  children: [
                    Icon(Icons.speed, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Fast Speech'),
                  ],
                ),
              ),
            ],
          ),
          if (_duelMessages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyDuelTranscript,
              tooltip: 'Copy Transcript',
            ),
          if (_isSpeaking || _ttsInProgress)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              onPressed: () async {
                if (flutterTts != null) await flutterTts!.stop();
              },
              tooltip: 'Stop Speaking',
            ),
          if (_isDuelActive)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: _stopDuel,
              tooltip: 'Stop Duel',
            ),
          if (_isDuelActive && (_isProcessingIntervention || _ttsInProgress))
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.orange),
              onPressed: _emergencyReset,
              tooltip: 'Reset if Stuck',
            ),
        ],
      ),
      // FIXED: Proper keyboard handling to prevent 21px overflow
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final screenHeight = MediaQuery.of(context).size.height;
            final appBarHeight = AppBar().preferredSize.height;
            final statusBarHeight = MediaQuery.of(context).padding.top;
            final bottomPadding = MediaQuery.of(context).padding.bottom;

            final availableHeight =
                screenHeight -
                appBarHeight -
                statusBarHeight -
                bottomPadding -
                keyboardHeight;

            return SizedBox(
              height: availableHeight,
              child: Column(
                children: [
                  // Topic Input Section (when duel is not active)
                  if (!_isDuelActive)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Your Battle Topic',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Watch AI characters debate with TTS! Use @Alex or @Sam to target specific responses.',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Quick topic selection
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _quickTopics.length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, index) {
                                return _buildQuickTopicCard(
                                  _quickTopics[index],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Custom topic input
                          Column(
                            children: [
                              TextField(
                                controller: _topicController,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'Or enter your own debate topic...',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.grey[850]
                                      : Colors.grey[100],
                                  prefixIcon: const Icon(Icons.topic),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _startDuel,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('START DUEL'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Active Duel Section (when duel is active)
                  if (_isDuelActive)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withOpacity(0.1),
                            Colors.blue.withOpacity(0.1),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'TOPIC: ${_topicController.text.trim()}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Round $_currentRound of $_maxRounds',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    // Progress bar
                                    Container(
                                      width: double.infinity,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _currentRound / _maxRounds,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Colors.blue, Colors.red],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Character cards layout
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isSmallScreen = constraints.maxWidth < 400;
                              return IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildCharacterCard(
                                        _character1!,
                                        _currentSpeaker == _character1!.name,
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 12),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department,
                                          color: Colors.orange,
                                          size: isSmallScreen ? 24 : 32,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'VS',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 14 : 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 12),
                                    Expanded(
                                      child: _buildCharacterCard(
                                        _character2!,
                                        _currentSpeaker == _character2!.name,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  // Messages List with proper flex constraints
                  Expanded(
                    child: _duelMessages.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sports_mma,
                                    size: 80,
                                    color: isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Ready for an AI Knowledge Duel?',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Pick a topic and watch two AI characters battle it out!\n\n🎤 Use @Alex or @Sam to target specific characters!\n\n🔊 Now with shorter, punchier responses!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : FadeTransition(
                            opacity: _fadeAnimation,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const ClampingScrollPhysics(),
                              itemCount: _duelMessages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageBubble(
                                  _duelMessages[index],
                                );
                              },
                            ),
                          ),
                  ),

                  // FIXED: Intervention Controls with proper keyboard handling
                  if (_isDuelActive)
                    Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: keyboardHeight > 0
                            ? 12
                            : 16, // Less padding when keyboard is open
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.05),
                        border: Border(
                          top: BorderSide(
                            color: Colors.purple.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header row - only show when keyboard is closed to save space
                          if (keyboardHeight == 0) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Colors.purple,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Add Your Point ${_character1?.name != null && _character2?.name != null ? '(@${_character1!.name} or @${_character2!.name})' : ''}',
                                    style: const TextStyle(
                                      fontSize: 14, // Smaller font
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                                if (_targetedCharacterName != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Targeting $_targetedCharacterName',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8), // Reduced spacing
                          ],
                          // Input row - FIXED: Better constraints
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: 44, // Slightly smaller
                                    maxHeight: keyboardHeight > 0
                                        ? 66
                                        : 88, // Smaller when keyboard open
                                  ),
                                  child: TextField(
                                    controller: _interventionController,
                                    focusNode: _interventionFocusNode,
                                    enabled: !_isProcessingIntervention,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 14, // Slightly smaller font
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _isListening
                                          ? 'Listening... Speak now!'
                                          : _isProcessingIntervention
                                          ? 'Processing...'
                                          : 'Type "@Alex your point" or tap mic',
                                      hintStyle: TextStyle(
                                        color: _isListening
                                            ? Colors.green
                                            : _isProcessingIntervention
                                            ? Colors.purple
                                            : (isDark
                                                  ? Colors.grey[500]
                                                  : Colors.grey[600]),
                                        fontSize: 13, // Smaller hint text
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          18,
                                        ), // Slightly smaller
                                        borderSide: BorderSide(
                                          color: _isListening
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.grey[850]
                                          : Colors.white,
                                      prefixIcon: const Icon(
                                        Icons.lightbulb_outline,
                                        color: Colors.purple,
                                        size: 20, // Smaller icon
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal:
                                                14, // Slightly smaller padding
                                            vertical: 10,
                                          ),
                                    ),
                                    maxLines: keyboardHeight > 0
                                        ? 2
                                        : 3, // Fewer lines when keyboard open
                                    minLines: 1,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _intervene(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6), // Reduced spacing
                              IconButton(
                                onPressed:
                                    (_speechEnabled &&
                                        !_isProcessingIntervention)
                                    ? _toggleListening
                                    : null,
                                icon: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  color: _isListening
                                      ? Colors.red
                                      : (_speechEnabled &&
                                                !_isProcessingIntervention
                                            ? Colors.purple
                                            : Colors.grey),
                                  size: 22, // Smaller icon
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: _isListening
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.purple.withOpacity(0.2),
                                  padding: const EdgeInsets.all(
                                    10,
                                  ), // Smaller padding
                                ),
                                tooltip: _isListening
                                    ? 'Stop Listening'
                                    : 'Start Voice Input',
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                onPressed: _isProcessingIntervention
                                    ? null
                                    : _intervene,
                                icon: _isProcessingIntervention
                                    ? const SizedBox(
                                        width: 14, // Smaller spinner
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.pan_tool,
                                        size: 16,
                                      ), // Smaller icon
                                label: Text(
                                  _isProcessingIntervention
                                      ? 'Processing...'
                                      : 'Add Point',
                                  style: const TextStyle(
                                    fontSize: 12,
                                  ), // Smaller text
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isProcessingIntervention
                                      ? Colors.grey
                                      : Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12, // Smaller padding
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
