import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'gemini_api.dart';

class ToolImageStoryPage extends StatefulWidget {
  const ToolImageStoryPage({super.key});
  @override
  State<ToolImageStoryPage> createState() => _ToolImageStoryPageState();
}

enum StoryGenre {
  adventure('Adventure', Icons.explore, Colors.orange),
  mystery('Mystery', Icons.search, Colors.purple),
  romance('Romance', Icons.favorite, Colors.pink),
  fantasy('Fantasy', Icons.auto_awesome, Colors.indigo),
  horror('Horror', Icons.nightlight, Colors.red),
  comedy('Comedy', Icons.sentiment_very_satisfied, Colors.green),
  drama('Drama', Icons.theater_comedy, Colors.blue),
  sciFi('Sci-Fi', Icons.rocket_launch, Colors.cyan),
  historical('Historical', Icons.history_edu, Colors.brown),
  children('Children\'s', Icons.child_care, Colors.amber);

  const StoryGenre(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

enum StoryLength {
  short('Short (100-150 words)', '100-150 words'),
  medium('Medium (200-300 words)', '200-300 words');

  const StoryLength(this.label, this.description);
  final String label;
  final String description;
}

enum StoryLanguage {
  english('English', '🇺🇸'),
  kannada('Kannada', 'kar'),
  spanish('Spanish', '🇪🇸'),
  french('French', '🇫🇷'),
  german('German', '🇩🇪'),
  italian('Italian', '🇮🇹'),
  portuguese('Portuguese', '🇵🇹'),
  russian('Russian', '🇷🇺'),
  japanese('Japanese', '🇯🇵'),
  korean('Korean', '🇰🇷'),
  chinese('Chinese', '🇨🇳'),
  arabic('Arabic', '🇸🇦'),
  hindi('Hindi', '🇮🇳'),
  dutch('Dutch', '🇳🇱'),
  swedish('Swedish', '🇸🇪'),
  norwegian('Norwegian', '🇳🇴');

  const StoryLanguage(this.label, this.flag);
  final String label;
  final String flag;
}

class _ToolImageStoryPageState extends State<ToolImageStoryPage> {
  String _output = '';
  bool _loading = false;
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _themeController = TextEditingController();
  final TextEditingController _customPromptController = TextEditingController();
  StoryGenre _selectedGenre = StoryGenre.adventure;
  StoryLength _selectedLength = StoryLength.medium;
  StoryLanguage _selectedLanguage = StoryLanguage.english;
  bool _includeDialogue = true;
  bool _includeDescription = true;

  @override
  void dispose() {
    _themeController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} image(s) selected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickSingleImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        setState(() {
          _selectedImages = [image];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _generate() async {
    if (_themeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a theme for your story'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _output = '';
    });

    try {
      String prompt =
          '''
Create a ${_selectedGenre.label.toLowerCase()} story with the following specifications:
IMPORTANT: Write the entire story in ${_selectedLanguage.label}. All text, dialogue, descriptions, and narrative should be in ${_selectedLanguage.label}.
Theme: "${_themeController.text.trim()}"
Length: ${_selectedLength.description}
Genre: ${_selectedGenre.label}
Language: ${_selectedLanguage.label}
Story Requirements:
${_includeDialogue ? '- Include engaging dialogue between characters' : '- Focus on narrative without dialogue'}
${_includeDescription ? '- Include vivid descriptions of scenes and characters' : '- Keep descriptions minimal and focus on action'}
${_customPromptController.text.trim().isNotEmpty ? 'Additional Instructions: ${_customPromptController.text.trim()}' : ''}
${_selectedImages.isNotEmpty ? '''
IMPORTANT: The user has uploaded ${_selectedImages.length} image(s) to inspire this story. 
Please create a story that incorporates visual elements commonly found in images such as:
- People, characters, or figures in various poses or activities
- Landscapes, settings, environments (indoor/outdoor scenes)
- Objects, items, symbols, or artifacts
- Colors, lighting, moods, or atmospheres
- Actions, scenes, moments, or events
- Architectural elements, nature scenes, or urban environments
Use your creativity to imagine what these images might contain and weave those visual elements naturally into your narrative. The story should feel like it was genuinely inspired by compelling visual imagery.
''' : 'Create an original story based on the theme and genre specified.'}
Please structure the story with:
1. An engaging, creative title (in ${_selectedLanguage.label})
2. A well-developed story with proper pacing and character development (in ${_selectedLanguage.label})
3. A satisfying and memorable conclusion (in ${_selectedLanguage.label})
Make the story creative, engaging, emotionally resonant, and appropriate for the chosen genre. Focus on creating vivid scenes that readers can easily visualize. Remember to write everything in ${_selectedLanguage.label}.
''';

      // Call Gemini API
      final response = await GeminiApi.callGemini(prompt: prompt);
      setState(() {
        _output = response;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _output =
            'Error: Unable to generate story. Please try again.\n\nDetails: ${e.toString()}';
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyStory() {
    if (_output.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _output));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearAll() {
    setState(() {
      _selectedImages.clear();
      _themeController.clear();
      _customPromptController.clear();
      _output = '';
      _selectedGenre = StoryGenre.adventure;
      _selectedLength = StoryLength.medium;
      _selectedLanguage = StoryLanguage.english;
      _includeDialogue = true;
      _includeDescription = true;
    });
  }

  Widget _buildImageGrid() {
    if (_selectedImages.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onBackground;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Images (${_selectedImages.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_selectedImages[index].path),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onBackground;
    final unselectedBgColor = isDark
        ? colorScheme.surface
        : Colors.grey.shade200;
    final unselectedTextColor = isDark
        ? colorScheme.onSurface
        : Colors.grey.shade700;
    final unselectedBorderColor = isDark
        ? colorScheme.outline
        : Colors.grey.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Story Genre',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: StoryGenre.values.map((genre) {
            final isSelected = _selectedGenre == genre;
            return GestureDetector(
              onTap: () => setState(() => _selectedGenre = genre),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? genre.color : unselectedBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? genre.color : unselectedBorderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      genre.icon,
                      size: 14,
                      color: isSelected ? Colors.white : unselectedTextColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        genre.label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : unselectedTextColor,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // 🎨 Dynamic Colors Based on Theme
    final backgroundColor = isDark
        ? colorScheme.background
        : Colors.grey.shade50;
    final cardColor = colorScheme.surface;
    final textColor = colorScheme.onBackground;
    final secondaryTextColor = colorScheme.onSurface.withOpacity(0.7);
    final borderColor = colorScheme.outline;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const FittedBox(child: Text('📖 AI Story Generator')),
        backgroundColor: _selectedGenre.color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_output.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyStory,
              tooltip: 'Copy Story',
            ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearAll,
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📷 Image Upload Section with Theme Support
              Card(
                elevation: 4,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Images (Optional)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload one or more images to inspire your story',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickSingleImage,
                              icon: const Icon(
                                Icons.add_photo_alternate,
                                size: 18,
                              ),
                              label: const FittedBox(
                                child: Text(
                                  'Single Image',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedGenre.color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const FittedBox(
                                child: Text(
                                  'Multiple Images',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedGenre.color
                                    .withOpacity(0.8),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _buildImageGrid(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ⚙️ Story Configuration with Theme Support
              Card(
                elevation: 4,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Story Configuration',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 📝 Theme Input with Theme Support
                      TextFormField(
                        controller: _themeController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Story Theme *',
                          labelStyle: TextStyle(color: secondaryTextColor),
                          hintText:
                              'e.g., Friendship, Adventure, Love, Mystery...',
                          hintStyle: TextStyle(color: secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _selectedGenre.color),
                          ),
                          prefixIcon: Icon(
                            Icons.lightbulb_outline,
                            color: secondaryTextColor,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🎭 Genre Selector
                      _buildGenreSelector(),
                      const SizedBox(height: 16),

                      // 📏 Story Length with Theme Support
                      Text(
                        'Story Length',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<StoryLength>(
                        value: _selectedLength,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _selectedGenre.color),
                          ),
                          prefixIcon: Icon(
                            Icons.format_size,
                            color: secondaryTextColor,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: StoryLength.values.map((length) {
                          return DropdownMenuItem(
                            value: length,
                            child: Text(
                              length.label,
                              style: TextStyle(color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedLength = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 🌍 Story Language with Theme Support
                      Text(
                        'Story Language',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<StoryLanguage>(
                        value: _selectedLanguage,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _selectedGenre.color),
                          ),
                          prefixIcon: Icon(
                            Icons.language,
                            color: secondaryTextColor,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: StoryLanguage.values.map((language) {
                          return DropdownMenuItem(
                            value: language,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(language.flag),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    language.label,
                                    style: TextStyle(color: textColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedLanguage = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // ✅ Story Options with Theme Support
                      Text(
                        'Story Elements',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: Text(
                          'Include Dialogue',
                          style: TextStyle(color: textColor),
                        ),
                        subtitle: Text(
                          'Add conversations between characters',
                          style: TextStyle(color: secondaryTextColor),
                        ),
                        value: _includeDialogue,
                        onChanged: (value) {
                          setState(() => _includeDialogue = value ?? true);
                        },
                        activeColor: _selectedGenre.color,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: Text(
                          'Include Detailed Descriptions',
                          style: TextStyle(color: textColor),
                        ),
                        subtitle: Text(
                          'Add vivid scene and character descriptions',
                          style: TextStyle(color: secondaryTextColor),
                        ),
                        value: _includeDescription,
                        onChanged: (value) {
                          setState(() => _includeDescription = value ?? true);
                        },
                        activeColor: _selectedGenre.color,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16),

                      // 📝 Custom Prompt with Theme Support
                      TextFormField(
                        controller: _customPromptController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Additional Instructions (Optional)',
                          labelStyle: TextStyle(color: secondaryTextColor),
                          hintText:
                              'Any specific requirements for your story...',
                          hintStyle: TextStyle(color: secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _selectedGenre.color),
                          ),
                          prefixIcon: Icon(
                            Icons.edit_note,
                            color: secondaryTextColor,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🚀 Generate Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: FittedBox(
                    child: Text(
                      _loading
                          ? 'Generating Story...'
                          : 'Generate Story in ${_selectedLanguage.label}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedGenre.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 📖 Output Section with Theme Support
              if (_output.isNotEmpty || _loading)
                Card(
                  elevation: 4,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Generated Story',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_output.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedGenre.color.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _selectedGenre.color
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_selectedLanguage.flag),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              _selectedLanguage.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _selectedGenre.color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_output.isNotEmpty)
                              IconButton(
                                onPressed: _copyStory,
                                icon: Icon(
                                  Icons.copy,
                                  color: secondaryTextColor,
                                ),
                                tooltip: 'Copy Story',
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_loading)
                          Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  color: _selectedGenre.color,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Creating your story...',
                                  style: TextStyle(color: textColor),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colorScheme.surface.withOpacity(0.5)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: SelectableText(
                              _output,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: textColor,
                              ),
                            ),
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
