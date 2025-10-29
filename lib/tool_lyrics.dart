import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gemini_api.dart';

class ToolLyricsPage extends StatefulWidget {
  final String initialTheme;
  final String initialMood;
  const ToolLyricsPage({
    super.key,
    this.initialTheme = 'love, hope',
    this.initialMood = 'melancholic',
  });

  @override
  State<ToolLyricsPage> createState() => _ToolLyricsPageState();
}

class _ToolLyricsPageState extends State<ToolLyricsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _themeController;
  late final TextEditingController _moodController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _customChorusController = TextEditingController();
  String _lyrics = '';
  bool _loading = false;

  String _genre = 'Pop';
  String _language = 'English';
  bool _explicit = false;
  String _rhymeScheme = "AABB";
  int _verseCount = 2;
  int _chorusCount = 1;
  int _bridgeCount = 0;
  String _songType = "Full Song";

  static const genres = [
    "Pop",
    "Rock",
    "Hip-Hop",
    "Jazz",
    "Metal",
    "Folk",
    "Classical",
    "EDM",
    "R&B",
    "Country",
    "Custom",
  ];

  static const languages = [
    "English",
    "Hindi",
    "Spanish",
    "French",
    "German",
    "Chinese",
    "Japanese",
    "Italian",
    "Korean",
  ];

  static const rhymeSchemes = ["AABB", "ABAB", "ABBA", "None"];

  static const songTypes = [
    "Full Song",
    "Only Chorus",
    "Only Verse",
    "Verse + Chorus",
    "Verse/Chorus/Bridge",
  ];

  @override
  void initState() {
    super.initState();
    _themeController = TextEditingController(text: widget.initialTheme);
    _moodController = TextEditingController(text: widget.initialMood);
  }

  @override
  void dispose() {
    _themeController.dispose();
    _moodController.dispose();
    _titleController.dispose();
    _customChorusController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _lyrics = '';
    });

    try {
      final prompt =
          '''
Generate song lyrics with these features:
${_titleController.text.isNotEmpty ? 'Title: ${_titleController.text}' : 'Title: Create a catchy title'}
Theme: ${_themeController.text}
Mood: ${_moodController.text}
Genre: $_genre
Language: $_language
Song Type: $_songType
Explicit: ${_explicit ? "Yes" : "No"}
Rhyme Scheme: $_rhymeScheme
Number of Verses: $_verseCount
Number of Chorus: $_chorusCount
Number of Bridges: $_bridgeCount
${_customChorusController.text.isNotEmpty ? 'Custom Chorus: "${_customChorusController.text}"' : ''}

Please generate a ${_songType.toLowerCase()} with these settings, with proper structure and visible section headings. Lyrics should be easy to read and suitable for songwriting, without any markdown formatting or special characters.

Song structure example:
Verse 1
...
Chorus
...
Verse 2
...

Do not use asterisks, hashes, or markdown.
''';

      final res = await GeminiApi.callGemini(prompt: prompt);

      setState(() {
        _lyrics = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _lyrics = 'Error: $e';
        _loading = false;
      });
    }
  }

  void _copyLyrics() {
    if (_lyrics.trim().isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _lyrics));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lyrics copied to clipboard!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareLyrics() {
    if (_lyrics.trim().isNotEmpty) {
      _copyLyrics();
    }
  }

  Widget _buildResponsiveRow({
    required List<Widget> children,
    required bool forceColumn,
    double spacing = 12.0,
  }) {
    if (forceColumn) {
      return Column(
        children: children
            .expand((child) => [child, SizedBox(height: spacing)])
            .take(children.length * 2 - 1)
            .toList(),
      );
    } else {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children
              .expand(
                (child) => [Expanded(child: child), SizedBox(width: spacing)],
              )
              .take(children.length * 2 - 1)
              .toList(),
        ),
      );
    }
  }

  Widget _buildNumberInput({
    required String label,
    required IconData icon,
    required int initialValue,
    required Function(int) onChanged,
    int maxLength = 2,
  }) {
    // 🌙 Theme Detection
    final colorScheme = Theme.of(context).colorScheme;

    return Flexible(
      child: Container(
        constraints: const BoxConstraints(minWidth: 70),
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 12,
            ),
            isDense: true,
            filled: true,
            fillColor: colorScheme.surface,
          ),
          initialValue: initialValue.toString(),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          onChanged: (v) => onChanged(int.tryParse(v) ?? initialValue),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
        ),
      ),
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
    final primaryColor = colorScheme.primary;
    final onPrimaryColor = colorScheme.onPrimary;
    final textColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurface.withOpacity(0.7);
    final borderColor = colorScheme.outline;

    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isVerySmallScreen = screenSize.width < 400;

    // Calculate available height minus keyboard
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight =
        screenSize.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        keyboardHeight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Lyrics Generator',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: onPrimaryColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: onPrimaryColor,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_lyrics.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.copy, color: onPrimaryColor),
              tooltip: "Copy Lyrics",
              onPressed: _copyLyrics,
            ),
            IconButton(
              icon: Icon(Icons.share, color: onPrimaryColor),
              tooltip: "Share Lyrics",
              onPressed: _shareLyrics,
            ),
          ],
        ],
      ),
      body: SizedBox(
        height: availableHeight,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // THEME & MOOD SECTION
                Card(
                  elevation: 4,
                  color: cardColor,
                  shadowColor: isDark
                      ? Colors.black54
                      : Colors.grey.withOpacity(0.2),
                  child: Padding(
                    padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Basic Information',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isVerySmallScreen ? 12 : 16),

                        _buildResponsiveRow(
                          forceColumn: isSmallScreen,
                          children: [
                            TextFormField(
                              controller: _themeController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Theme',
                                labelStyle: TextStyle(
                                  color: secondaryTextColor,
                                ),
                                hintText: 'e.g. love, hope, heartbreak',
                                hintStyle: TextStyle(color: secondaryTextColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                                prefixIcon: Icon(
                                  Icons.favorite,
                                  color: secondaryTextColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: cardColor,
                              ),
                              validator: (val) =>
                                  val!.trim().isEmpty ? "Enter a theme" : null,
                              maxLines: null,
                              textInputAction: TextInputAction.next,
                            ),
                            TextFormField(
                              controller: _moodController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Mood',
                                labelStyle: TextStyle(
                                  color: secondaryTextColor,
                                ),
                                hintText: 'e.g. melancholy, upbeat',
                                hintStyle: TextStyle(color: secondaryTextColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                                prefixIcon: Icon(
                                  Icons.mood,
                                  color: secondaryTextColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: cardColor,
                              ),
                              validator: (val) =>
                                  val!.trim().isEmpty ? "Enter a mood" : null,
                              maxLines: null,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),

                        SizedBox(height: isVerySmallScreen ? 12 : 16),
                        TextField(
                          controller: _titleController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Song Title (optional)',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            hintText: 'Leave blank for AI to create',
                            hintStyle: TextStyle(color: secondaryTextColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            prefixIcon: Icon(
                              Icons.title,
                              color: secondaryTextColor,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            filled: true,
                            fillColor: cardColor,
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isVerySmallScreen ? 12 : 16),

                // GENRE & LANGUAGE SECTION
                Card(
                  elevation: 4,
                  color: cardColor,
                  shadowColor: isDark
                      ? Colors.black54
                      : Colors.grey.withOpacity(0.2),
                  child: Padding(
                    padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.style,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Style & Language',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isVerySmallScreen ? 12 : 16),

                        _buildResponsiveRow(
                          forceColumn: isSmallScreen,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _genre,
                              isExpanded: true,
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor),
                              items: genres
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(
                                        g,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              decoration: InputDecoration(
                                labelText: 'Genre',
                                labelStyle: TextStyle(
                                  color: secondaryTextColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                                prefixIcon: Icon(
                                  Icons.music_note,
                                  color: secondaryTextColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: cardColor,
                              ),
                              onChanged: (g) => setState(() => _genre = g!),
                            ),
                            DropdownButtonFormField<String>(
                              value: _language,
                              isExpanded: true,
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor),
                              items: languages
                                  .map(
                                    (l) => DropdownMenuItem(
                                      value: l,
                                      child: Text(
                                        l,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              decoration: InputDecoration(
                                labelText: 'Language',
                                labelStyle: TextStyle(
                                  color: secondaryTextColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                                prefixIcon: Icon(
                                  Icons.language,
                                  color: secondaryTextColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: cardColor,
                              ),
                              onChanged: (l) => setState(() => _language = l!),
                            ),
                          ],
                        ),

                        SizedBox(height: isVerySmallScreen ? 12 : 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                flex: 2,
                                child: Text(
                                  "Explicit Content:",
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 14 : 16,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Flexible(
                                flex: 1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Switch(
                                      value: _explicit,
                                      onChanged: (val) =>
                                          setState(() => _explicit = val),
                                      activeColor: primaryColor,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _explicit ? "Yes" : "No",
                                      style: TextStyle(
                                        color: _explicit
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isVerySmallScreen ? 12 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isVerySmallScreen ? 12 : 16),

                // SONG STRUCTURE SECTION
                Card(
                  elevation: 4,
                  color: cardColor,
                  shadowColor: isDark
                      ? Colors.black54
                      : Colors.grey.withOpacity(0.2),
                  child: Padding(
                    padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.architecture,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Song Structure',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isVerySmallScreen ? 12 : 16),

                        _buildResponsiveRow(
                          forceColumn: isSmallScreen,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _rhymeScheme,
                              isExpanded: true,
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor),
                              items: rhymeSchemes
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        "Rhyme: $s",
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              decoration: InputDecoration(
                                labelText: 'Rhyme Scheme',
                                labelStyle: TextStyle(
                                  color: secondaryTextColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                                prefixIcon: Icon(
                                  Icons.architecture,
                                  color: secondaryTextColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: cardColor,
                              ),
                              onChanged: (s) =>
                                  setState(() => _rhymeScheme = s!),
                            ),
                            DropdownButtonFormField<String>(
                              value: _songType,
                              isExpanded: true,
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor),
                              items: songTypes
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(
                                        t,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              decoration: InputDecoration(
                                labelText: 'Song Type',
                                labelStyle: TextStyle(
                                  color: secondaryTextColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                                prefixIcon: Icon(
                                  Icons.library_music,
                                  color: secondaryTextColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: cardColor,
                              ),
                              onChanged: (t) => setState(() => _songType = t!),
                            ),
                          ],
                        ),

                        SizedBox(height: isVerySmallScreen ? 12 : 16),

                        // Number inputs with better spacing
                        Row(
                          children: [
                            _buildNumberInput(
                              label: 'Verses',
                              icon: Icons.format_list_numbered,
                              initialValue: _verseCount,
                              onChanged: (v) => setState(() => _verseCount = v),
                            ),
                            const SizedBox(width: 6),
                            _buildNumberInput(
                              label: 'Chorus',
                              icon: Icons.repeat,
                              initialValue: _chorusCount,
                              onChanged: (v) =>
                                  setState(() => _chorusCount = v),
                            ),
                            const SizedBox(width: 6),
                            _buildNumberInput(
                              label: 'Bridges',
                              icon: Icons.account_tree,
                              initialValue: _bridgeCount,
                              onChanged: (v) =>
                                  setState(() => _bridgeCount = v),
                            ),
                          ],
                        ),

                        SizedBox(height: isVerySmallScreen ? 12 : 16),
                        TextField(
                          controller: _customChorusController,
                          minLines: 1,
                          maxLines: 2,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Custom Chorus (optional)',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            hintText: 'AI will incorporate this',
                            hintStyle: TextStyle(color: secondaryTextColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            prefixIcon: Icon(
                              Icons.edit,
                              color: secondaryTextColor,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: cardColor,
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isVerySmallScreen ? 16 : 20),

                // GENERATE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: isVerySmallScreen ? 48 : 56,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: _loading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onPrimaryColor,
                            ),
                          )
                        : Icon(
                            Icons.music_note,
                            size: isVerySmallScreen ? 20 : 24,
                          ),
                    label: Text(
                      _loading ? 'Generating Lyrics...' : 'Generate Lyrics',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: onPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),

                SizedBox(height: isVerySmallScreen ? 16 : 20),

                // LYRICS DISPLAY
                if (_lyrics.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(
                      minHeight: 200,
                      maxHeight: availableHeight * 0.5,
                    ),
                    child: Card(
                      elevation: 6,
                      color: cardColor,
                      shadowColor: isDark
                          ? Colors.black54
                          : Colors.grey.withOpacity(0.3),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cardColor, primaryColor.withOpacity(0.05)],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(
                                isVerySmallScreen ? 12 : 16,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lyrics,
                                    color: onPrimaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Generated Lyrics',
                                      style: TextStyle(
                                        color: onPrimaryColor,
                                        fontSize: isVerySmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.copy,
                                      color: onPrimaryColor,
                                      size: 20,
                                    ),
                                    onPressed: _copyLyrics,
                                    tooltip: 'Copy to Clipboard',
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(
                                  isVerySmallScreen ? 12 : 16,
                                ),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: SelectableText(
                                    _lyrics,
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 14 : 16,
                                      height: 1.5,
                                      color: textColor,
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

                // Extra bottom padding to prevent overflow
                SizedBox(
                  height: keyboardHeight > 0
                      ? 0
                      : (isVerySmallScreen ? 24 : 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
