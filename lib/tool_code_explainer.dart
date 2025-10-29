import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';

import 'gemini_api.dart';

class CodeSnippet {
  final String code;
  final String explanation;
  final int lineStart;
  final int lineEnd;

  CodeSnippet({
    required this.code,
    required this.explanation,
    required this.lineStart,
    required this.lineEnd,
  });
}

class ToolCodeExplainerPage extends StatefulWidget {
  final String initialCode;
  const ToolCodeExplainerPage({super.key, this.initialCode = ''});

  @override
  State<ToolCodeExplainerPage> createState() => _ToolCodeExplainerPageState();
}

class _ToolCodeExplainerPageState extends State<ToolCodeExplainerPage> {
  late final TextEditingController _codeController;
  List<CodeSnippet> _codeSnippets = [];
  String _overallExplanation = '';
  bool _loading = false;
  String _selectedLanguage = 'Auto-detect';
  double _progress = 0.0;
  String _progressLabel = '';

  final List<String> _languages = [
    'Auto-detect',
    'Dart',
    'Python',
    'Java',
    'JavaScript',
    'TypeScript',
    'C++',
    'C#',
    'Go',
    'Rust',
    'Swift',
    'Kotlin',
    'PHP',
    'Ruby',
    'HTML',
    'CSS',
    'SQL',
  ];

