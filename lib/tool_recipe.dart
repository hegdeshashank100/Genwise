import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'gemini_api.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ToolRecipePage extends StatefulWidget {
  final String initialIngredients;
  const ToolRecipePage({
    super.key,
    this.initialIngredients = 'tomato, rice, spices',
  });

  @override
  State<ToolRecipePage> createState() => _ToolRecipePageState();
}

class Recipe {
  final String name;
  final String difficulty;
  final String prepTime;
  final String cookTime;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> tips;
  final String servings;
  final String cuisine;
  final String calories;

  Recipe({
    required this.name,
    required this.difficulty,
    required this.prepTime,
    required this.cookTime,
    required this.ingredients,
    required this.steps,
    required this.tips,
    required this.servings,
    this.cuisine = '',
    this.calories = '',
  });

  factory Recipe.fromString(String response) {
    try {
      final lines = response.split('\n');
      String name = '';
      String difficulty = 'Medium';
      String prepTime = '';
      String cookTime = '';
      String servings = '2-4';
      String cuisine = '';
      String calories = '';
      List<String> ingredients = [];
      List<String> steps = [];
      List<String> tips = [];

      int section = 0; // 0=none, 1=ingredients, 2=steps, 3=tips

      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        if (line.toLowerCase().contains('recipe:') ||
            line.toLowerCase().contains('name:')) {
          name = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('difficulty:')) {
          difficulty = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('prep time:')) {
          prepTime = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('cook time:')) {
          cookTime = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('servings:')) {
          servings = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('cuisine:')) {
          cuisine = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('calories:')) {
          calories = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('ingredients:')) {
          section = 1;
        } else if (line.toLowerCase().contains('instructions:') ||
            line.toLowerCase().contains('steps:') ||
            line.toLowerCase().contains('directions:')) {
          section = 2;
        } else if (line.toLowerCase().contains('tips:') ||
            line.toLowerCase().contains('notes:')) {
          section = 3;
        } else if (line.startsWith('•') ||
            line.startsWith('-') ||
            line.startsWith('*') ||
            RegExp(r'^\d+[\.|\)]').hasMatch(line)) {
          line = line.replaceFirst(RegExp(r'^[•\-*\d\.).\s]+'), '').trim();
          if (section == 1)
            ingredients.add(line);
          else if (section == 2)
            steps.add(line);
          else if (section == 3)
            tips.add(line);
        }
      }

      return Recipe(
        name: name,
        difficulty: difficulty,
        prepTime: prepTime,
        cookTime: cookTime,
        ingredients: ingredients,
        steps: steps,
        tips: tips,
        servings: servings,
        cuisine: cuisine,
        calories: calories,
      );
    } catch (e) {
      return Recipe(
        name: 'Recipe',
        difficulty: 'Medium',
        prepTime: 'N/A',
        cookTime: 'N/A',
        ingredients: [],
        steps: [],
        tips: [],
        servings: '2-4',
      );
    }
  }

  String toShareableText() {
    String text = '🍽️ $name\n\n';
    if (cuisine.isNotEmpty) text += '🌍 Cuisine: $cuisine\n';
    text += '👥 Serves: $servings\n';
    text += '⏱️ Prep: $prepTime | Cook: $cookTime\n';
    text += '📊 Difficulty: $difficulty\n';
    if (calories.isNotEmpty) text += '🔥 Calories: $calories\n';

    text += '\n📝 INGREDIENTS:\n';
    for (int i = 0; i < ingredients.length; i++) {
      text += '${i + 1}. ${ingredients[i]}\n';
    }

    text += '\n👨‍🍳 INSTRUCTIONS:\n';
    for (int i = 0; i < steps.length; i++) {
      text += '${i + 1}. ${steps[i]}\n';
    }

    if (tips.isNotEmpty) {
      text += '\n💡 TIPS:\n';
      for (String tip in tips) {
        text += '• $tip\n';
      }
    }

    text += '\n🤖 Generated with Recipe Generator';
    return text;
  }
}

