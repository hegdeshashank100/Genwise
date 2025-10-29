import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:open_file/open_file.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ToolPosterPage extends StatefulWidget {
  final String initialDetails;

  const ToolPosterPage({super.key, this.initialDetails = ''});

  @override
  State<ToolPosterPage> createState() => _ToolPosterPageState();
}

class _ToolPosterPageState extends State<ToolPosterPage>
    with TickerProviderStateMixin {
  late final TextEditingController _detailsController;
  List<String> _posterImagePaths = [];
  bool _loading = false;
  FilePickerResult? _logoFile;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Your Gemini API key
  static const String _geminiApiKey = 'YOUR_API_KEY_HERE';

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController(text: widget.initialDetails);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        setState(() {
          _logoFile = result;
        });

        _showSnackBar(
          'Logo selected successfully!',
          Colors.green,
          Icons.check_circle,
        );
      }
    } catch (e) {
      _showSnackBar('Error picking logo: $e', Colors.red, Icons.error);
    }
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    } else {
      await Permission.storage.request();
    }
  }

  Future<void> _saveImageToDownloads(String imagePath) async {
    try {
      await _requestStoragePermission();
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        downloadsDir = Directory("/storage/emulated/0/Download");
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception("Could not access Downloads folder");
      }

      Uint8List posterBytes = await File(imagePath).readAsBytes();

      if (_logoFile != null) {
        final logoPath = _logoFile!.files.single.path!;
        final combinedBytes = await _overlayLogoOnPoster(
          posterBytes,
          File(logoPath),
        );
        posterBytes = combinedBytes;
      }

      String fileName = "poster_${DateTime.now().millisecondsSinceEpoch}.png";
      File file = File("${downloadsDir.path}/$fileName");
      await file.writeAsBytes(posterBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.save_alt, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text("Poster saved: ${file.path}")),
            ],
          ),
          backgroundColor: Colors.blue[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: "Open",
            textColor: Colors.white,
            onPressed: () {
              OpenFile.open(file.path);
            },
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Save failed: $e', Colors.red, Icons.error);
    }
  }

  Future<Uint8List> _overlayLogoOnPoster(
    Uint8List posterBytes,
    File logoFile,
  ) async {
    final posterImage = await _loadUiImage(posterBytes);
    final logoBytes = await logoFile.readAsBytes();
    final logoImage = await _loadUiImage(logoBytes);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    canvas.drawImage(posterImage, Offset.zero, paint);

    double logoWidth = posterImage.width * 0.15;
    double logoHeight = logoWidth * (logoImage.height / logoImage.width);

    canvas.drawImageRect(
      logoImage,
      Rect.fromLTWH(
        0,
        0,
        logoImage.width.toDouble(),
        logoImage.height.toDouble(),
      ),
      Rect.fromLTWH(30, 30, logoWidth, logoHeight),
      paint,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(posterImage.width, posterImage.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<ui.Image> _loadUiImage(Uint8List imgBytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(imgBytes, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  String _buildEnhancedPrompt(String userDescription) {
    return """Generate a professional, high-quality poster design in a 3D digital art style.

CONTENT: $userDescription

For the poster, create an image with these specifications:

DESIGN REQUIREMENTS:
- Vertical poster format (portrait orientation, 2:3 aspect ratio)
- Professional, eye-catching layout with clear visual hierarchy
- Bold, highly readable typography that stands out from a distance
- Modern, clean design aesthetic
- Leave a clear 150x150px space in the top-left corner for logo placement
- Use complementary color schemes that enhance readability and visual appeal
- Include appropriate white space and margins for a balanced composition
- High contrast between text and background for maximum legibility

VISUAL STYLE:
- 3D digital art style with depth and dimension
- Photorealistic quality where applicable
- Sharp, crisp text rendering with high-fidelity typography
- Professional color grading and lighting effects
- Suitable for both print and digital display
- Eye-catching but not cluttered - maintain visual balance

TEXT & TYPOGRAPHY:
- All text must be sharp, clear, and perfectly legible
- Use bold, modern fonts for headlines
- Ensure proper text placement and alignment
- Text should integrate seamlessly with 3D design elements
- Add subtle shadows or depth effects to text for dimension

OUTPUT QUALITY:
- High resolution, print-ready quality
- Professional poster suitable for marketing, events, or announcements
- Balanced composition with proper negative space
- Modern, contemporary 3D digital art design style
- Vibrant, engaging colors that capture attention""";
  }

  Future<void> _generatePosters() async {
    if (_detailsController.text.trim().isEmpty) {
      _showSnackBar(
        'Please enter poster description',
        Colors.orange,
        Icons.warning,
      );
      return;
    }

    setState(() {
      _loading = true;
      _posterImagePaths.clear();
    });

    _fadeController.reset();
    _scaleController.reset();

    try {
      final prompt = _buildEnhancedPrompt(_detailsController.text);

      // Use Gemini 2.0 Flash Experimental with image generation
      // Following the exact pattern from the Python reference code
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$_geminiApiKey',
      );

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': [
            'Text',
            'Image',
          ], // Match Python: ["Text", "Image"]
        },
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Extract images from Gemini response
        if (jsonResponse.containsKey('candidates') &&
            jsonResponse['candidates'] is List &&
            jsonResponse['candidates'].isNotEmpty) {
          final candidate = jsonResponse['candidates'][0];

          if (candidate['content'] != null &&
              candidate['content']['parts'] != null) {
            for (var part in candidate['content']['parts']) {
              // Check for inline image data
              if (part['inlineData'] != null &&
                  part['inlineData']['data'] != null) {
                final imageData = part['inlineData']['data'] as String;
                final bytes = base64Decode(imageData);

                final tempDir = await getTemporaryDirectory();
                final filePath =
                    '${tempDir.path}/poster_${DateTime.now().millisecondsSinceEpoch}.png';
                final file = File(filePath);
                await file.writeAsBytes(bytes);

                setState(() {
                  _posterImagePaths.add(filePath);
                });

                _fadeController.forward();
                _scaleController.forward();
              }
            }
          }
        }

        if (_posterImagePaths.isEmpty) {
          throw Exception(
            'No image generated. The model may have returned only text. Response: ${json.encode(jsonResponse)}',
          );
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(
          'API Error ${response.statusCode}: ${error['error']?['message'] ?? error}',
        );
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red, Icons.error);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showDownloadDialog(String imagePath) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.download, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              "Download Poster",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          "Save this poster to your Downloads folder?",
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurface.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text("Cancel"),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _saveImageToDownloads(imagePath);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.download, size: 18),
              label: const Text("Download"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = isDark
        ? colorScheme.background
        : Colors.grey.shade50;
    final cardColor = colorScheme.surface;
    final textColor = colorScheme.onBackground;
    final secondaryTextColor = colorScheme.onSurface.withOpacity(0.7);
    final primaryAccentColor = colorScheme.primary;
    final borderColor = colorScheme.outline;
    final appBarBackgroundColor = isDark ? colorScheme.surface : Colors.white;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: primaryAccentColor, size: 24),
            const SizedBox(width: 8),
            Text(
              'AI Poster Generator',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: textColor,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                appBarBackgroundColor,
                isDark ? colorScheme.background : Colors.grey.shade50,
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  borderColor.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Logo Upload Section
              GestureDetector(
                onTap: _pickLogo,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _logoFile != null ? Colors.green : borderColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: _logoFile != null
                              ? Colors.green.withOpacity(0.1)
                              : primaryAccentColor.withOpacity(0.1),
                        ),
                        child: _logoFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(_logoFile!.files.single.path!),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 28,
                                color: primaryAccentColor,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _logoFile != null
                                  ? "Logo Selected ✓"
                                  : "Upload Logo (Optional)",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _logoFile != null
                                    ? Colors.green
                                    : textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _logoFile != null
                                  ? "Tap to change logo"
                                  : "Add your brand logo to posters",
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _logoFile != null
                            ? Icons.check_circle
                            : Icons.cloud_upload_outlined,
                        color: _logoFile != null
                            ? Colors.green
                            : primaryAccentColor,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Description Input Section
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.description,
                              color: Colors.orange,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Poster Description",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _detailsController,
                        maxLines: null,
                        minLines: 6,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: borderColor,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: borderColor,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: primaryAccentColor,
                              width: 2,
                            ),
                          ),
                          fillColor: isDark
                              ? colorScheme.surface.withOpacity(0.3)
                              : Colors.grey.shade50,
                          filled: true,
                          hintText:
                              'Describe your poster in detail...\n\nExample: "College event poster for TREASURE HUNT at PESITM Shivamogga, vibrant colors, bold title text, event details, energetic design"',
                          hintStyle: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 15,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Generate Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _loading
                        ? [
                            colorScheme.onSurface.withOpacity(0.3),
                            colorScheme.onSurface.withOpacity(0.4),
                          ]
                        : [
                            primaryAccentColor,
                            primaryAccentColor.withOpacity(0.8),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _loading
                      ? null
                      : [
                          BoxShadow(
                            color: primaryAccentColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generatePosters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 24),
                  label: Text(
                    _loading
                        ? 'Generating with Gemini AI...'
                        : 'Generate Poster with AI',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Results Section
              if (_posterImagePaths.isNotEmpty)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.collections,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Generated Poster",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Gemini 2.0 Exp',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _posterImagePaths.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 1,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.67,
                              ),
                          itemBuilder: (context, index) {
                            final imgPath = _posterImagePaths[index];
                            return GestureDetector(
                              onTap: () => _showDownloadDialog(imgPath),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: shadowColor.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        File(imgPath),
                                        fit: BoxFit.cover,
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.7),
                                            ],
                                            stops: const [0.7, 1.0],
                                          ),
                                        ),
                                      ),
                                      const Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.touch_app,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Tap to download',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
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
      ),
    );
  }
}
