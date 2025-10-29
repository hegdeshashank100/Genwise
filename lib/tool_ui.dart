import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gemini_api.dart';
import 'dart:math' as math;

class ToolUIPage extends StatefulWidget {
  const ToolUIPage({super.key});

  @override
  State<ToolUIPage> createState() => _ToolUIPageState();
}

class UIComponent {
  final String type;
  final String label;
  final IconData icon;
  final Color color;
  final Size defaultSize;
  final Map<String, dynamic> properties;

  const UIComponent({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.defaultSize,
    Map<String, dynamic>? properties,
  }) : properties = properties ?? const {};
}

class LayoutItem {
  final String id;
  final UIComponent component;
  Offset position;
  Size size;
  String customText;
  Color backgroundColor;
  Color textColor;
  double borderRadius;
  double fontSize;
  double opacity;
  bool isBold;
  bool isItalic;
  TextAlign textAlign;
  bool isLocked;
  bool isVisible;
  int layer;
  double rotation;
  EdgeInsets padding;
  EdgeInsets margin;
  BoxShadow? shadow;

  LayoutItem({
    required this.id,
    required this.component,
    this.position = const Offset(50, 50),
    Size? size,
    this.customText = '',
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black,
    this.borderRadius = 8.0,
    this.fontSize = 16.0,
    this.opacity = 1.0,
    this.isBold = false,
    this.isItalic = false,
    this.textAlign = TextAlign.left,
    this.isLocked = false,
    this.isVisible = true,
    this.layer = 0,
    this.rotation = 0.0,
    this.padding = const EdgeInsets.all(8),
    this.margin = EdgeInsets.zero,
    this.shadow,
  }) : size = size ?? component.defaultSize;

  LayoutItem copyWith({
    String? id,
    UIComponent? component,
    Offset? position,
    Size? size,
    String? customText,
    Color? backgroundColor,
    Color? textColor,
    double? borderRadius,
    double? fontSize,
    double? opacity,
    bool? isBold,
    bool? isItalic,
    TextAlign? textAlign,
    bool? isLocked,
    bool? isVisible,
    int? layer,
    double? rotation,
    EdgeInsets? padding,
    EdgeInsets? margin,
    BoxShadow? shadow,
  }) {
    return LayoutItem(
      id: id ?? this.id,
      component: component ?? this.component,
      position: position ?? this.position,
      size: size ?? this.size,
      customText: customText ?? this.customText,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      borderRadius: borderRadius ?? this.borderRadius,
      fontSize: fontSize ?? this.fontSize,
      opacity: opacity ?? this.opacity,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      textAlign: textAlign ?? this.textAlign,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      layer: layer ?? this.layer,
      rotation: rotation ?? this.rotation,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      shadow: shadow ?? this.shadow,
    );
  }
}

class DeviceTemplate {
  final String name;
  final String description;
  final double width;
  final double height;
  final IconData icon;
  final Color color;

  const DeviceTemplate({
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.icon,
    required this.color,
  });
}

class _ToolUIPageState extends State<ToolUIPage> with TickerProviderStateMixin {
  List<LayoutItem> _layoutItems = [];
  LayoutItem? _selectedItem;
  List<LayoutItem> _selectedItems = [];
  late AnimationController _animationController;
  String _generatedCode = '';
  bool _loading = false;
  bool _showGrid = true;
  bool _snapToGrid = true;
  double _canvasWidth = 375.0;
  double _canvasHeight = 667.0;
  double _gridSize = 20.0;
  String _searchQuery = '';
  List<List<LayoutItem>> _history = [];
  int _historyIndex = -1;
  bool _multiSelectMode = false;
  Offset? _selectionStart;
  Offset? _selectionEnd;

  // **ENHANCED CANVAS LOCK SYSTEM**
  bool _canvasLocked = false;
  bool _showResizeHandles = true;
  bool _precisionMode = false;
  double _moveStep = 1.0; // Pixel step for precision movement

  // **PERFORMANCE OPTIMIZATION: Reuse TextEditingControllers**
  late final TextEditingController _searchController;
  late final TextEditingController _canvasWidthController;
  late final TextEditingController _canvasHeightController;
  late final TextEditingController _contentController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // **PERFORMANCE: Cache filtered components**
  List<UIComponent>? _cachedFilteredComponents;
  String _lastSearchQuery = '';

  // **COMPREHENSIVE UI COMPONENTS LIBRARY**
  static const List<UIComponent> _uiComponents = [
    // Text Components
    UIComponent(
      type: 'header',
      label: 'Header H1',
      icon: Icons.title,
      color: Color(0xFF3B82F6),
      defaultSize: Size(240, 50),
      properties: {'text': 'Main Header', 'tag': 'h1', 'semantic': true},
    ),
    UIComponent(
      type: 'subheader',
      label: 'Header H2',
      icon: Icons.subtitles,
      color: Color(0xFF6366F1),
      defaultSize: Size(200, 40),
      properties: {'text': 'Subheader', 'tag': 'h2', 'semantic': true},
    ),
    UIComponent(
      type: 'h3',
      label: 'Header H3',
      icon: Icons.format_size,
      color: Color(0xFF8B5CF6),
      defaultSize: Size(180, 35),
      properties: {'text': 'Section Header', 'tag': 'h3', 'semantic': true},
    ),
    UIComponent(
      type: 'paragraph',
      label: 'Paragraph',
      icon: Icons.text_fields,
      color: Color(0xFF6B7280),
      defaultSize: Size(200, 60),
      properties: {
        'text':
            'This is a paragraph of text content that can wrap to multiple lines.',
        'tag': 'p',
        'semantic': true,
      },
    ),
    UIComponent(
      type: 'label',
      label: 'Label',
      icon: Icons.label,
      color: Color(0xFF9CA3AF),
      defaultSize: Size(120, 25),
      properties: {'text': 'Label Text', 'tag': 'label', 'semantic': true},
    ),

    // Form Components
    UIComponent(
      type: 'button',
      label: 'Button',
      icon: Icons.smart_button,
      color: Color(0xFF10B981),
      defaultSize: Size(120, 40),
      properties: {'text': 'Click Me', 'tag': 'button', 'interactive': true},
    ),
    UIComponent(
      type: 'input',
      label: 'Text Input',
      icon: Icons.input,
      color: Color(0xFFF59E0B),
      defaultSize: Size(220, 40),
      properties: {
        'text': 'Enter text...',
        'tag': 'input',
        'interactive': true,
      },
    ),
    UIComponent(
      type: 'textarea',
      label: 'Text Area',
      icon: Icons.notes,
      color: Color(0xFFEF4444),
      defaultSize: Size(240, 100),
      properties: {
        'text': 'Multi-line text...',
        'tag': 'textarea',
        'interactive': true,
      },
    ),
    UIComponent(
      type: 'select',
      label: 'Select Dropdown',
      icon: Icons.arrow_drop_down_circle,
      color: Color(0xFF8B5CF6),
      defaultSize: Size(180, 40),
      properties: {
        'text': 'Choose option',
        'tag': 'select',
        'interactive': true,
      },
    ),
    UIComponent(
      type: 'checkbox',
      label: 'Checkbox',
      icon: Icons.check_box,
      color: Color(0xFF06B6D4),
      defaultSize: Size(120, 30),
      properties: {'text': 'Check me', 'tag': 'input', 'interactive': true},
    ),
    UIComponent(
      type: 'radio',
      label: 'Radio Button',
      icon: Icons.radio_button_checked,
      color: Color(0xFFF59E0B),
      defaultSize: Size(120, 30),
      properties: {
        'text': 'Select option',
        'tag': 'input',
        'interactive': true,
      },
    ),

    // Layout Components
    UIComponent(
      type: 'container',
      label: 'Container',
      icon: Icons.crop_square,
      color: Color(0xFF8B5CF6),
      defaultSize: Size(200, 120),
      properties: {'text': 'Container', 'tag': 'div', 'layout': true},
    ),
    UIComponent(
      type: 'card',
      label: 'Card',
      icon: Icons.card_membership,
      color: Color(0xFFA855F7),
      defaultSize: Size(240, 160),
      properties: {'text': 'Card Component', 'tag': 'div', 'layout': true},
    ),
    UIComponent(
      type: 'panel',
      label: 'Panel',
      icon: Icons.dashboard,
      color: Color(0xFF6366F1),
      defaultSize: Size(280, 200),
      properties: {'text': 'Panel', 'tag': 'section', 'layout': true},
    ),

    // Media Components
    UIComponent(
      type: 'image',
      label: 'Image',
      icon: Icons.image,
      color: Color(0xFF06B6D4),
      defaultSize: Size(160, 120),
      properties: {'text': 'Image', 'tag': 'img', 'media': true},
    ),
    UIComponent(
      type: 'video',
      label: 'Video',
      icon: Icons.video_library,
      color: Color(0xFFEF4444),
      defaultSize: Size(200, 120),
      properties: {'text': 'Video Player', 'tag': 'video', 'media': true},
    ),
    UIComponent(
      type: 'icon',
      label: 'Icon',
      icon: Icons.star,
      color: Color(0xFFF59E0B),
      defaultSize: Size(40, 40),
      properties: {'text': '★', 'tag': 'i', 'media': true},
    ),

    // Navigation Components
    UIComponent(
      type: 'navbar',
      label: 'Navigation Bar',
      icon: Icons.menu,
      color: Color(0xFF1F2937),
      defaultSize: Size(300, 60),
      properties: {'text': 'Navigation', 'tag': 'nav', 'navigation': true},
    ),
    UIComponent(
      type: 'breadcrumb',
      label: 'Breadcrumb',
      icon: Icons.navigate_next,
      color: Color(0xFF6B7280),
      defaultSize: Size(250, 30),
      properties: {
        'text': 'Home > Page > Section',
        'tag': 'nav',
        'navigation': true,
      },
    ),
    UIComponent(
      type: 'link',
      label: 'Link',
      icon: Icons.link,
      color: Color(0xFF3B82F6),
      defaultSize: Size(100, 25),
      properties: {'text': 'Click here', 'tag': 'a', 'navigation': true},
    ),

    // List Components
    UIComponent(
      type: 'list',
      label: 'Unordered List',
      icon: Icons.list,
      color: Color(0xFFDC2626),
      defaultSize: Size(180, 120),
      properties: {
        'text': '• Item 1\n• Item 2\n• Item 3',
        'tag': 'ul',
        'list': true,
      },
    ),
    UIComponent(
      type: 'ordered_list',
      label: 'Ordered List',
      icon: Icons.format_list_numbered,
      color: Color(0xFFDC2626),
      defaultSize: Size(180, 120),
      properties: {
        'text': '1. First item\n2. Second item\n3. Third item',
        'tag': 'ol',
        'list': true,
      },
    ),
  ];

