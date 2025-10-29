import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'
    as sf; // Use prefix for syncfusion
import 'package:pdf/pdf.dart'; // For PdfPageFormat
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'gemini_api.dart';

class ToolQuestionPaperPage extends StatefulWidget {
  final String initialTopic;
  const ToolQuestionPaperPage({super.key, this.initialTopic = ''});

  @override
  State<ToolQuestionPaperPage> createState() => _ToolQuestionPaperPageState();
}

enum QuestionType { mcq, descriptive, both }

enum DifficultyLevel { easy, medium, hard }

class _ToolQuestionPaperPageState extends State<ToolQuestionPaperPage> {
  late final TextEditingController _topicController;
  late final TextEditingController _numQuestionsController;

  String _output = '';
  bool _loading = false;
  File? _selectedFile;
  QuestionType _questionType = QuestionType.both;
  DifficultyLevel _difficultyLevel = DifficultyLevel.medium;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic);
    _numQuestionsController = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _topicController.dispose();
    _numQuestionsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _extractTextFromFile(File file) async {
    try {
      final ext = file.path.toLowerCase();
      if (ext.endsWith('.pdf')) {
        final bytes = await file.readAsBytes();
        final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
        final String text = sf.PdfTextExtractor(document).extractText();
        document.dispose();
        return text.trim();
      } else if (ext.endsWith('.txt')) {
        return await file.readAsString();
      } else if (ext.endsWith('.doc') || ext.endsWith('.docx')) {
        return "DOC/DOCX text extraction not supported yet. Please convert to PDF or use a TXT file.";
      } else {
        return "Unsupported file format.";
      }
    } catch (e) {
      return "Error extracting text from file: $e";
    }
  }

  Future<void> _generate() async {
    if (_numQuestionsController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the number of questions'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _loading = true;
      _output = '';
    });

    try {
      String? fileText;
      if (_selectedFile != null) {
        fileText = await _extractTextFromFile(_selectedFile!);
      }

      final buffer = StringBuffer();
      buffer.write(
        'Generate a clean, professional question paper with the following specifications:\n\n',
      );

      if (_topicController.text.trim().isNotEmpty) {
        buffer.write('Topic: ${_topicController.text.trim()}\n');
      }

      int? numQuestions;
      try {
        numQuestions = int.parse(_numQuestionsController.text.trim());
      } catch (_) {}

      if (numQuestions != null) {
        buffer.write('Number of questions: $numQuestions\n');
      }

      buffer.write('Question type: ');
      switch (_questionType) {
        case QuestionType.mcq:
          buffer.write('Multiple Choice Questions (MCQ) with 4 options each');
          break;
        case QuestionType.descriptive:
          buffer.write('Descriptive/Essay questions');
          break;
        case QuestionType.both:
          buffer.write('Both MCQ and descriptive questions');
          break;
      }
      buffer.write('\n');

      buffer.write('Difficulty level: ');
      switch (_difficultyLevel) {
        case DifficultyLevel.easy:
          buffer.write('Easy (Basic concepts and recall)');
          break;
        case DifficultyLevel.medium:
          buffer.write('Medium (Application and analysis)');
          break;
        case DifficultyLevel.hard:
          buffer.write('Hard (Advanced analysis and synthesis)');
          break;
      }
      buffer.write('\n\n');

      if (fileText != null &&
          fileText.isNotEmpty &&
          !fileText.startsWith('Error') &&
          !fileText.contains('not supported')) {
        buffer.write('Based on the following document content:\n');
        buffer.write('$fileText\n\n');
      } else if (_topicController.text.trim().isEmpty &&
          (fileText == null || fileText.isEmpty)) {
        setState(() {
          _output =
              'Please provide a topic or upload a document to generate questions.';
          _loading = false;
        });
        return;
      } else {
        buffer.write('Generate questions based on the topic provided.\n\n');
      }

      buffer.write('IMPORTANT FORMATTING REQUIREMENTS:\n');
      buffer.write('- Do NOT use ** or ## formatting\n');
      buffer.write('- Use plain text only\n');
      buffer.write('- Number questions clearly (1., 2., 3., etc.)\n');
      buffer.write('- For MCQ, use a), b), c), d) for options\n');
      buffer.write('- Separate answer key with "ANSWER KEY:" at the end\n');
      buffer.write('- No explanations, only clean questions and answers\n');
      buffer.write('- Use proper spacing between questions\n');

      final prompt = buffer.toString();

      final res = await GeminiApi.callGemini(
        prompt: prompt,
        endpoint: 'https://your-backend.example/question-paper',
      );

      setState(() {
        _output = res;
      });
    } catch (e) {
      setState(() {
        _output = 'Error generating questions: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Generated Question Paper',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Generated on: ${DateTime.now().toString().split(' ')[0]}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Divider(),
                ],
              ),
            ),
            pw.Paragraph(
              text: _cleanResponse(_output),
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportDocx() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DOCX export feature coming soon!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  // Helper method to clean response from ** and ## formatting
  String _cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r'\*\*'), '') // Remove **
        .replaceAll(RegExp(r'##'), '') // Remove ##
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Remove # headers
        .replaceAll(
          RegExp(r'\*{1,2}([^*]+)\*{1,2}'),
          r'$1',
        ) // Remove bold formatting
        .trim();
  }

  // Helper method to separate questions and answer key
  Map<String, String> _separateQuestionsAndAnswers(String text) {
    final cleanText = _cleanResponse(text);
    final answerKeyRegex = RegExp(
      r'ANSWER KEY:?\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    );
    final match = answerKeyRegex.firstMatch(cleanText);

    if (match != null) {
      final questions = cleanText.substring(0, match.start).trim();
      final answers = match.group(1)?.trim() ?? '';
      return {'questions': questions, 'answers': answers};
    }

    return {'questions': cleanText, 'answers': ''};
  }

  Widget _buildFileUploadCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.upload_file, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Document Upload',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _selectedFile == null
                        ? 'Choose Document'
                        : 'Change Document',
                  ),
                  onPressed: _loading ? null : _pickFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFile?.path.split('/').last ??
                        'No document selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: _selectedFile != null
                          ? Colors.green
                          : Colors.grey[600],
                    ),
                  ),
                ),
                if (_selectedFile != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    tooltip: 'Remove document',
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _selectedFile = null;
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Supported formats: PDF, TXT, DOC, DOCX',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTypeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.quiz, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Question Configuration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.topic),
                hintText: 'e.g., Photosynthesis, World War II',
              ),
              enabled: !_loading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numQuestionsController,
              decoration: const InputDecoration(
                labelText: 'Number of Questions',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              enabled: !_loading,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DifficultyLevel>(
              value: _difficultyLevel,
              decoration: const InputDecoration(
                labelText: 'Difficulty Level',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.trending_up),
              ),
              items: DifficultyLevel.values.map((e) {
                final text = e.name[0].toUpperCase() + e.name.substring(1);
                return DropdownMenuItem(value: e, child: Text(text));
              }).toList(),
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _difficultyLevel = v!),
            ),
            const SizedBox(height: 16),
            const Text(
              'Question Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...QuestionType.values.map((type) {
              String title = '';
              String subtitle = '';
              switch (type) {
                case QuestionType.mcq:
                  title = 'Multiple Choice Questions';
                  subtitle = 'Questions with 4 options and correct answers';
                  break;
                case QuestionType.descriptive:
                  title = 'Descriptive Questions';
                  subtitle = 'Essay-type questions with detailed answers';
                  break;
                case QuestionType.both:
                  title = 'Mixed (MCQ + Descriptive)';
                  subtitle = 'Combination of both question types';
                  break;
              }
              return RadioListTile<QuestionType>(
                title: Text(title),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                value: type,
                groupValue: _questionType,
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _questionType = v!),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Clean Generated Question Paper card with separated questions and answers
  Widget _buildGeneratedQuestionCard() {
    final separated = _separateQuestionsAndAnswers(_output);
    final questions = separated['questions'] ?? '';
    final answers = separated['answers'] ?? '';

    return Column(
      children: [
        // Questions Container
        Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.blue[50]!],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Questions Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[400]!, Colors.blue[600]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.quiz,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question Paper',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              'Clean formatted questions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Download buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _exportPdf,
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          label: const Text('Download PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _exportDocx,
                          icon: const Icon(Icons.file_copy, size: 20),
                          label: const Text('Download DOCX'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Questions Content
                  Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Questions',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(
                                questions,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.left,
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
        ),

        // Answer Key Container (if answers exist)
        if (answers.isNotEmpty)
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.green[50]!],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Answer Key Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green[400]!, Colors.green[600]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.key,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Answer Key',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'Correct answers and solutions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Answer Key Content
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Answer Key',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: SelectableText(
                                  answers,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.left,
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
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Paper Generator'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildFileUploadCard(),
                  const SizedBox(height: 16),
                  _buildQuestionTypeCard(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _generate,
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
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _loading ? 'Generating...' : 'Generate Questions',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Clean Generated Question Paper with separated sections
                  if (_output.isNotEmpty) _buildGeneratedQuestionCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