class _ToolRecipePageState extends State<ToolRecipePage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ingredientsController;
  Recipe? _recipe;
  bool _loading = false;
  File? _ingredientImage;
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;

  // New features
  String _selectedCuisine = 'Any';
  String _selectedDifficulty = 'Any';
  String _selectedDietType = 'Any';
  int _selectedServings = 4;
  bool _quickRecipe = false;
  List<String> _savedRecipes = [];

  final List<String> _cuisines = [
    'Any',
    'Italian',
    'Chinese',
    'Mexican',
    'Indian',
    'Thai',
    'French',
    'Japanese',
    'Mediterranean',
    'American',
    'Korean',
    'Vietnamese',
  ];

  final List<String> _difficulties = ['Any', 'Easy', 'Medium', 'Hard'];
  final List<String> _dietTypes = [
    'Any',
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Keto',
    'Low-Carb',
    'High-Protein',
    'Dairy-Free',
    'Paleo',
  ];

  @override
  void initState() {
    super.initState();
    _ingredientsController = TextEditingController(
      text: widget.initialIngredients,
    );
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _ingredientsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImageFromSource(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImageFromSource(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _ingredientImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  Future<void> _generate() async {
    if (_ingredientsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some ingredients')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _recipe = null;
    });

    try {
      String prompt =
          '''Create a detailed recipe using these ingredients: ${_ingredientsController.text}

Requirements:
- Cuisine style: $_selectedCuisine
- Difficulty level: $_selectedDifficulty
- Diet type: $_selectedDietType
- Servings: $_selectedServings people
${_quickRecipe ? '- Quick recipe (under 30 minutes)' : ''}

Please include:
1. Recipe name
2. Cuisine type
3. Prep time and cook time
4. Estimated calories per serving
5. Ingredients with exact measurements
6. Step by step instructions
7. Cooking tips and variations
8. Nutritional benefits (if applicable)''';

      final res = await GeminiApi.callGemini(prompt: prompt);

      setState(() {
        _recipe = Recipe.fromString(res);
        _loading = false;
        _tabController.index = 0;
      });
    } catch (e) {
      setState(() {
        _recipe = null;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _shareRecipe() {
    if (_recipe != null) {
      Share.share(_recipe!.toShareableText());
    }
  }

  void _copyRecipe() {
    if (_recipe != null) {
      Clipboard.setData(ClipboardData(text: _recipe!.toShareableText()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe copied to clipboard!')),
      );
    }
  }

  void _saveRecipe() {
    if (_recipe != null) {
      setState(() {
        _savedRecipes.add(_recipe!.toShareableText());
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recipe saved locally!')));
    }
  }

  void _clearIngredients() {
    _ingredientsController.clear();
  }

  void _addCommonIngredients(List<String> ingredients) {
    String current = _ingredientsController.text;
    String addition = ingredients.join(', ');
    _ingredientsController.text = current.isEmpty
        ? addition
        : '$current, $addition';
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipe Preferences',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Cuisine Selection
            DropdownButtonFormField<String>(
              value: _selectedCuisine,
              decoration: InputDecoration(
                labelText: 'Cuisine Style',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                prefixIcon: const Icon(Icons.restaurant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              items: _cuisines
                  .map(
                    (cuisine) =>
                        DropdownMenuItem(value: cuisine, child: Text(cuisine)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCuisine = value!),
            ),
            const SizedBox(height: 20),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Difficulty
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: _selectedDifficulty,
                      decoration: InputDecoration(
                        labelText: 'Difficulty',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        prefixIcon: const Icon(Icons.speed),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      items: _difficulties
                          .map(
                            (diff) => DropdownMenuItem(
                              value: diff,
                              child: Text(diff),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedDifficulty = value!),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Servings
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      initialValue: _selectedServings.toString(),
                      decoration: InputDecoration(
                        labelText: 'Servings',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        prefixIcon: const Icon(Icons.people),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          _selectedServings = int.tryParse(value) ?? 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Diet Type
            DropdownButtonFormField<String>(
              value: _selectedDietType,
              decoration: InputDecoration(
                labelText: 'Dietary Preferences',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                prefixIcon: const Icon(Icons.eco),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              items: _dietTypes
                  .map(
                    (diet) => DropdownMenuItem(value: diet, child: Text(diet)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedDietType = value!),
            ),
            const SizedBox(height: 20),

            // Quick Recipe Toggle
            SwitchListTile(
              title: const Text('Quick Recipe (Under 30 min)'),
              subtitle: const Text('Generate faster cooking recipes'),
              value: _quickRecipe,
              onChanged: (value) => setState(() => _quickRecipe = value),
              secondary: const Icon(Icons.timer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickIngredientsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Add Ingredients',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildIngredientChip('Vegetables', [
                  'onions',
                  'tomatoes',
                  'carrots',
                  'peppers',
                ]),
                _buildIngredientChip('Proteins', [
                  'chicken',
                  'beef',
                  'fish',
                  'eggs',
                ]),
                _buildIngredientChip('Grains', [
                  'rice',
                  'pasta',
                  'bread',
                  'quinoa',
                ]),
                _buildIngredientChip('Dairy', [
                  'milk',
                  'cheese',
                  'butter',
                  'yogurt',
                ]),
                _buildIngredientChip('Spices', [
                  'salt',
                  'pepper',
                  'garlic',
                  'ginger',
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientChip(String category, List<String> ingredients) {
    return ActionChip(
      label: Text(category),
      onPressed: () => _addCommonIngredients(ingredients),
      avatar: const Icon(Icons.add, size: 16),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fastfood, size: 68, color: theme.colorScheme.secondary),
          const SizedBox(height: 16),
          Text(
            'Ready to cook something amazing?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add ingredients, set your preferences, and let AI create the perfect recipe for you!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Add Photo'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 22,
                  ),
                ),
                onPressed: _pickImage,
              ),
            ),
            if (_ingredientImage != null) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 22,
                  ),
                ),
                onPressed: () => setState(() => _ingredientImage = null),
              ),
            ],
          ],
        ),
        if (_ingredientImage != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              _ingredientImage!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSavedRecipesTab() {
    return _savedRecipes.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No saved recipes yet'),
                Text('Generate and save recipes to see them here'),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _savedRecipes.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('Saved Recipe ${index + 1}'),
                  subtitle: Text(
                    _savedRecipes[index]
                        .split('\n')
                        .first
                        .replaceAll('🍽️ ', ''),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _savedRecipes.removeAt(index);
                      });
                    },
                  ),
                  onTap: () {
                    Share.share(_savedRecipes[index]);
                  },
                ),
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Generator'),
        elevation: 0,
        backgroundColor: theme.cardColor,
        actions: [
          if (_recipe != null)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: const Row(
                    children: [
                      Icon(Icons.share),
                      SizedBox(width: 8),
                      Text('Share Recipe'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: const Row(
                    children: [
                      Icon(Icons.copy),
                      SizedBox(width: 8),
                      Text('Copy Recipe'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'save',
                  child: const Row(
                    children: [
                      Icon(Icons.bookmark),
                      SizedBox(width: 8),
                      Text('Save Recipe'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'share':
                    _shareRecipe();
                    break;
                  case 'copy':
                    _copyRecipe();
                    break;
                  case 'save':
                    _saveRecipe();
                    break;
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick Add Ingredients
              _buildQuickIngredientsSection(),
              const SizedBox(height: 16),

              // Main Input Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Your Ingredients',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear'),
                            onPressed: _clearIngredients,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      TextField(
                        controller: _ingredientsController,
                        minLines: 2,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText:
                              'e.g., chicken breast, broccoli, garlic, olive oil...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          fillColor: theme.cardColor.withOpacity(0.05),
                          filled: true,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 13),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _loading
                            ? ElevatedButton(
                                key: const ValueKey(1),
                                onPressed: null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Creating your recipe...'),
                                  ],
                                ),
                              )
                            : ElevatedButton.icon(
                                key: const ValueKey(2),
                                onPressed: _generate,
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Generate Recipe'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filter Section
              _buildFilterSection(),
              const SizedBox(height: 16),

              // Results Section
              SizedBox(
                height: 600,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _recipe == null && !_loading
                      ? _buildEmptyState(context)
                      : Column(
                          children: [
                            Container(
                              color: theme.colorScheme.surfaceVariant,
                              child: TabBar(
                                controller: _tabController,
                                labelColor: theme.colorScheme.primary,
                                unselectedLabelColor:
                                    theme.colorScheme.onSurface,
                                isScrollable: true,
                                indicator: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                ),
                                tabs: const [
                                  Tab(
                                    icon: Icon(Icons.restaurant_menu),
                                    text: 'Recipe',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.format_list_numbered),
                                    text: 'Steps',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.lightbulb_outline),
                                    text: 'Tips',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.photo_camera),
                                    text: 'Photo',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.bookmark),
                                    text: 'Saved',
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // Recipe Overview Tab
                                  _recipe == null
                                      ? const SizedBox()
                                      : SingleChildScrollView(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _recipe!.name,
                                                style: theme
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 12),
                                              // Recipe Info Cards
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _buildInfoChip(
                                                    Icons.public,
                                                    'Cuisine',
                                                    _recipe!.cuisine.isEmpty
                                                        ? 'Mixed'
                                                        : _recipe!.cuisine,
                                                  ),
                                                  _buildInfoChip(
                                                    Icons.schedule,
                                                    'Prep',
                                                    _recipe!.prepTime,
                                                  ),
                                                  _buildInfoChip(
                                                    Icons.timer,
                                                    'Cook',
                                                    _recipe!.cookTime,
                                                  ),
                                                  _buildInfoChip(
                                                    Icons.people,
                                                    'Serves',
                                                    _recipe!.servings,
                                                  ),
                                                  _buildInfoChip(
                                                    Icons.speed,
                                                    'Level',
                                                    _recipe!.difficulty,
                                                  ),
                                                  if (_recipe!
                                                      .calories
                                                      .isNotEmpty)
                                                    _buildInfoChip(
                                                      Icons
                                                          .local_fire_department,
                                                      'Calories',
                                                      _recipe!.calories,
                                                    ),
                                                ],
                                              ),
                                              const Divider(height: 24),
                                              Text(
                                                'Ingredients',
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              ...(_recipe!.ingredients.isEmpty
                                                  ? [
                                                      const Text(
                                                        'No ingredients found.',
                                                      ),
                                                    ]
                                                  : _recipe!.ingredients.asMap().entries.map(
                                                      (entry) => Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 6,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .surface,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade200,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              width: 24,
                                                              height: 24,
                                                              decoration: BoxDecoration(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  '${entry.key + 1}',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                entry.value,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )),
                                            ],
                                          ),
                                        ),

                                  // Steps Tab
                                  _recipe == null
                                      ? const SizedBox()
                                      : SingleChildScrollView(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Cooking Instructions',
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 12),
                                              ...(_recipe!.steps.isEmpty
                                                  ? [
                                                      const Text(
                                                        'No instructions provided.',
                                                      ),
                                                    ]
                                                  : _recipe!.steps.asMap().entries.map(
                                                      (entry) => Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 16,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .surface,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade200,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Container(
                                                              width: 32,
                                                              height: 32,
                                                              decoration: BoxDecoration(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  '${entry.key + 1}',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 16,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                entry.value,
                                                                style: theme
                                                                    .textTheme
                                                                    .bodyMedium,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )),
                                            ],
                                          ),
                                        ),

                                  // Tips Tab
                                  _recipe == null
                                      ? const SizedBox()
                                      : SingleChildScrollView(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Pro Tips & Notes',
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 12),
                                              ...(_recipe!.tips.isEmpty
                                                  ? [
                                                      const Text(
                                                        'No tips available.',
                                                      ),
                                                    ]
                                                  : _recipe!.tips.map(
                                                      (tip) => Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 12,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .amber
                                                              .shade50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .amber
                                                                .shade200,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Icon(
                                                              Icons.lightbulb,
                                                              color: Colors
                                                                  .amber
                                                                  .shade700,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(tip),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )),
                                            ],
                                          ),
                                        ),

                                  // Photo Tab
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: _buildImageSection(context),
                                  ),

                                  // Saved Recipes Tab
                                  _buildSavedRecipesTab(),
                                ],
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

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text('$label: $value', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