  // **DEVICE TEMPLATES**
  static const List<DeviceTemplate> _deviceTemplates = [
    DeviceTemplate(
      name: 'iPhone 14',
      description: 'Standard iPhone',
      width: 375.0,
      height: 667.0,
      icon: Icons.phone_iphone,
      color: Color(0xFF3B82F6),
    ),
    DeviceTemplate(
      name: 'iPhone 14 Pro',
      description: 'iPhone Pro',
      width: 393.0,
      height: 852.0,
      icon: Icons.phone_iphone,
      color: Color(0xFF6366F1),
    ),
    DeviceTemplate(
      name: 'Android Phone',
      description: 'Standard Android',
      width: 360.0,
      height: 640.0,
      icon: Icons.phone_android,
      color: Color(0xFF10B981),
    ),
    DeviceTemplate(
      name: 'iPad',
      description: 'Standard iPad',
      width: 768.0,
      height: 1024.0,
      icon: Icons.tablet,
      color: Color(0xFFF59E0B),
    ),
    DeviceTemplate(
      name: 'iPad Pro',
      description: 'Large iPad',
      width: 1024.0,
      height: 1366.0,
      icon: Icons.tablet,
      color: Color(0xFFEF4444),
    ),
    DeviceTemplate(
      name: 'Android Tablet',
      description: 'Android Tablet',
      width: 800.0,
      height: 1280.0,
      icon: Icons.tablet_android,
      color: Color(0xFF8B5CF6),
    ),
    DeviceTemplate(
      name: 'Desktop',
      description: 'Standard Desktop',
      width: 1200.0,
      height: 800.0,
      icon: Icons.desktop_windows,
      color: Color(0xFF06B6D4),
    ),
    DeviceTemplate(
      name: 'Large Desktop',
      description: 'Large Screen',
      width: 1440.0,
      height: 900.0,
      icon: Icons.desktop_mac,
      color: Color(0xFF9CA3AF),
    ),
    DeviceTemplate(
      name: 'Ultrawide',
      description: 'Ultrawide Monitor',
      width: 1920.0,
      height: 1080.0,
      icon: Icons.monitor,
      color: Color(0xFF1F2937),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // **PERFORMANCE: Initialize controllers once**
    _searchController = TextEditingController();
    _canvasWidthController = TextEditingController(
      text: _canvasWidth.toString(),
    );
    _canvasHeightController = TextEditingController(
      text: _canvasHeight.toString(),
    );
    _contentController = TextEditingController();

    _saveToHistory();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _canvasWidthController.dispose();
    _canvasHeightController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // **PERFORMANCE: Cached filtering with debouncing**
  List<UIComponent> get _filteredComponents {
    if (_searchQuery != _lastSearchQuery) {
      _lastSearchQuery = _searchQuery;
      if (_searchQuery.isEmpty) {
        _cachedFilteredComponents = _uiComponents;
      } else {
        _cachedFilteredComponents = _uiComponents
            .where(
              (component) =>
                  component.label.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  component.type.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
            )
            .toList();
      }
    }
    return _cachedFilteredComponents ?? _uiComponents;
  }

  // **OPTIMIZED HISTORY MANAGEMENT**
  void _saveToHistory() {
    final currentState = _layoutItems.map((item) => item.copyWith()).toList();

    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }
    _history.add(currentState);
    if (_history.length > 50) {
      _history.removeAt(0);
    } else {
      _historyIndex++;
    }
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      setState(() {
        _layoutItems = _history[_historyIndex]
            .map((item) => item.copyWith())
            .toList();
        _selectedItem = null;
        _selectedItems.clear();
        _updateContentController();
      });
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      setState(() {
        _layoutItems = _history[_historyIndex]
            .map((item) => item.copyWith())
            .toList();
        _selectedItem = null;
        _selectedItems.clear();
        _updateContentController();
      });
    }
  }

  // **PERFORMANCE: Update controller without rebuild**
  void _updateContentController() {
    if (_selectedItem != null) {
      _contentController.text = _selectedItem!.customText;
    }
  }

  // **COMPONENT MANAGEMENT**
  void _addComponent(UIComponent component) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = LayoutItem(
      id: id,
      component: component,
      position: _snapToGrid
          ? Offset(
              (50.0 + (_layoutItems.length * 30.0)).clamp(
                0,
                _canvasWidth - component.defaultSize.width,
              ),
              (50.0 + (_layoutItems.length * 30.0)).clamp(
                0,
                _canvasHeight - component.defaultSize.height,
              ),
            )
          : Offset(
              (50.0 + (_layoutItems.length * 25.0)).clamp(
                0,
                _canvasWidth - component.defaultSize.width,
              ),
              (50.0 + (_layoutItems.length * 25.0)).clamp(
                0,
                _canvasHeight - component.defaultSize.height,
              ),
            ),
      size: component.defaultSize,
      customText: component.properties['text']?.toString() ?? component.label,
      layer: _layoutItems.length,
    );

