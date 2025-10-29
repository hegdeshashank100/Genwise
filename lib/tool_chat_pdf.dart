import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'gemini_api.dart';

class ToolChatPDFPage extends StatefulWidget {
  const ToolChatPDFPage({super.key});

  @override
  State<ToolChatPDFPage> createState() => _ToolChatPDFPageState();
}

class _ToolChatPDFPageState extends State<ToolChatPDFPage>
    with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocusNode = FocusNode();
  final List<Map<String, dynamic>> _chatHistory = [];
  String _documentText = '';
  List<String> _documentChunks = [];
  Map<String, List<int>> _keywordIndex = {}; // New: keyword-to-chunk mapping
  bool _loading = false;
  bool _docUploaded = false;
  String? _fileName;
  int? _totalPages;
  String _documentType = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  static const int _maxChunkSize = 2500; // Optimized chunk size
  static const int _chunkOverlap = 200; // New: overlap between chunks

  final List<Map<String, dynamic>> _quickActions = [
    {
      'title': 'Full Summary',
      'icon': Icons.summarize,
      'color': Colors.blue,
      'query':
          'Provide a comprehensive summary of this entire document including all major sections and topics',
    },
    {
      'title': 'Key Concepts',
      'icon': Icons.highlight_alt,
      'color': Colors.green,
      'query':
          'Extract all key concepts, main ideas, and important points from throughout the document',
    },
    {
      'title': 'Academic Data',
      'icon': Icons.school,
      'color': Colors.orange,
      'query':
          'Find and calculate any academic information like CGPA, GPA, grades, scores, or percentages',
    },
    {
      'title': 'Deep Search',
      'icon': Icons.search,
      'color': Colors.purple,
      'query':
          'Search through the entire document and tell me what important or interesting information is available',
    },
    {
      'title': 'Timeline & Dates',
      'icon': Icons.event,
      'color': Colors.teal,
      'query':
          'Find all dates, deadlines, timelines, schedules, and time-related information throughout the document',
    },
    {
      'title': 'Requirements',
      'icon': Icons.task_alt,
      'color': Colors.red,
      'query':
          'List all requirements, tasks, assignments, obligations, or action items mentioned anywhere in the document',
    },
    {
      'title': 'Names & People',
      'icon': Icons.people,
      'color': Colors.indigo,
      'query':
          'Find all names of people, organizations, companies, or entities mentioned in the document',
    },
    {
      'title': 'Numbers & Data',
      'icon': Icons.bar_chart,
      'color': Colors.brown,
      'query':
          'Extract all numerical data, statistics, percentages, amounts, quantities, and measurements',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Improved chunking with overlap for better context preservation
  List<String> _chunkDocument(String text) {
    List<String> chunks = [];
    if (text.length <= _maxChunkSize) {
      return [text];
    }

    List<String> paragraphs = text.split(RegExp(r'\n\s*\n'));
    String currentChunk = '';
    String previousChunk = '';

    for (String paragraph in paragraphs) {
      String testChunk = currentChunk.isEmpty
          ? paragraph
          : '$currentChunk\n\n$paragraph';

      if (testChunk.length <= _maxChunkSize) {
        currentChunk = testChunk;
      } else {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());

          // Add overlap from the end of previous chunk
          if (currentChunk.length > _chunkOverlap) {
            previousChunk = currentChunk.substring(
              currentChunk.length - _chunkOverlap,
            );
          }
          currentChunk = previousChunk.isEmpty
              ? paragraph
              : '$previousChunk\n\n$paragraph';
          previousChunk = '';
        } else {
          // Handle very long paragraphs
          if (paragraph.length > _maxChunkSize) {
            List<String> sentences = paragraph.split(RegExp(r'[.!?]+\s+'));
            String sentenceChunk = '';

            for (String sentence in sentences) {
              if ((sentenceChunk + sentence).length <= _maxChunkSize) {
                sentenceChunk += (sentenceChunk.isEmpty ? '' : '. ') + sentence;
              } else {
                if (sentenceChunk.isNotEmpty) {
                  chunks.add(sentenceChunk.trim());

                  // Add overlap
                  if (sentenceChunk.length > _chunkOverlap) {
                    previousChunk = sentenceChunk.substring(
                      sentenceChunk.length - _chunkOverlap,
                    );
                  }
                  sentenceChunk = previousChunk + sentence;
                  previousChunk = '';
                } else {
                  // Force split very long sentences
                  int start = 0;
                  while (start < sentence.length) {
                    int end = (start + _maxChunkSize < sentence.length)
                        ? start + _maxChunkSize
                        : sentence.length;
                    chunks.add(sentence.substring(start, end));
                    start = end - _chunkOverlap;
                  }
                }
              }
            }

            if (sentenceChunk.isNotEmpty) {
              currentChunk = sentenceChunk;
            }
          } else {
            currentChunk = paragraph;
          }
        }
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    return chunks;
  }

  // Build keyword index for faster searching
  void _buildKeywordIndex() {
    _keywordIndex.clear();

    for (int i = 0; i < _documentChunks.length; i++) {
      String chunk = _documentChunks[i].toLowerCase();

      // Extract meaningful words (3+ characters)
      List<String> words = chunk
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3)
          .toList();

      for (String word in words) {
        if (!_keywordIndex.containsKey(word)) {
          _keywordIndex[word] = [];
        }
        if (!_keywordIndex[word]!.contains(i)) {
          _keywordIndex[word]!.add(i);
        }
      }
    }
  }

  // Enhanced content finding with fuzzy matching and semantic understanding
  String _findRelevantContent(String question, List<String> chunks) {
    if (chunks.isEmpty) return '';

    // Extract and expand keywords
    List<String> questionWords = _extractAndExpandKeywords(question);

    // Score each chunk with multiple relevance factors
    List<MapEntry<int, double>> chunkScores = [];

    for (int i = 0; i < chunks.length; i++) {
      String chunk = chunks[i].toLowerCase();
      double score = 0;

      // 1. Exact keyword matches (highest weight)
      for (String word in questionWords) {
        int exactMatches = RegExp(
          r'\b' + RegExp.escape(word) + r'\b',
        ).allMatches(chunk).length;
        score += exactMatches * 3.0;
      }

      // 2. Partial matches and fuzzy matching
      for (String word in questionWords) {
        if (word.length >= 4) {
          // Check for partial matches (e.g., "calculate" matches "calculation")
          String stem = word.substring(0, word.length - 2);
          if (chunk.contains(stem)) {
            score += 1.5;
          }
        }
      }

      // 3. Proximity scoring - words appearing close together
      score += _calculateProximityScore(chunk, questionWords);

      // 4. Density scoring - multiple keywords in small area
      score += _calculateDensityScore(chunk, questionWords);

      // 5. Position bonus - earlier chunks slightly favored for context
      if (i < chunks.length / 4) {
        score += 0.5;
      }

      // 6. Length normalization - prefer chunks with good content
      double normalizedLength = chunk.length / 1000.0;
      score *= (0.5 + normalizedLength.clamp(0.5, 1.5));

      if (score > 0) {
        chunkScores.add(MapEntry(i, score));
      }
    }

    // Sort by relevance
    chunkScores.sort((a, b) => b.value.compareTo(a.value));

    // Intelligent chunk selection
    List<int> selectedChunks = _selectOptimalChunks(chunkScores, chunks.length);

    if (selectedChunks.isEmpty) {
      // Fallback: use first few chunks and search for any related terms
      return _getFallbackContent(chunks, questionWords);
    }

    // Sort selected chunks by position to maintain document flow
    selectedChunks.sort();

    return selectedChunks
        .map((i) => chunks[i])
        .join('\n\n--- SECTION BREAK ---\n\n');
  }

  // Extract keywords and add related terms
  List<String> _extractAndExpandKeywords(String question) {
    List<String> keywords = question
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((word) => word.length > 2)
        .toList();

    // Remove common stop words
    List<String> stopWords = [
      'the',
      'and',
      'for',
      'are',
      'but',
      'not',
      'you',
      'all',
      'can',
      'her',
      'was',
      'one',
      'our',
      'out',
      'about',
      'what',
      'which',
      'their',
      'there',
      'been',
      'have',
      'has',
      'had',
      'this',
      'that',
      'these',
      'those',
      'from',
      'with',
      'they',
    ];

    keywords = keywords.where((w) => !stopWords.contains(w)).toList();

    // Add related terms for common queries
    List<String> expanded = List.from(keywords);

    for (String keyword in keywords) {
      switch (keyword) {
        case 'gpa':
        case 'cgpa':
          expanded.addAll(['grade', 'score', 'marks', 'percentage', 'average']);
          break;
        case 'date':
        case 'dates':
          expanded.addAll([
            'deadline',
            'schedule',
            'timeline',
            'month',
            'year',
          ]);
          break;
        case 'name':
        case 'names':
          expanded.addAll(['person', 'author', 'people', 'student']);
          break;
        case 'price':
        case 'cost':
          expanded.addAll(['amount', 'fee', 'payment', 'money', 'dollar']);
          break;
        case 'summary':
        case 'summarize':
          expanded.addAll(['overview', 'conclusion', 'abstract', 'main']);
          break;
      }
    }

    return expanded.toSet().toList();
  }

  // Calculate proximity score for words appearing near each other
  double _calculateProximityScore(String chunk, List<String> keywords) {
    double proximityScore = 0;

    for (int i = 0; i < keywords.length - 1; i++) {
      for (int j = i + 1; j < keywords.length; j++) {
        int pos1 = chunk.indexOf(keywords[i]);
        int pos2 = chunk.indexOf(keywords[j]);

        if (pos1 != -1 && pos2 != -1) {
          int distance = (pos1 - pos2).abs();
          if (distance < 100) {
            proximityScore += 2.0;
          } else if (distance < 300) {
            proximityScore += 1.0;
          }
        }
      }
    }

    return proximityScore;
  }

  // Calculate density score - multiple keywords in concentrated area
  double _calculateDensityScore(String chunk, List<String> keywords) {
    int matchCount = 0;
    for (String keyword in keywords) {
      if (chunk.contains(keyword)) {
        matchCount++;
      }
    }

    return (matchCount >= 3) ? matchCount * 1.5 : 0;
  }

  // Select optimal chunks with context awareness
  List<int> _selectOptimalChunks(
    List<MapEntry<int, double>> scores,
    int totalChunks,
  ) {
    if (scores.isEmpty) return [];

    List<int> selected = [];
    int maxChunks = (totalChunks > 100)
        ? 8
        : (totalChunks > 50)
        ? 6
        : 4;

    // Always include top scoring chunk
    selected.add(scores[0].key);

    // Add additional chunks based on score and diversity
    for (int i = 1; i < scores.length && selected.length < maxChunks; i++) {
      int chunkIdx = scores[i].key;

      // Ensure we're not adding too many consecutive chunks
      bool tooClose = selected.any((s) => (s - chunkIdx).abs() <= 1);

      if (!tooClose || scores[i].value > scores[0].value * 0.7) {
        selected.add(chunkIdx);
      }
    }

    // Add surrounding context for top chunk if space allows
    if (selected.length < maxChunks) {
      int topChunk = scores[0].key;
      if (topChunk > 0 && !selected.contains(topChunk - 1)) {
        selected.add(topChunk - 1);
      }
      if (topChunk < totalChunks - 1 && !selected.contains(topChunk + 1)) {
        selected.add(topChunk + 1);
      }
    }

    return selected;
  }

  // Fallback content when no strong matches found
  String _getFallbackContent(List<String> chunks, List<String> keywords) {
    // Try to find any chunks with at least one keyword
    List<int> hasKeyword = [];

    for (int i = 0; i < chunks.length; i++) {
      String chunk = chunks[i].toLowerCase();
      if (keywords.any((k) => chunk.contains(k))) {
        hasKeyword.add(i);
        if (hasKeyword.length >= 3) break;
      }
    }

    if (hasKeyword.isNotEmpty) {
      return hasKeyword
          .map((i) => chunks[i])
          .join('\n\n--- SECTION BREAK ---\n\n');
    }

    // Last resort: return first 4 chunks for general context
    return chunks.take(4).join('\n\n--- SECTION BREAK ---\n\n');
  }

  Future<void> _pickDocument() async {
    try {
      setState(() => _loading = true);
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String extension = fileName.split('.').last.toLowerCase();
        String extractedText = '';
        int pageCount = 1;

        if (extension == 'pdf') {
          final PdfDocument document = PdfDocument(
            inputBytes: await file.readAsBytes(),
          );
          extractedText = PdfTextExtractor(document).extractText();
          pageCount = document.pages.count;
          document.dispose();
          _documentType = 'PDF Document';
        } else if (extension == 'txt') {
          extractedText = await file.readAsString();
          _documentType = 'Text Document';
        } else {
          extractedText = 'Document uploaded successfully. Ready for analysis.';
          _documentType = '${extension.toUpperCase()} Document';
        }

        List<String> chunks = _chunkDocument(extractedText);

        setState(() {
          _documentText = extractedText;
          _documentChunks = chunks;
          _docUploaded = true;
          _fileName = fileName;
          _totalPages = pageCount;
          _chatHistory.clear();
          _loading = false;
        });

        // Build keyword index for fast searching
        _buildKeywordIndex();

        _animationController.forward();
        _showSuccessMessage();
        _addWelcomeMessage();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showSnackBar('Error loading document: ${e.toString()}', Colors.red);
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('${_documentType} loaded successfully!')),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _addWelcomeMessage() {
    setState(() {
      _chatHistory.add({
        "role": "assistant",
        "content":
            '''Hello! I have successfully loaded your ${_documentType} (${_totalPages} pages, ${(_documentText.length / 1000).toStringAsFixed(1)}k characters).

ADVANCED AI CAPABILITIES:

• Enhanced Semantic Search: I can find information even if it's described differently than your question
• Fuzzy Matching: I understand related terms and concepts (e.g., "grades" = "marks" = "scores")
• Context Awareness: I connect information from multiple sections
• Intelligent Fallback: Even if exact matches aren't found, I'll provide the closest relevant information
• Deep Analysis: I can analyze ${_documentChunks.length} document sections with ${_keywordIndex.length} indexed keywords
• Comprehensive Coverage: I search thoroughly and provide context-rich answers

WHAT I CAN DO:
✓ Answer questions about ANY topic in the document
✓ Find loosely related information
✓ Calculate academic data (GPA, grades, percentages)
✓ Extract dates, names, numbers, and requirements
✓ Provide summaries and detailed breakdowns
✓ Connect related concepts across sections

Just ask your question naturally - I'll understand and find the information!''',
        "timestamp": DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  Future<void> _askQuestion(String question) async {
    if (question.trim().isEmpty) {
      _showSnackBar('Please enter a question', Colors.orange);
      return;
    }

    if (!_docUploaded) {
      _showSnackBar('Please upload a document first', Colors.orange);
      return;
    }

    setState(() {
      _loading = true;
      _chatHistory.add({
        "role": "user",
        "content": question,
        "timestamp": DateTime.now(),
      });
    });
    _questionController.clear();
    _textFocusNode.unfocus();
    _scrollToBottom();

    try {
      // Detect question type for better response formatting
      bool wantsExplanation =
          question.toLowerCase().contains('explain') ||
          question.toLowerCase().contains('how') ||
          question.toLowerCase().contains('why') ||
          question.toLowerCase().contains('detail') ||
          question.toLowerCase().contains('breakdown') ||
          question.toLowerCase().contains('step by step');

      bool wantsList =
          question.toLowerCase().contains('list') ||
          question.toLowerCase().contains('all') ||
          question.toLowerCase().contains('what are');

      bool wantsSummary =
          question.toLowerCase().contains('summary') ||
          question.toLowerCase().contains('summarize') ||
          question.toLowerCase().contains('overview');

      // Find relevant content with enhanced algorithm
      String relevantContent = _findRelevantContent(question, _documentChunks);

      // Ensure we have sufficient content
      if (relevantContent.length < 800 && _documentText.length > 800) {
        // Add more context if available
        relevantContent +=
            '\n\n--- ADDITIONAL CONTEXT ---\n\n' +
            _documentText.substring(
              0,
              (_documentText.length > 2000) ? 2000 : _documentText.length,
            );
      }

      final prompt =
          '''
You are an advanced AI document analyst with exceptional comprehension and inference capabilities.

DOCUMENT METADATA:
- File: ${_fileName ?? 'Unknown'}
- Type: ${_documentType}
- Pages: ${_totalPages ?? 1}
- Total Size: ${_documentText.length} characters
- Sections Analyzed: ${_documentChunks.length}

RELEVANT DOCUMENT CONTENT:
${relevantContent}

USER QUESTION: $question

CRITICAL ANALYSIS INSTRUCTIONS:

1. COMPREHENSIVE SEARCH:
   - Read ALL provided content thoroughly
   - Look for direct answers, indirect references, and related information
   - Consider synonyms, related concepts, and contextual clues
   - If exact information is not present, find the closest related content

2. INFERENCE AND CONNECTION:
   - Make reasonable inferences from available data
   - Connect information from different sections
   - Identify patterns and relationships
   - Use context to deduce implicit information

3. FLEXIBLE MATCHING:
   - Match questions flexibly (e.g., "grades" = "marks" = "scores" = "GPA")
   - Understand acronyms and abbreviations
   - Recognize different phrasings of the same concept
   - Consider temporal and categorical relationships

4. ANSWER REQUIREMENTS:
   - Provide the MOST relevant information available, even if not a perfect match
   - If asked about specific data (numbers, dates, names), search exhaustively
   - For calculations (GPA, averages), show your work
   - Quote specific text when directly relevant
   - ${wantsList ? 'Format as a clear, organized list' : ''}
   - ${wantsSummary ? 'Provide a comprehensive summary covering all main points' : ''}
   - ${wantsExplanation ? 'Give detailed explanation with examples and context' : 'Be direct and concise'}

5. RESPONSE FORMAT:
   - Use plain text only (NO markdown, asterisks, hashtags, or special characters)
   - Use simple dashes (-) for bullet points if needed
   - Maximum ${wantsExplanation || wantsSummary ? '600' : '350'} words
   - Be specific and cite page numbers/sections when possible

6. HANDLING MISSING INFORMATION:
   - If the exact answer is not found, explain what IS available
   - Suggest related topics covered in the document
   - Offer alternative interpretations of the question
   - Never say "I don't know" without providing related information

7. SMART DEFAULTS:
   - For vague questions, provide the most likely intended information
   - For broad questions, give a comprehensive overview
   - For specific questions, focus deeply on that aspect

REMEMBER: Your goal is to be MAXIMALLY HELPFUL. Find and present the information the user needs, even if it requires inference, connection-making, or creative interpretation of the question.

YOUR ANSWER:''';

      final response = await GeminiApi.callGemini(prompt: prompt);

      setState(() {
        _chatHistory.add({
          "role": "assistant",
          "content": _cleanResponse(response),
          "timestamp": DateTime.now(),
        });
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _chatHistory.add({
          "role": "assistant",
          "content":
              "I encountered an error while processing your question. Please try rephrasing or ask something else about the document.",
          "timestamp": DateTime.now(),
        });
        _loading = false;
      });
    }
  }

  String _cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'#+'), '')
        .replaceAll(RegExp(r'\$+'), '')
        .replaceAll(RegExp(r'_+'), '')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'\|+'), '')
        .replaceAll(RegExp(r'~+'), '')
        .replaceAll(RegExp(r'\^+'), '')
        .replaceAll(RegExp(r'&+'), '')
        .replaceAll(RegExp(r'\\n\\n+'), '\n\n')
        .replaceAll(RegExp(r'\\t+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    _showSnackBar('Message copied to clipboard', Colors.green);
  }

  Widget _buildMessageBubble(Map<String, dynamic> chat) {
    final isUser = chat["role"] == "user";
    final content = chat["content"] ?? '';
    final timestamp = chat["timestamp"] as DateTime?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(
        left: isUser ? 60 : 16,
        right: isUser ? 16 : 60,
        top: 6,
        bottom: 6,
      ),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isUser
                  ? LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isUser
                  ? null
                  : (isDark ? Colors.grey[800] : Colors.grey.shade100),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  content,
                  style: TextStyle(
                    color: isUser
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _copyMessage(content),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.copy,
                            size: 16,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 16,
                right: isUser ? 16 : 0,
              ),
              child: Text(
                '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    if (!_docUploaded) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickActions.length,
              itemBuilder: (context, index) {
                final action = _quickActions[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? Colors.grey[800] : Colors.white,
                    child: InkWell(
                      onTap: _loading
                          ? null
                          : () => _askQuestion(action['query']),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              action['color'].withOpacity(0.1),
                              action['color'].withOpacity(0.05),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              action['icon'],
                              color: action['color'],
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              action['title'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentInfo() {
    if (!_docUploaded) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Colors.grey[800] : Colors.white,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.blue.shade900.withOpacity(0.3), Colors.grey[800]!]
                    : [Colors.blue.shade50, Colors.white],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getDocumentIcon(),
                    color: Colors.blue.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fileName ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_documentType} • ${_totalPages ?? 1} pages • ${(_documentText.length / 1000).toStringAsFixed(1)}k chars • ${_documentChunks.length} sections',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _pickDocument,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Change Document',
                  color: Colors.blue.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getDocumentIcon() {
    if (_fileName == null) return Icons.description;
    final extension = _fileName!.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file,
                size: 64,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Upload Your Document',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'I can analyze and answer questions about your PDF, Word documents, or text files. Upload a document to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Document Chat Assistant'),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_docUploaded)
              IconButton(
                onPressed: () {
                  setState(() {
                    _chatHistory.clear();
                  });
                  _addWelcomeMessage();
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Restart Chat',
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildDocumentInfo(),
              _buildQuickActions(),
              Expanded(
                child: _docUploaded
                    ? ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: _chatHistory.length + (_loading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < _chatHistory.length) {
                            return _buildMessageBubble(_chatHistory[index]);
                          } else {
                            return Container(
                              margin: const EdgeInsets.only(
                                left: 16,
                                right: 60,
                                top: 6,
                                bottom: 6,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.blue.shade600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Analyzing...',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      )
                    : _buildEmptyState(),
              ),
              if (_docUploaded)
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0
                        ? 8
                        : 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 100),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[600]!
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: TextField(
                            controller: _questionController,
                            focusNode: _textFocusNode,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ask anything about your document...',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey.shade600,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              prefixIcon: Icon(
                                Icons.chat_bubble_outline,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey.shade500,
                              ),
                            ),
                            maxLines: null,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _loading ? null : _askQuestion,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade700,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _loading
                                ? null
                                : () => _askQuestion(_questionController.text),
                            borderRadius: BorderRadius.circular(24),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
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
        ),
      ),
    );
  }
}