  // Chunking controls (tune for your model/quota)
  static const int maxLinesPerChunk = 60; // upper bound for per-chunk lines
  static const int minLinesPerChunk = 20; // lower bound
  static const int chunkOverlapLines = 6; // context overlap
  static const int hardMaxTotalSnippets = 120; // global cap

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Code copied to clipboard!');
  }

  Future<void> _explain() async {
    final code = _codeController.text;
    final trimmed = code.trim();
    if (trimmed.isEmpty || trimmed == '// Paste your code here...') {
      _showSnackBar('Please enter some code to explain', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _progress = 0;
      _progressLabel = 'Preparing chunks...';
      _codeSnippets.clear();
      _overallExplanation = '';
    });

    try {
      // 1) Pre-chunk long code deterministically
      final lines = code.split('\n');
      final chunks = _smartChunk(lines);

      // 2) For each chunk, request structured JSON snippets
      final allSnippets = <CodeSnippet>[];
      for (int i = 0; i < chunks.length; i++) {
        final c = chunks[i];
        setState(() {
          _progress = (i / max(1, chunks.length));
          _progressLabel = 'Analyzing chunk ${i + 1}/${chunks.length}';
        });

        final prompt = _buildChunkPrompt(
          languageHint: _selectedLanguage,
          chunkText: c.text,
          globalStartLine: c.startLine,
        );

        String res = await GeminiApi.callGemini(prompt: prompt);

        final parsed = _parseSnippetsJson(
          res,
          fallbackLines: c.text.split('\n'),
          globalStart: c.startLine,
        );
        allSnippets.addAll(parsed);

        if (allSnippets.length > hardMaxTotalSnippets) break;
      }

      // De-duplicate and sort by line
      final dedup = _dedupeAndSort(allSnippets);

      // 3) Ask model for a single overall summary using only code + snippet heads
      setState(() {
        _progress = 0.98;
        _progressLabel = 'Synthesizing overall explanation...';
      });

      final summaryPrompt = _buildSummaryPrompt(
        _selectedLanguage,
        lines,
        dedup.take(30).toList(),
      );
      final summaryRes = await GeminiApi.callGemini(prompt: summaryPrompt);
      final summary = _extractPlain(summaryRes);

      setState(() {
        _overallExplanation = summary.isEmpty
            ? 'This code defines and organizes logic across multiple functions and structures. See the step-by-step breakdown below.'
            : summary;
        _codeSnippets = dedup;
        _progress = 1.0;
        _progressLabel = 'Done';
      });
    } catch (e) {
      // 4) Fallback: client-side chunking + heuristic explanations
      await _fallbackClientSideExplain();
      _showSnackBar(
        'Used local fallback explainer due to an error.',
        isError: false,
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Smart semantic chunk
  List<_Chunk> _smartChunk(List<String> lines) {
    final n = lines.length;
    if (n <= maxLinesPerChunk) {
      return [_Chunk(text: lines.join('\n'), startLine: 1, endLine: n)];
    }

    final chunks = <_Chunk>[];
    int i = 0;
    while (i < n) {
      int targetEnd = min(i + maxLinesPerChunk, n);
      int bestBreak = _findSemanticBreak(lines, i, targetEnd);
      int start = i;
      int end = bestBreak;

      // Ensure minimum size
      if (end - start < minLinesPerChunk && end < n) {
        end = min(n, start + minLinesPerChunk);
      }

      final startLine = start + 1; // 1-based
      final endLine = end;

      final segment = lines.sublist(start, end).join('\n');
      chunks.add(_Chunk(text: segment, startLine: startLine, endLine: endLine));

      // Overlap to keep context
      i = max(end - chunkOverlapLines, end);
    }

    return chunks;
  }

  // Prefer to break at function/class/import/blank lines near boundary
  int _findSemanticBreak(List<String> lines, int start, int targetEnd) {
    int end = targetEnd;

    // Search backwards from targetEnd for a clean boundary
    for (int k = targetEnd; k > start + minLinesPerChunk; k--) {
      final s = lines[k - 1].trim();
      if (s.isEmpty ||
          s.startsWith('class ') ||
          s.startsWith('struct ') ||
          s.startsWith('interface ') ||
          s.startsWith('def ') ||
          s.startsWith('function ') ||
          s.startsWith('void ') ||
          s.contains(
            RegExp(r'^\w+\s*\(.*\)\s*\{?\s*$'),
          ) || // foo(...) {   or foo(...)
          s.startsWith('import ') ||
          s.startsWith('#include') ||
          s.startsWith('using ') ||
          s.startsWith('final ') ||
          s.endsWith('};')) {
        end = k;
        break;
      }
    }
    return end;
  }

  String _buildChunkPrompt({
    required String languageHint,
    required String chunkText,
    required int globalStartLine,
  }) {
    final lh = languageHint != 'Auto-detect'
        ? 'This is $languageHint code. '
        : '';
    return '''
${lh}Break this code chunk into multiple small, meaningful snippets and return STRICT JSON only.

CHUNK_START_LINE: $globalStartLine

CODE_CHUNK:
<<<CODE_BEGIN>>>
$chunkText
<<<CODE_END>>>

Return ONLY this JSON (no markdown, no prose):

{
  "snippets": [
    {
      "code": "the exact code lines for this snippet",
      "explanation": "what it does, why it's needed, and how it works, in simple terms",
      "line_start": <absolute_line_number_in_original_file>,
      "line_end": <absolute_line_number_in_original_file>
    }
  ]
}

Rules:
- Aim for 3-10 snippets per chunk, each ~3-12 lines; never return a single giant snippet.
- Map line_start and line_end to absolute lines using CHUNK_START_LINE + local offsets.
- Cover all important logic; prefer splitting by functions, classes, conditionals, loops, and setup blocks.
- Keep explanations concise but educational; avoid repeating the full code in explanations.
- Output valid JSON only.
''';
  }

  String _buildSummaryPrompt(
    String languageHint,
    List<String> allLines,
    List<CodeSnippet> preview,
  ) {
    final lh = languageHint != 'Auto-detect'
        ? 'This is $languageHint code. '
        : '';
    final head = allLines.take(120).join('\n');
    final previewBullets = preview
        .map(
          (s) =>
              '- Lines ${s.lineStart}-${s.lineEnd}: ${s.explanation.replaceAll('\n', ' ')}',
        )
        .join('\n');

    return '''
${lh}Provide a brief overall explanation of the entire codebase. Be concise, high level, and avoid repeating snippet-level details.

REFERENCE (first 120 lines):
<<<CODE_HEAD>>>
$head
<<<END>>>

PREVIEW OF SNIPPETS:
$previewBullets

Return only plain text (no JSON, no markdown).
''';
  }

  List<CodeSnippet> _parseSnippetsJson(
    String response, {
    required List<String> fallbackLines,
    required int globalStart,
  }) {
    final text = _extractPlain(response);
    Map<String, dynamic>? jsonMap;

    try {
      jsonMap = json.decode(text);
    } catch (_) {
      // Try to salvage: find first/last braces
      final i = text.indexOf('{');
      final j = text.lastIndexOf('}');
      if (i >= 0 && j > i) {
        final maybe = text.substring(i, j + 1);
        try {
          jsonMap = json.decode(maybe);
        } catch (_) {}
      }
    }

    if (jsonMap == null || jsonMap['snippets'] == null) {
      // Local fallback split for this chunk
      return _localSplitFallback(fallbackLines, globalStart);
    }

    final list = (jsonMap['snippets'] as List)
        .whereType<Map<String, dynamic>>()
        .map((m) {
          final code = (m['code'] ?? '').toString();
          final explanation = (m['explanation'] ?? '').toString();
          final ls = (m['line_start'] is int)
              ? m['line_start'] as int
              : int.tryParse('${m['line_start'] ?? ''}') ?? globalStart;
          final le = (m['line_end'] is int)
              ? m['line_end'] as int
              : int.tryParse('${m['line_end'] ?? ''}') ??
                    (globalStart + fallbackLines.length - 1);
          return CodeSnippet(
            code: code,
            explanation: explanation,
            lineStart: max(1, ls),
            lineEnd: max(ls, le),
          );
        })
        .toList();

    // filter degenerate results (empty code or absurd ranges)
    return list
        .where(
          (s) =>
              s.code.trim().isNotEmpty &&
              s.lineStart <= s.lineEnd &&
              s.lineStart >= 1 &&
              s.lineEnd - s.lineStart <= 120,
        )
        .toList();
  }

  List<CodeSnippet> _localSplitFallback(
    List<String> chunkLines,
    int globalStart,
  ) {
    // 30–60 line groups with simple reasoning
    final local = <CodeSnippet>[];
    int i = 0;
    while (i < chunkLines.length) {
      final end = min(i + 40, chunkLines.length);
      final seg = chunkLines.sublist(i, end).join('\n');
      final ls = globalStart + i;
      final le = globalStart + end - 1;
      local.add(
        CodeSnippet(
          code: seg,
          explanation:
              'This block groups related lines for readability. It likely includes setup, declarations, and control flow. Focus on the function/class boundaries and how values flow between them.',
          lineStart: ls,
          lineEnd: le,
        ),
      );
      i = end;
      if (local.length > 10) break; // keep it bounded per chunk
    }
    return local;
  }

  List<CodeSnippet> _dedupeAndSort(List<CodeSnippet> items) {
    // dedupe by normalized code+range
    final seen = <String>{};
    final out = <CodeSnippet>[];
    for (final s in items) {
      final key = '${s.lineStart}-${s.lineEnd}-${s.code.trim()}';
      if (seen.add(key)) out.add(s);
    }
    out.sort((a, b) => a.lineStart.compareTo(b.lineStart));
    return out;
  }

  String _extractPlain(String text) {
    String t = text.trim();
    if (t.startsWith('```')) t = t.substring(3);
    if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    return t.trim();
  }

  Future<void> _fallbackClientSideExplain() async {
    final code = _codeController.text;
    final lines = code.split('\n');
    final chunks = _smartChunk(lines);
    final out = <CodeSnippet>[];
    for (final c in chunks) {
      out.addAll(_localSplitFallback(c.text.split('\n'), c.startLine));
      if (out.length > hardMaxTotalSnippets) break;
    }
    setState(() {
      _overallExplanation =
          'High-level summary: The program defines logic across multiple functions/classes, initializes state, and processes input through control structures. See detailed blocks below.';
      _codeSnippets = _dedupeAndSort(out);
    });
  }

  // UI

  Widget _buildSnippetCard(CodeSnippet snippet, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Snippet Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Code Snippet ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  'Lines ${snippet.lineStart}-${snippet.lineEnd}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Code Block
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Code header with copy button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFF2B2B2B),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedLanguage,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copyToClipboard(snippet.code),
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: 'Copy snippet',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          minimumSize: const Size(28, 28),
                        ),
                      ),
                    ],
                  ),
                ),
                // Code content
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    snippet.code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Explanation
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Explanation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  snippet.explanation,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallExplanation() {
    if (_overallExplanation.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 3,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withOpacity(0.08),
              const Color(0xFF10B981).withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.code,
                    color: colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Overall Code Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              _overallExplanation,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 24),
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress.clamp(0.0, 1.0),
              minHeight: 6,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _progressLabel.isEmpty
                  ? 'Analyzing your code...'
                  : _progressLabel,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.8),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Code Explainer'),
        centerTitle: true,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Selection
            Row(
              children: [
                Text(
                  'Language:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onBackground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    dropdownColor: colorScheme.surface,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _languages.map((language) {
                      return DropdownMenuItem(
                        value: language,
                        child: Text(
                          language,
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value!;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Input Section
            Text(
              'Paste Your Code',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline),
              ),
              child: TextField(
                controller: _codeController,
                maxLines: 18,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.4,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Paste your code here...\n\nExample:\nclass Example {\n  void main() {\n    print("Hello World");\n  }\n}',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontFamily: 'monospace',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? colorScheme.surface.withOpacity(0.3)
                      : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Explain Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _explain,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.psychology),
                label: Text(
                  _loading ? 'Analyzing...' : 'Explain Code Step by Step',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (_loading) _buildLoadingState(),

            if (!_loading &&
                (_codeSnippets.isNotEmpty ||
                    _overallExplanation.isNotEmpty)) ...[
              const SizedBox(height: 24),
              _buildOverallExplanation(),

              if (_codeSnippets.isNotEmpty) ...[
                Text(
                  'Step-by-Step Breakdown',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(_codeSnippets.length, (index) {
                  return _buildSnippetCard(_codeSnippets[index], index);
                }),
              ],
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Chunk {
  final String text;
  final int startLine;
  final int endLine;
  _Chunk({required this.text, required this.startLine, required this.endLine});
}