    setState(() {
      _layoutItems.add(item);
      _selectedItem = item;
      _selectedItems = [item];
      _updateContentController();
    });
    _saveToHistory();
  }

  void _deleteSelectedItems() {
    if (_selectedItems.isNotEmpty) {
      final itemsToDelete = _selectedItems
          .where((item) => !item.isLocked)
          .toList();
      setState(() {
        for (final item in itemsToDelete) {
          _layoutItems.removeWhere((layoutItem) => layoutItem.id == item.id);
        }
        _selectedItem = null;
        _selectedItems.clear();
        _contentController.clear();
      });
      _saveToHistory();
    }
  }

  void _duplicateSelectedItems() {
    if (_selectedItems.isNotEmpty) {
      final newItems = <LayoutItem>[];
      for (final selectedItem in _selectedItems) {
        final newItem = selectedItem.copyWith(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              newItems.length.toString(),
          position: Offset(
            (selectedItem.position.dx + 20).clamp(
              0,
              _canvasWidth - selectedItem.size.width,
            ),
            (selectedItem.position.dy + 20).clamp(
              0,
              _canvasHeight - selectedItem.size.height,
            ),
          ),
          layer: _layoutItems.length + newItems.length,
        );
        newItems.add(newItem);
      }

      setState(() {
        _layoutItems.addAll(newItems);
        _selectedItems = newItems;
        _selectedItem = newItems.isNotEmpty ? newItems.first : null;
        _updateContentController();
      });
      _saveToHistory();
    }
  }

  void _clearCanvas() {
    setState(() {
      _layoutItems.clear();
      _selectedItem = null;
      _selectedItems.clear();
      _generatedCode = '';
      _contentController.clear();
    });
    _saveToHistory();
  }

  void _lockSelectedItems() {
    if (_selectedItems.isNotEmpty) {
      setState(() {
        for (final item in _selectedItems) {
          item.isLocked = !item.isLocked;
        }
      });
      _saveToHistory();
    }
  }

  // **ENHANCED CANVAS LOCK SYSTEM**
  void _toggleCanvasLock() {
    setState(() {
      _canvasLocked = !_canvasLocked;
      // When canvas is locked, enable precision mode for better component editing
      if (_canvasLocked) {
        _precisionMode = true;
        _showResizeHandles = true;
        _moveStep = 1.0; // Precise pixel movement
      } else {
        _precisionMode = false;
        _moveStep = 10.0; // Normal movement
      }
    });

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _canvasLocked ? Icons.lock : Icons.lock_open,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _canvasLocked
                  ? 'Canvas Locked - Components can be freely moved and resized'
                  : 'Canvas Unlocked - Normal interaction mode',
            ),
          ],
        ),
        backgroundColor: _canvasLocked ? Colors.green : Colors.blue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _togglePrecisionMode() {
    setState(() {
      _precisionMode = !_precisionMode;
      _moveStep = _precisionMode ? 1.0 : 10.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _precisionMode ? Icons.straighten : Icons.open_with,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _precisionMode
                  ? 'Precision Mode ON - 1px movement steps'
                  : 'Precision Mode OFF - 10px movement steps',
            ),
          ],
        ),
        backgroundColor: _precisionMode ? Colors.purple : Colors.orange,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleResizeHandles() {
    setState(() {
      _showResizeHandles = !_showResizeHandles;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _showResizeHandles ? Icons.crop_square : Icons.visibility_off,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _showResizeHandles
                  ? 'Resize Handles Visible'
                  : 'Resize Handles Hidden',
            ),
          ],
        ),
        backgroundColor: _showResizeHandles ? Colors.green : Colors.grey,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // **ENHANCED COMPONENT MOVEMENT WITH PRECISION**
  void _moveSelectedItems(Offset delta) {
    if (_selectedItems.isEmpty) return;

    setState(() {
      for (final item in _selectedItems) {
        if (!item.isLocked) {
          final newPosition = Offset(
            (item.position.dx + delta.dx).clamp(
              0.0,
              _canvasWidth - item.size.width,
            ),
            (item.position.dy + delta.dy).clamp(
              0.0,
              _canvasHeight - item.size.height,
            ),
          );

          item.position = _snapToGrid && !_precisionMode
              ? _snapToGridIfEnabled(newPosition)
              : newPosition;
        }
      }
    });
    _saveToHistory();
  }

  // **KEYBOARD-BASED COMPONENT MOVEMENT**
  void _moveSelectedItemsWithKeyboard(String direction) {
    if (_selectedItems.isEmpty) return;

    Offset delta = Offset.zero;
    switch (direction) {
      case 'up':
        delta = Offset(0, -_moveStep);
        break;
      case 'down':
        delta = Offset(0, _moveStep);
        break;
      case 'left':
        delta = Offset(-_moveStep, 0);
        break;
      case 'right':
        delta = Offset(_moveStep, 0);
        break;
    }

    _moveSelectedItems(delta);
  }

  void _bringToFront() {
    if (_selectedItems.isNotEmpty) {
      setState(() {
        final maxLayer = _layoutItems
            .map((item) => item.layer)
            .fold(0, math.max);
        for (int i = 0; i < _selectedItems.length; i++) {
          _selectedItems[i].layer = maxLayer + i + 1;
        }
      });
      _saveToHistory();
    }
  }

  void _sendToBack() {
    if (_selectedItems.isNotEmpty) {
      setState(() {
        final minLayer = _layoutItems
            .map((item) => item.layer)
            .fold(0, math.min);
        for (int i = 0; i < _selectedItems.length; i++) {
          _selectedItems[i].layer = minLayer - _selectedItems.length + i;
        }
      });
      _saveToHistory();
    }
  }

  // **DEVICE TEMPLATE MANAGEMENT**
  void _setDeviceTemplate(DeviceTemplate template) {
    setState(() {
      _canvasWidth = template.width;
      _canvasHeight = template.height;
      _canvasWidthController.text = template.width.toString();
      _canvasHeightController.text = template.height.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(template.icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Canvas set to ${template.name} (${template.width.round()}×${template.height.round()})',
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: template.color,
      ),
    );
  }

  void _setCustomCanvasSize() {
    final width = double.tryParse(_canvasWidthController.text);
    final height = double.tryParse(_canvasHeightController.text);

    if (width != null && height != null && width > 0 && height > 0) {
      setState(() {
        _canvasWidth = width;
        _canvasHeight = height;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canvas size updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid dimensions'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // **ADVANCED CODE GENERATION**
  Future<void> _generateCodeWithAI() async {
    if (_layoutItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please add components to your design first'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _generatedCode = '';
    });

    try {
      String componentSpecs = '';
      final sortedItems = List<LayoutItem>.from(_layoutItems)
        ..sort((a, b) => a.layer.compareTo(b.layer));

      for (int i = 0; i < sortedItems.length; i++) {
        final item = sortedItems[i];
        if (!item.isVisible) continue;

        componentSpecs +=
            '''
Component ${i + 1} (${item.component.type.toUpperCase()}):
- HTML Tag: ${item.component.properties['tag'] ?? 'div'}
- Position: left: ${item.position.dx.round()}px, top: ${item.position.dy.round()}px
- Dimensions: width: ${item.size.width.round()}px, height: ${item.size.height.round()}px
- Text Content: "${item.customText}"
- Background: ${_colorToHex(item.backgroundColor)}
- Text Color: ${_colorToHex(item.textColor)}
- Font Size: ${item.fontSize.round()}px
- Font Weight: ${item.isBold ? 'bold' : 'normal'}
- Font Style: ${item.isItalic ? 'italic' : 'normal'}
- Text Align: ${item.textAlign.name}
- Border Radius: ${item.borderRadius.round()}px
- Opacity: ${item.opacity.toStringAsFixed(2)}
- Z-Index: ${item.layer}
- Rotation: ${item.rotation.round()}deg
- Padding: ${item.padding.top}px ${item.padding.right}px ${item.padding.bottom}px ${item.padding.left}px
- Margin: ${item.margin.top}px ${item.margin.right}px ${item.margin.bottom}px ${item.margin.left}px
${item.shadow != null ? '- Box Shadow: ${item.shadow!.offset.dx}px ${item.shadow!.offset.dy}px ${item.shadow!.blurRadius}px ${_colorToHex(item.shadow!.color)}' : ''}

''';
      }

      String prompt =
          '''You are a senior full-stack developer specializing in modern web development. Generate PIXEL-PERFECT, production-ready HTML/CSS code that EXACTLY replicates this UI design with 100% accuracy.

CANVAS SPECIFICATIONS:
- Container Dimensions: ${_canvasWidth.round()}px × ${_canvasHeight.round()}px
- Total Components: ${sortedItems.where((item) => item.isVisible).length}

COMPONENT SPECIFICATIONS (in layer order):
$componentSpecs

TECHNICAL REQUIREMENTS:
1. Use CSS Grid or Flexbox for responsive layouts where appropriate
2. Implement absolute positioning for precise component placement
3. Use semantic HTML5 tags as specified for each component
4. Include proper accessibility attributes (ARIA labels, alt text, etc.)
5. Add CSS custom properties for maintainable styling
6. Implement CSS transitions for interactive elements
7. Use modern CSS features (CSS Grid, Flexbox, CSS Variables)
8. Ensure cross-browser compatibility (Chrome, Firefox, Safari, Edge)
9. Add responsive design principles with proper breakpoints
10. Include proper meta tags and viewport settings
11. Use BEM methodology for CSS class naming
12. Add proper form validation for interactive elements
13. Implement proper focus states for accessibility
14. Use CSS transforms for rotated elements
15. Add box-shadow effects as specified

OUTPUT FORMAT:
- Complete HTML document with embedded CSS
- Include DOCTYPE, proper HTML5 structure
- Add viewport meta tag for mobile responsiveness
- Use external font imports if needed (Google Fonts)
- Include CSS reset/normalize styles
- Add comments for code sections
- Ensure W3C HTML/CSS validation compliance

DESIGN ACCURACY:
The generated code must be PIXEL-PERFECT - every position, size, color, and styling property must match exactly as specified. This is critical for design fidelity.''';

      final response = await GeminiApi.callGemini(prompt: prompt);

      setState(() {
        _generatedCode = response;
        _loading = false;
      });
      _animationController.forward();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Code generated successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error generating code: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  void _copyCode() {
    if (_generatedCode.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _generatedCode));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.content_copy, color: Colors.white),
              SizedBox(width: 8),
              Text('Code copied to clipboard successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // **GRID UTILITIES**
  Offset _snapToGridIfEnabled(Offset position) {
    if (!_snapToGrid) return position;

    final snappedX = (position.dx / _gridSize).round() * _gridSize;
    final snappedY = (position.dy / _gridSize).round() * _gridSize;

    return Offset(snappedX.toDouble(), snappedY.toDouble());
  }

  // **ENHANCED KEYBOARD SHORTCUTS WITH CANVAS LOCK SUPPORT**
  void _handleKeyEvent(RawKeyEvent event) {
    if (event.runtimeType == RawKeyDownEvent) {
      final isCtrlPressed = event.isControlPressed;
      final isShiftPressed = event.isShiftPressed;

      if (isCtrlPressed) {
        switch (event.logicalKey.keyLabel) {
          case 'z':
            if (isShiftPressed) {
              _redo();
            } else {
              _undo();
            }
            break;
          case 'd':
            _duplicateSelectedItems();
            break;
          case 'l':
            _toggleCanvasLock(); // Ctrl+L to toggle canvas lock
            break;
          case 'p':
            _togglePrecisionMode(); // Ctrl+P for precision mode
            break;
          case 'h':
            _toggleResizeHandles(); // Ctrl+H to toggle resize handles
            break;
        }
      } else {
        switch (event.logicalKey.keyLabel) {
          case 'Delete':
            _deleteSelectedItems();
            break;
          case 'Escape':
            setState(() {
              _selectedItem = null;
              _selectedItems.clear();
              _contentController.clear();
            });
            break;
          // **ENHANCED: Arrow key movement with precision support**
          case 'Arrow Up':
            _moveSelectedItemsWithKeyboard('up');
            break;
          case 'Arrow Down':
            _moveSelectedItemsWithKeyboard('down');
            break;
          case 'Arrow Left':
            _moveSelectedItemsWithKeyboard('left');
            break;
          case 'Arrow Right':
            _moveSelectedItemsWithKeyboard('right');
            break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // 🎨 Dynamic Colors Based on Theme
    final backgroundColor = isDark ? colorScheme.background : Colors.grey[50];

    final screenWidth = MediaQuery.of(context).size.width;

    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyEvent,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: true, // ENHANCED: Enable keyboard handling
        appBar: _buildAppBar(),
        drawer: screenWidth <= 1200 ? _buildComponentDrawer() : null,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return screenWidth > 1200
                  ? _buildDesktopLayout()
                  : _buildMobileLayout();
            },
          ),
        ),
        floatingActionButton: _buildFloatingButtons(),
        floatingActionButtonLocation:
            MediaQuery.of(context).size.shortestSide >= 600
            ? FloatingActionButtonLocation.endFloat
            : FloatingActionButtonLocation.endDocked,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI UI Designer Pro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Professional Design Tool',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Undo/Redo
        IconButton(
          icon: Icon(
            Icons.undo,
            color: _historyIndex > 0
                ? colorScheme.primary
                : (isDark ? Colors.grey[600] : Colors.grey),
            size: 20,
          ),
          tooltip: 'Undo (Ctrl+Z)',
          onPressed: _historyIndex > 0 ? _undo : null,
        ),
        IconButton(
          icon: Icon(
            Icons.redo,
            color: _historyIndex < _history.length - 1
                ? colorScheme.primary
                : (isDark ? Colors.grey[600] : Colors.grey),
            size: 20,
          ),
          tooltip: 'Redo (Ctrl+Shift+Z)',
          onPressed: _historyIndex < _history.length - 1 ? _redo : null,
        ),
        const SizedBox(width: 8),

        // **ENHANCED CANVAS LOCK CONTROLS**
        // Canvas Lock Toggle
        IconButton(
          icon: Icon(
            _canvasLocked ? Icons.lock : Icons.lock_open,
            color: _canvasLocked ? Colors.green : colorScheme.primary,
            size: 22,
          ),
          tooltip:
              'Toggle Canvas Lock (Ctrl+L)\n${_canvasLocked ? "Locked: Easy component editing" : "Unlocked: Normal mode"}',
          onPressed: _toggleCanvasLock,
        ),

        // Precision Mode Toggle
        IconButton(
          icon: Icon(
            _precisionMode ? Icons.straighten : Icons.open_with,
            color: _precisionMode ? Colors.purple : colorScheme.primary,
            size: 20,
          ),
          tooltip:
              'Precision Mode (Ctrl+P)\n${_precisionMode ? "1px steps" : "10px steps"}',
          onPressed: _togglePrecisionMode,
        ),

        // Resize Handles Toggle
        IconButton(
          icon: Icon(
            _showResizeHandles ? Icons.crop_square : Icons.visibility_off,
            color: _showResizeHandles ? colorScheme.primary : Colors.grey,
            size: 20,
          ),
          tooltip: 'Toggle Resize Handles (Ctrl+H)',
          onPressed: _toggleResizeHandles,
        ),

        const SizedBox(width: 8),

        // Device Templates
        PopupMenuButton<DeviceTemplate>(
          icon: Icon(Icons.devices, color: colorScheme.primary, size: 22),
          tooltip: 'Device Templates',
          onSelected: _setDeviceTemplate,
          itemBuilder: (context) => _deviceTemplates
              .map(
                (template) => PopupMenuItem(
                  value: template,
                  child: SizedBox(
                    width: 280,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: template.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              template.icon,
                              color: template.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${template.width.round()}×${template.height.round()} • ${template.description}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
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
              )
              .toList(),
        ),

        // Canvas Settings
        IconButton(
          icon: Icon(Icons.settings, color: colorScheme.primary, size: 20),
          tooltip: 'Canvas Settings',
          onPressed: _showCanvasSettings,
        ),

        // Grid Toggle
        IconButton(
          icon: Icon(
            _showGrid ? Icons.grid_on : Icons.grid_off,
            color: colorScheme.primary,
            size: 20,
          ),
          tooltip: 'Toggle Grid',
          onPressed: () => setState(() => _showGrid = !_showGrid),
        ),

        // Snap to Grid Toggle
        IconButton(
          icon: Icon(
            _snapToGrid ? Icons.grid_3x3 : Icons.grid_off,
            color: _snapToGrid
                ? Colors.green
                : (isDark ? Colors.grey[600] : Colors.grey),
            size: 20,
          ),
          tooltip: 'Snap to Grid',
          onPressed: () => setState(() => _snapToGrid = !_snapToGrid),
        ),

        // Clear Canvas
        IconButton(
          icon: const Icon(Icons.clear_all, color: Colors.red, size: 20),
          tooltip: 'Clear Canvas',
          onPressed: _confirmClearCanvas,
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  void _showCanvasSettings() {
    // 🌙 Theme Detection
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Canvas Settings',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _canvasWidthController,
                      decoration: const InputDecoration(
                        labelText: 'Width (px)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _canvasHeightController,
                      decoration: const InputDecoration(
                        labelText: 'Height (px)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Grid Size:',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value: _gridSize,
                      min: 10,
                      max: 50,
                      divisions: 8,
                      label: '${_gridSize.round()}px',
                      onChanged: (value) => setState(() => _gridSize = value),
                      activeColor: colorScheme.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_gridSize.round()}px',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              _setCustomCanvasSize();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _confirmClearCanvas() {
    if (_layoutItems.isNotEmpty) {
      // 🌙 Theme Detection
      final colorScheme = Theme.of(context).colorScheme;
      final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: Colors.orange,
                    size: isTablet ? 28 : 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Clear Canvas',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              content: Container(
                constraints: BoxConstraints(maxWidth: isTablet ? 400 : 300),
                child: Text(
                  'Are you sure you want to remove all components? This action cannot be undone.',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: isTablet ? 16 : 14,
                    height: 1.5,
                  ),
                ),
              ),
              actionsPadding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                isTablet ? 24 : 20,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _clearCanvas();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  Widget _buildComponentDrawer() {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 320,
      child: Drawer(
        backgroundColor: colorScheme.surface,
        child: Column(
          children: [
            // Header
            Container(
              height: 140,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.palette, color: Colors.white, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Components',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Professional UI Elements',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search components...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 16,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  filled: true,
                  fillColor: isDark ? colorScheme.surface : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Component Stats
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${_filteredComponents.length}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Available',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 30, color: colorScheme.outline),
                  Column(
                    children: [
                      Text(
                        '${_layoutItems.length}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'In Canvas',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // **PERFORMANCE: Lazy loading components list with ListView.builder**
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredComponents.length,
                itemBuilder: (context, index) {
                  final component = _filteredComponents[index];
                  return ComponentTile(
                    key: ValueKey(component.type),
                    component: component,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Double-tap to add ${component.label} to canvas',
                          ),
                          duration: const Duration(milliseconds: 1000),
                          backgroundColor: component.color,
                        ),
                      );
                    },
                    onDoubleTap: () {
                      _addComponent(component);
                      if (MediaQuery.of(context).size.width <= 1200) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 600;

        return Column(
          children: [
            // Enhanced Toolbar with responsive sizing
            Container(
              height: isSmallScreen ? 50 : 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(bottom: BorderSide(color: colorScheme.outline)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: colorScheme.primary),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? colorScheme.surface : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Canvas: ${_canvasWidth.round()}×${_canvasHeight.round()}px',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_selectedItems.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.content_copy,
                        size: 18,
                        color: Color(0xFF6366F1),
                      ),
                      onPressed: _duplicateSelectedItems,
                      tooltip: 'Duplicate',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: _deleteSelectedItems,
                      tooltip: 'Delete',
                    ),
                    IconButton(
                      icon: Icon(
                        _selectedItems.any((item) => item.isLocked)
                            ? Icons.lock
                            : Icons.lock_open,
                        size: 18,
                        color: const Color(0xFFF59E0B),
                      ),
                      onPressed: _lockSelectedItems,
                      tooltip: 'Lock/Unlock',
                    ),
                  ],
                ],
              ),
            ),

            // Enhanced Canvas with better responsive sizing
            Expanded(
              flex: isSmallScreen ? 2 : 3,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(child: _buildCanvas()),
                  ),
                ),
              ),
            ),

            // Enhanced Properties Panel with better sizing constraints
            if (_selectedItem != null)
              Container(
                constraints: BoxConstraints(
                  maxHeight: isSmallScreen ? 200 : 300,
                  minHeight: 150,
                ),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Enhanced header with better spacing
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedItem!.component.icon,
                            color: _selectedItem!.component.color,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_selectedItem!.component.label} Properties',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedItems.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_selectedItems.length} selected',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildPropertyEditor(),
                      ),
                    ),
                  ],
                ),
              ),

            // Enhanced Code Viewer with adaptive height
            if (_generatedCode.isNotEmpty)
              Container(
                height: isSmallScreen ? 150 : 200,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildCodeViewer(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Left Sidebar - Components
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: _buildComponentDrawer(),
        ),

        // Main Canvas Area
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Canvas Header
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outline),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Canvas (${_canvasWidth.round()}×${_canvasHeight.round()}px) • ${_layoutItems.length} components',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_selectedItems.isNotEmpty) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.content_copy, size: 16),
                        label: Text('Duplicate (${_selectedItems.length})'),
                        onPressed: _duplicateSelectedItems,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete, size: 16),
                        label: Text('Delete (${_selectedItems.length})'),
                        onPressed: _deleteSelectedItems,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(
                          _selectedItems.any((item) => item.isLocked)
                              ? Icons.lock
                              : Icons.lock_open,
                          size: 16,
                        ),
                        label: const Text('Lock'),
                        onPressed: _lockSelectedItems,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Canvas
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildCanvas(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right Sidebar - Properties & Code
        Container(
          width: 380,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Properties Panel
              if (_selectedItem != null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedItem!.component.color.withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _selectedItem!.component.icon,
                          color: _selectedItem!.component.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Properties',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _selectedItem!.component.label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedItems.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedItems.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildAdvancedPropertyEditor(),
                  ),
                ),
                const Divider(height: 1),
              ],

              // Code Viewer
              Expanded(
                flex: _selectedItem != null ? 2 : 1,
                child: _buildCodeViewer(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // **PERFORMANCE: Static Canvas with RepaintBoundary**
  Widget _buildCanvas() {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Container(
        width: _canvasWidth,
        height: _canvasHeight,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outline, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // **PERFORMANCE: Grid wrapped in RepaintBoundary**
            if (_showGrid)
              RepaintBoundary(
                child: CustomPaint(
                  painter: GridPainter(gridSize: _gridSize),
                  size: Size(_canvasWidth, _canvasHeight),
                ),
              ),

            // Static Canvas Background
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedItem = null;
                  _selectedItems.clear();
                  _contentController.clear();
                }),
                behavior: HitTestBehavior.translucent,
                child: Container(
                  color: Colors.transparent,
                  width: _canvasWidth,
                  height: _canvasHeight,
                ),
              ),
            ),

            // **PERFORMANCE: Only rebuild visible components**
            ..._layoutItems
                .where((item) => item.isVisible)
                .map((item) => _buildOptimizedLayoutItem(item)),

            // Selection Rectangle
            if (_selectionStart != null && _selectionEnd != null)
              Positioned(
                left: math.min(_selectionStart!.dx, _selectionEnd!.dx),
                top: math.min(_selectionStart!.dy, _selectionEnd!.dy),
                child: Container(
                  width: (_selectionEnd!.dx - _selectionStart!.dx).abs(),
                  height: (_selectionEnd!.dy - _selectionStart!.dy).abs(),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF6366F1),
                      width: 2,
                    ),
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // **ENHANCED: Optimized Layout Item with Canvas Lock Support**
  Widget _buildOptimizedLayoutItem(LayoutItem item) {
    final isSelected = _selectedItems.contains(item);

    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: RepaintBoundary(
        child: Transform.rotate(
          angle: item.rotation * math.pi / 180,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (_multiSelectMode && !isSelected) {
                  _selectedItems.add(item);
                } else if (_multiSelectMode && isSelected) {
                  _selectedItems.remove(item);
                } else {
                  _selectedItem = item;
                  _selectedItems = [item];
                  _updateContentController();
                }
              });
            },
            onPanStart: (details) {
              if (!item.isLocked && (!_canvasLocked || isSelected)) {
                setState(() {
                  if (!_selectedItems.contains(item)) {
                    _selectedItem = item;
                    _selectedItems = [item];
                    _updateContentController();
                  }
                });
              }
            },
            onPanUpdate: (details) {
              if (!item.isLocked &&
                  _selectedItems.contains(item) &&
                  (!_canvasLocked || isSelected)) {
                // **ENHANCED: Improved movement with precision support**
                for (final selectedItem in _selectedItems) {
                  if (!selectedItem.isLocked) {
                    final deltaStep = _precisionMode ? 1.0 : 1.0;
                    final newPosition = Offset(
                      selectedItem.position.dx + (details.delta.dx * deltaStep),
                      selectedItem.position.dy + (details.delta.dy * deltaStep),
                    );

                    final snappedPosition = (_snapToGrid && !_precisionMode)
                        ? _snapToGridIfEnabled(newPosition)
                        : newPosition;

                    selectedItem.position = Offset(
                      snappedPosition.dx.clamp(
                        0.0,
                        _canvasWidth - selectedItem.size.width,
                      ),
                      snappedPosition.dy.clamp(
                        0.0,
                        _canvasHeight - selectedItem.size.height,
                      ),
                    );
                  }
                }
                setState(() {});
              }
            },
            onPanEnd: (details) => _saveToHistory(),
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: item.opacity,
              child: Container(
                margin: item.margin,
                child: Stack(
                  children: [
                    Container(
                      width: item.size.width,
                      height: item.size.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? (_canvasLocked
                                    ? Colors.green
                                    : const Color(0xFF6366F1))
                              : Colors.transparent,
                          width: isSelected ? (_canvasLocked ? 3 : 2) : 0,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          if (item.shadow != null) item.shadow!,
                          // **ENHANCED: Canvas lock glow effect**
                          if (isSelected && _canvasLocked)
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: _buildPreviewWidget(item),
                    ),

                    // **ENHANCED: Larger resize handles when canvas is locked**
                    if (isSelected && _showResizeHandles) ...[
                      _buildResizeHandle(item, Alignment.topLeft),
                      _buildResizeHandle(item, Alignment.topRight),
                      _buildResizeHandle(item, Alignment.bottomLeft),
                      _buildResizeHandle(item, Alignment.bottomRight),
                      _buildResizeHandle(item, Alignment.topCenter),
                      _buildResizeHandle(item, Alignment.bottomCenter),
                      _buildResizeHandle(item, Alignment.centerLeft),
                      _buildResizeHandle(item, Alignment.centerRight),
                    ],

                    // **ENHANCED: Lock and Canvas Lock Indicators**
                    if (item.isLocked)
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),

                    // Canvas Lock Mode Indicator
                    if (_canvasLocked && isSelected)
                      Positioned(
                        top: -8,
                        left: -8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),

                    // Precision Mode Indicator
                    if (_precisionMode && isSelected)
                      Positioned(
                        bottom: -8,
                        right: -8,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(
                            Icons.straighten,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    if (item.isLocked)
                      Positioned(
                        top: -10,
                        right: -10,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // **ENHANCED: Much Larger Resize Handles with Canvas Lock Support**
  Widget _buildResizeHandle(LayoutItem item, Alignment alignment) {
    double left = 0, top = 0;

    // **ENHANCED: Larger handles when canvas is locked**
    final handleSize = _canvasLocked ? 40.0 : 30.0;
    final offset = handleSize / 2;

    switch (alignment) {
      case Alignment.topLeft:
        left = -offset;
        top = -offset;
        break;
      case Alignment.topRight:
        left = item.size.width - offset;
        top = -offset;
        break;
      case Alignment.bottomLeft:
        left = -offset;
        top = item.size.height - offset;
        break;
      case Alignment.bottomRight:
        left = item.size.width - offset;
        top = item.size.height - offset;
        break;
      case Alignment.topCenter:
        left = item.size.width / 2 - offset;
        top = -offset;
        break;
      case Alignment.bottomCenter:
        left = item.size.width / 2 - offset;
        top = item.size.height - offset;
        break;
      case Alignment.centerLeft:
        left = -offset;
        top = item.size.height / 2 - offset;
        break;
      case Alignment.centerRight:
        left = item.size.width - offset;
        top = item.size.height / 2 - offset;
        break;
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            double newWidth = item.size.width;
            double newHeight = item.size.height;
            double newX = item.position.dx;
            double newY = item.position.dy;

            // **ENHANCED: Precision resizing support**
            final resizeStep = _precisionMode ? 1.0 : 1.0;
            final deltaX = details.delta.dx * resizeStep;
            final deltaY = details.delta.dy * resizeStep;

            switch (alignment) {
              case Alignment.topLeft:
                newWidth -= deltaX;
                newHeight -= deltaY;
                newX += deltaX;
                newY += deltaY;
                break;
              case Alignment.topRight:
                newWidth += deltaX;
                newHeight -= deltaY;
                newY += deltaY;
                break;
              case Alignment.bottomLeft:
                newWidth -= deltaX;
                newHeight += deltaY;
                newX += deltaX;
                break;
              case Alignment.bottomRight:
                newWidth += deltaX;
                newHeight += deltaY;
                break;
              case Alignment.topCenter:
                newHeight -= deltaY;
                newY += deltaY;
                break;
              case Alignment.bottomCenter:
                newHeight += deltaY;
                break;
              case Alignment.centerLeft:
                newWidth -= deltaX;
                newX += deltaX;
                break;
              case Alignment.centerRight:
                newWidth += deltaX;
                break;
            }

            // **ENHANCED: Improved constraints**
            final minSize = _precisionMode ? 10.0 : 30.0;
            newWidth = newWidth.clamp(minSize, _canvasWidth - newX);
            newHeight = newHeight.clamp(minSize, _canvasHeight - newY);
            newX = newX.clamp(0.0, _canvasWidth - newWidth);
            newY = newY.clamp(0.0, _canvasHeight - newHeight);

            item.size = Size(newWidth, newHeight);
            item.position = Offset(newX, newY);
          });
        },
        onPanEnd: (details) => _saveToHistory(),
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            color: _canvasLocked ? Colors.green : const Color(0xFF6366F1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: _canvasLocked ? 5 : 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_canvasLocked ? 0.5 : 0.4),
                blurRadius: _canvasLocked ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              _getResizeHandleIcon(alignment),
              color: Colors.white,
              size: _canvasLocked ? 20 : 16,
            ),
          ),
        ),
      ),
    );
  }

  // **NEW: Get appropriate icon for resize handle**
  IconData _getResizeHandleIcon(Alignment alignment) {
    switch (alignment) {
      case Alignment.topLeft:
      case Alignment.bottomRight:
        return Icons.south_east;
      case Alignment.topRight:
      case Alignment.bottomLeft:
        return Icons.south_west;
      case Alignment.topCenter:
      case Alignment.bottomCenter:
        return Icons.unfold_more;
      case Alignment.centerLeft:
      case Alignment.centerRight:
        return Icons.swap_horiz;
      default:
        return Icons.open_with;
    }
  }

  Widget _buildPreviewWidget(LayoutItem item) {
    final component = item.component;
    final baseStyle = TextStyle(
      fontSize: item.fontSize,
      color: item.textColor,
      fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
    );

    Widget content;

    switch (component.type) {
      case 'header':
      case 'h3':
        content = Container(
          padding: item.padding,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Text(
            item.customText,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            textAlign: item.textAlign,
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      case 'subheader':
        content = Container(
          padding: item.padding,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Text(
            item.customText,
            style: baseStyle.copyWith(fontWeight: FontWeight.w600),
            textAlign: item.textAlign,
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      case 'paragraph':
        content = Container(
          padding: item.padding,
          alignment: Alignment.topLeft,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Text(
            item.customText,
            style: baseStyle,
            textAlign: item.textAlign,
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      case 'label':
        content = Container(
          padding: item.padding,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Text(
            item.customText,
            style: baseStyle.copyWith(fontSize: item.fontSize * 0.9),
            textAlign: item.textAlign,
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      case 'button':
        content = Container(
          padding: item.padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: item.backgroundColor.alpha > 0
                ? item.backgroundColor
                : const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(item.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            item.customText,
            style: baseStyle.copyWith(
              color: item.backgroundColor.alpha > 0
                  ? item.textColor
                  : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      case 'input':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor.alpha > 0
                ? item.backgroundColor
                : Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            item.customText,
            style: baseStyle.copyWith(color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      case 'textarea':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor.alpha > 0
                ? item.backgroundColor
                : Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          alignment: Alignment.topLeft,
          child: Text(
            item.customText,
            style: baseStyle.copyWith(color: Colors.grey),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      case 'select':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor.alpha > 0
                ? item.backgroundColor
                : Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.customText,
                  style: baseStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        );
        break;

      case 'checkbox':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF6366F1)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF6366F1),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.customText,
                  style: baseStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        break;

      case 'radio':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF6366F1)),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.customText,
                  style: baseStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        break;

      case 'image':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor.alpha > 0
                ? item.backgroundColor
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(item.borderRadius),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image,
                  color: component.color,
                  size: math.min(item.size.width, item.size.height) * 0.3,
                ),
                const SizedBox(height: 4),
                Text(
                  item.customText,
                  style: baseStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
        break;

      case 'video':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: math.min(item.size.width, item.size.height) * 0.3,
                ),
                const SizedBox(height: 4),
                Text(
                  item.customText,
                  style: baseStyle.copyWith(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
        break;

      case 'icon':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Center(
            child: Text(
              item.customText,
              style: baseStyle.copyWith(fontSize: item.size.width * 0.6),
              textAlign: TextAlign.center,
            ),
          ),
        );
        break;

      case 'navbar':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor.alpha > 0
                ? item.backgroundColor
                : const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Row(
            children: [
              const Icon(Icons.menu, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.customText,
                  style: baseStyle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.search, color: Colors.white, size: 20),
            ],
          ),
        );
        break;

      case 'breadcrumb':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.customText,
                  style: baseStyle.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        break;

      case 'link':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Text(
            item.customText,
            style: baseStyle.copyWith(
              color: const Color(0xFF3B82F6),
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      case 'list':
      case 'ordered_list':
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          alignment: Alignment.topLeft,
          child: Text(
            item.customText,
            style: baseStyle.copyWith(fontSize: 14),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;

      default:
        content = Container(
          padding: item.padding,
          decoration: BoxDecoration(
            color: component.color.withOpacity(0.1),
            border: Border.all(color: component.color),
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(component.icon, color: component.color, size: 24),
                const SizedBox(height: 4),
                Text(
                  component.label,
                  style: TextStyle(color: component.color, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(item.borderRadius),
      child: content,
    );
  }

  // **ENHANCED: RESPONSIVE PROPERTY EDITOR WITH BETTER KEYBOARD HANDLING**
  Widget _buildPropertyEditor() {
    if (_selectedItem == null) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 350;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Content Editor
            const Text(
              'Content',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (context, value, child) {
                return TextField(
                  controller: _contentController,
                  onChanged: (value) {
                    if (_selectedItem != null) {
                      setState(() => _selectedItem!.customText = value);
                    }
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: isCompact ? 2 : 3,
                  textInputAction: TextInputAction.done,
                );
              },
            ),
            const SizedBox(height: 16),

            // Enhanced Font Size with better layout
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Font Size',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_selectedItem!.fontSize.round()}px',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _selectedItem!.fontSize,
                    min: 8,
                    max: 48,
                    divisions: 40,
                    onChanged: (value) =>
                        setState(() => _selectedItem!.fontSize = value),
                    activeColor: const Color(0xFF6366F1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Enhanced Border Radius with better layout
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Border Radius',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_selectedItem!.borderRadius.round()}px',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _selectedItem!.borderRadius,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    onChanged: (value) =>
                        setState(() => _selectedItem!.borderRadius = value),
                    activeColor: const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Enhanced Background Color Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Background Color',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildColorPicker(_selectedItem!.backgroundColor, (color) {
                    setState(() => _selectedItem!.backgroundColor = color);
                  }),
                ],
              ),
            ),

            // Enhanced Typography Controls (if not compact)
            if (!isCompact) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Typography',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Bold',
                              style: TextStyle(fontSize: 13),
                            ),
                            value: _selectedItem!.isBold,
                            onChanged: (value) {
                              setState(
                                () => _selectedItem!.isBold = value ?? false,
                              );
                            },
                            activeColor: const Color(0xFF6366F1),
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Italic',
                              style: TextStyle(fontSize: 13),
                            ),
                            value: _selectedItem!.isItalic,
                            onChanged: (value) {
                              setState(
                                () => _selectedItem!.isItalic = value ?? false,
                              );
                            },
                            activeColor: const Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAdvancedPropertyEditor() {
    if (_selectedItem == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Position & Size
        _buildPropertySection('Position & Size', [
          _buildNumberField('X Position', _selectedItem!.position.dx, (value) {
            setState(
              () => _selectedItem!.position = Offset(
                value,
                _selectedItem!.position.dy,
              ),
            );
          }),
          _buildNumberField('Y Position', _selectedItem!.position.dy, (value) {
            setState(
              () => _selectedItem!.position = Offset(
                _selectedItem!.position.dx,
                value,
              ),
            );
          }),
          _buildNumberField('Width', _selectedItem!.size.width, (value) {
            setState(
              () =>
                  _selectedItem!.size = Size(value, _selectedItem!.size.height),
            );
          }),
          _buildNumberField('Height', _selectedItem!.size.height, (value) {
            setState(
              () =>
                  _selectedItem!.size = Size(_selectedItem!.size.width, value),
            );
          }),
        ]),

        // Content
        _buildPropertySection('Content', [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _contentController,
            builder: (context, value, child) {
              return TextField(
                controller: _contentController,
                onChanged: (value) {
                  if (_selectedItem != null) {
                    setState(() => _selectedItem!.customText = value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Text Content',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
              );
            },
          ),
        ]),

        // Typography
        _buildPropertySection('Typography', [
          _buildSlider('Font Size', _selectedItem!.fontSize, 8, 48, (value) {
            setState(() => _selectedItem!.fontSize = value);
          }),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Bold', style: TextStyle(fontSize: 12)),
                  value: _selectedItem!.isBold,
                  onChanged: (value) =>
                      setState(() => _selectedItem!.isBold = value ?? false),
                  dense: true,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Italic', style: TextStyle(fontSize: 12)),
                  value: _selectedItem!.isItalic,
                  onChanged: (value) =>
                      setState(() => _selectedItem!.isItalic = value ?? false),
                  dense: true,
                ),
              ),
            ],
          ),
          DropdownButtonFormField<TextAlign>(
            value: _selectedItem!.textAlign,
            decoration: const InputDecoration(
              labelText: 'Text Align',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: TextAlign.left, child: Text('Left')),
              DropdownMenuItem(value: TextAlign.center, child: Text('Center')),
              DropdownMenuItem(value: TextAlign.right, child: Text('Right')),
              DropdownMenuItem(
                value: TextAlign.justify,
                child: Text('Justify'),
              ),
            ],
            onChanged: (value) => setState(
              () => _selectedItem!.textAlign = value ?? TextAlign.left,
            ),
          ),
        ]),

        // Colors
        _buildPropertySection('Colors', [
          const Text(
            'Background Color',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildColorPicker(_selectedItem!.backgroundColor, (color) {
            setState(() => _selectedItem!.backgroundColor = color);
          }),
          const SizedBox(height: 16),
          const Text(
            'Text Color',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildColorPicker(_selectedItem!.textColor, (color) {
            setState(() => _selectedItem!.textColor = color);
          }),
        ]),

        // Appearance
        _buildPropertySection('Appearance', [
          _buildSlider('Border Radius', _selectedItem!.borderRadius, 0, 50, (
            value,
          ) {
            setState(() => _selectedItem!.borderRadius = value);
          }),
          _buildSlider('Opacity', _selectedItem!.opacity, 0, 1, (value) {
            setState(() => _selectedItem!.opacity = value);
          }),
          _buildSlider('Rotation', _selectedItem!.rotation, -180, 180, (value) {
            setState(() => _selectedItem!.rotation = value);
          }),
        ]),

        // Layer Controls
        _buildPropertySection('Layer', [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flip_to_front, size: 16),
                  label: const Text('To Front'),
                  onPressed: _bringToFront,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flip_to_back, size: 16),
                  label: const Text('To Back'),
                  onPressed: _sendToBack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7280),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _buildPropertySection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNumberField(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: value.round().toString()),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixText: 'px',
        ),
        keyboardType: TextInputType.number,
        onChanged: (text) {
          final newValue = double.tryParse(text);
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              label == 'Opacity'
                  ? value.toStringAsFixed(2)
                  : '${value.round()}${label.contains('Rotation') ? '°' : 'px'}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: const Color(0xFF6366F1),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildColorPicker(Color currentColor, ValueChanged<Color> onChanged) {
    final colors = [
      Colors.transparent,
      Colors.white,
      const Color(0xFFF3F4F6),
      const Color(0xFFE5E7EB),
      Colors.black,
      const Color(0xFF1F2937),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
      const Color(0xFF3B82F6),
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFA855F7),
      const Color(0xFFEC4899),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors
          .map(
            (color) => GestureDetector(
              onTap: () => onChanged(color),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: currentColor == color
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFE5E7EB),
                    width: currentColor == color ? 3 : 1,
                  ),
                ),
                child: color == Colors.transparent
                    ? const Icon(Icons.block, color: Colors.red, size: 20)
                    : null,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCodeViewer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.code, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Generated HTML/CSS Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_generatedCode.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Download functionality could be added here
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _generatedCode.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(40),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Create your design and generate code',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add components to the canvas and click "Generate Code"',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _generatedCode,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontFamily: 'Courier',
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // **ENHANCED: RESPONSIVE FLOATING BUTTONS WITH BETTER MOBILE UX**
  Widget _buildFloatingButtons() {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
        final isMobile = !isTablet;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Multi-select mode toggle with enhanced touch target
            SizedBox(
              width: isMobile ? 56 : 48, // Larger touch target on mobile
              height: isMobile ? 56 : 48,
              child: FloatingActionButton(
                heroTag: "multiselect",
                onPressed: () =>
                    setState(() => _multiSelectMode = !_multiSelectMode),
                backgroundColor: _multiSelectMode
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.grey[700] : Colors.grey[600]),
                elevation: isMobile ? 6 : 4,
                child: Icon(
                  _multiSelectMode
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: Colors.white,
                  size: isMobile ? 24 : 20,
                ),
                tooltip: 'Multi-Select Mode',
              ),
            ),

            SizedBox(height: isMobile ? 12 : 8),

            // Generate code (main button) with responsive sizing
            SizedBox(
              height: isMobile ? 56 : 48,
              child: FloatingActionButton.extended(
                heroTag: "generate",
                onPressed: _loading ? null : _generateCodeWithAI,
                backgroundColor: _loading
                    ? colorScheme.primary.withOpacity(0.6)
                    : colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: isMobile ? 8 : 6,
                extendedPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 16,
                ),
                icon: _loading
                    ? SizedBox(
                        width: isMobile ? 24 : 20,
                        height: isMobile ? 24 : 20,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(Icons.auto_awesome, size: isMobile ? 24 : 20),
                label: Text(
                  _loading ? 'Generating...' : 'Generate Code',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                tooltip: 'Generate HTML/CSS Code with AI',
              ),
            ),
          ],
        );
      },
    );
  }
}

// **PERFORMANCE: Separate component tile widget**
class ComponentTile extends StatelessWidget {
  final UIComponent component;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const ComponentTile({
    Key? key,
    required this.component,
    required this.onTap,
    required this.onDoubleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: component.color.withOpacity(0.2)),
              color: isDark
                  ? component.color.withOpacity(0.1)
                  : component.color.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: component.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(component.icon, color: component.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        component.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${component.defaultSize.width.round()}×${component.defaultSize.height.round()}px',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      if (component.properties.containsKey('tag'))
                        Text(
                          '<${component.properties['tag']}>',
                          style: TextStyle(
                            fontSize: 10,
                            color: component.color,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(Icons.touch_app, color: component.color, size: 16),
                    Text(
                      '2x',
                      style: TextStyle(
                        fontSize: 10,
                        color: component.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// **ENHANCED GRID PAINTER - Optimized for performance**
class GridPainter extends CustomPainter {
  final double gridSize;

  const GridPainter({this.gridSize = 20.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB).withOpacity(0.6)
      ..strokeWidth = 0.5;

    final boldPaint = Paint()
      ..color = const Color(0xFFD1D5DB).withOpacity(0.8)
      ..strokeWidth = 1.0;

    // Draw grid lines
    for (double x = 0; x <= size.width; x += gridSize) {
      final useBold = (x / gridSize) % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        useBold ? boldPaint : paint,
      );
    }

    for (double y = 0; y <= size.height; y += gridSize) {
      final useBold = (y / gridSize) % 5 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        useBold ? boldPaint : paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) =>
      gridSize != oldDelegate.gridSize;
}
