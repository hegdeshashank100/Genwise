import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:archive/archive.dart';

class ToolResumePage extends StatefulWidget {
  const ToolResumePage({super.key});

  @override
  State<ToolResumePage> createState() => _ToolResumePageState();
}

class _ToolResumePageState extends State<ToolResumePage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  XFile? _profileImage;
  final _imagePicker = ImagePicker();

  // Contact Information
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();

  // Summary
  final _summaryController = TextEditingController();

  // Dynamic lists for sections
  List<Map<String, String>> _educationList = [
    {'degree': '', 'school': '', 'year': '', 'details': ''},
  ];
  List<Map<String, String>> _experienceList = [
    {'title': '', 'company': '', 'duration': '', 'description': ''},
  ];
  List<String> _skillsList = [''];
  List<Map<String, String>> _certificationsList = [
    {'name': '', 'issuer': '', 'date': ''},
  ];

  // ENHANCED: Professional template options
  String _selectedTemplate = 'professional'; // professional, modern, classic

  // ENHANCED: Skills categorization for ATS optimization
  List<Map<String, String>> _categorizedSkills = [
    {'category': 'Technical Skills', 'skills': ''},
    {'category': 'Soft Skills', 'skills': ''},
    {'category': 'Languages', 'skills': ''},
  ];
  bool _useSkillCategories = false;

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
  }

  Future<void> _requestInitialPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      if (sdkInt >= 33) {
        await Permission.photos.request();
      } else {
        await Permission.storage.request();
      }
    } else if (Platform.isIOS) {
      await Permission.photos.request();
    }
  }

  Future<void> _pickImage() async {
    try {
      PermissionStatus status;
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        status = sdkInt >= 33
            ? await Permission.photos.request()
            : await Permission.storage.request();
      } else {
        status = await Permission.photos.request();
      }

      if (status.isGranted) {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 512,
          maxHeight: 512,
        );
        if (image != null) {
          setState(() {
            _profileImage = image;
          });
          _showSnackBar('Photo selected successfully', isError: false);
        }
      } else {
        _showSnackBar('Storage/Photos permission denied', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error picking image: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Dynamic list management methods
  void _addEducation() {
    setState(() {
      _educationList.add({
        'degree': '',
        'school': '',
        'year': '',
        'details': '',
      });
    });
  }

  void _removeEducation(int index) {
    if (_educationList.length > 1) {
      setState(() {
        _educationList.removeAt(index);
      });
    }
  }

  void _addExperience() {
    setState(() {
      _experienceList.add({
        'title': '',
        'company': '',
        'duration': '',
        'description': '',
      });
    });
  }

  void _removeExperience(int index) {
    if (_experienceList.length > 1) {
      setState(() {
        _experienceList.removeAt(index);
      });
    }
  }

  void _addSkill() {
    setState(() {
      _skillsList.add('');
    });
  }

  void _removeSkill(int index) {
    if (_skillsList.length > 1) {
      setState(() {
        _skillsList.removeAt(index);
      });
    }
  }

  void _addCertification() {
    setState(() {
      _certificationsList.add({'name': '', 'issuer': '', 'date': ''});
    });
  }

  void _removeCertification(int index) {
    if (_certificationsList.length > 1) {
      setState(() {
        _certificationsList.removeAt(index);
      });
    }
  }

  // ENHANCED: Skill category management methods
  void _addSkillCategory() {
    setState(() {
      _categorizedSkills.add({'category': 'Custom Category', 'skills': ''});
    });
  }

  void _migrateSkillsToCategories() {
    if (_skillsList.any((skill) => skill.trim().isNotEmpty)) {
      final existingSkills = _skillsList
          .where((skill) => skill.trim().isNotEmpty)
          .join(', ');
      if (_categorizedSkills.isNotEmpty &&
          _categorizedSkills[0]['skills']!.isEmpty) {
        _categorizedSkills[0]['skills'] = existingSkills;
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      if (!RegExp(r'^\+?[\d\s\-\(\)]{7,15}$').hasMatch(value)) {
        return 'Please enter a valid phone number';
      }
    }
    return null;
  }

  Future<void> _generatePDF() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please correct the errors in the form', isError: true);
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final pdf = pw.Document();

      // Professional color scheme for ATS-friendly design
      final primaryBlue = PdfColor.fromHex(
        '#1f2937',
      ); // Dark gray-blue for headers
      final accentBlue = PdfColor.fromHex('#3b82f6'); // Bright blue for accents
      final darkGray = PdfColor.fromHex('#374151'); // Dark text
      final mediumGray = PdfColor.fromHex('#6b7280'); // Medium text

      // Load profile image if available
      pw.MemoryImage? profileImageWidget;
      if (_profileImage != null) {
        try {
          final imageBytes = await File(_profileImage!.path).readAsBytes();
          profileImageWidget = pw.MemoryImage(imageBytes);
        } catch (e) {
          _showSnackBar('Failed to load profile image', isError: true);
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32), // Professional margins
          build: (pw.Context context) {
            return [
              // Professional Header Section with improved layout
              _buildProfessionalHeader(
                primaryBlue,
                accentBlue,
                mediumGray,
                profileImageWidget,
              ),
              pw.SizedBox(height: 24),

              // Contact Information Bar (ATS-friendly single line)
              if (_emailController.text.isNotEmpty ||
                  _phoneController.text.isNotEmpty)
                _buildContactBar(mediumGray),

              pw.SizedBox(height: 20),

              // Professional Summary with enhanced formatting
              if (_summaryController.text.trim().isNotEmpty)
                _buildProfessionalSection(
                  'PROFESSIONAL SUMMARY',
                  _summaryController.text.trim(),
                  primaryBlue,
                  darkGray,
                  isFirstSection: true,
                ),

              // Core Competencies/Skills (ATS optimized)
              if ((_useSkillCategories &&
                      _categorizedSkills.any(
                        (cat) => cat['skills']!.trim().isNotEmpty,
                      )) ||
                  (!_useSkillCategories &&
                      _skillsList.any((skill) => skill.trim().isNotEmpty)))
                _buildSkillsSection(primaryBlue, darkGray),

              // Professional Experience with ATS-friendly formatting
              if (_experienceList.any((exp) => exp['title']!.isNotEmpty))
                _buildExperienceSection(primaryBlue, darkGray, mediumGray),

              // Education with improved layout
              if (_educationList.any((edu) => edu['degree']!.isNotEmpty))
                _buildEducationSection(primaryBlue, darkGray, mediumGray),

              // Certifications & Professional Development
              if (_certificationsList.any((cert) => cert['name']!.isNotEmpty))
                _buildCertificationsSection(primaryBlue, darkGray, mediumGray),
            ];
          },
        ),
      );

      await _savePDF(pdf);
    } catch (e) {
      _showSnackBar('Error generating PDF: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // ENHANCED: Professional ATS-friendly header
  pw.Widget _buildProfessionalHeader(
    PdfColor primaryColor,
    PdfColor accentColor,
    PdfColor mediumGray,
    pw.MemoryImage? profileImage,
  ) {
    return pw.Container(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Profile image section
          if (profileImage != null)
            pw.Container(
              width: 90,
              height: 90,
              margin: const pw.EdgeInsets.only(right: 24),
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: accentColor, width: 3),
                image: pw.DecorationImage(
                  image: profileImage,
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),

          // Name and location section
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Name with professional styling
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    _nameController.text.trim().toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Professional title line (if summary exists, extract first line)
                if (_summaryController.text.trim().isNotEmpty)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Text(
                      _extractProfessionalTitle(),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.normal,
                        color: accentColor,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),

                // Location with icon styling
                if (_locationController.text.trim().isNotEmpty)
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        margin: const pw.EdgeInsets.only(right: 8),
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: mediumGray,
                        ),
                      ),
                      pw.Text(
                        _locationController.text.trim(),
                        style: pw.TextStyle(fontSize: 12, color: mediumGray),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Professional contact bar (ATS-friendly)
  pw.Widget _buildContactBar(PdfColor mediumGray) {
    final contactItems = <String>[];

    if (_emailController.text.trim().isNotEmpty) {
      contactItems.add('📧 ${_emailController.text.trim()}');
    }
    if (_phoneController.text.trim().isNotEmpty) {
      contactItems.add('📱 ${_phoneController.text.trim()}');
    }
    if (_linkedinController.text.trim().isNotEmpty) {
      contactItems.add('💼 ${_linkedinController.text.trim()}');
    }
    if (_portfolioController.text.trim().isNotEmpty) {
      contactItems.add('🌐 ${_portfolioController.text.trim()}');
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#f8fafc'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor.fromHex('#e5e7eb'), width: 1),
      ),
      child: pw.Wrap(
        spacing: 20,
        children: contactItems
            .map(
              (item) => pw.Text(
                item,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: mediumGray,
                  fontWeight: pw.FontWeight.normal,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ENHANCED: Professional section builder with improved typography
  pw.Widget _buildProfessionalSection(
    String title,
    String content,
    PdfColor primaryColor,
    PdfColor darkGray, {
    bool isFirstSection = false,
  }) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 24, top: isFirstSection ? 0 : 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header with professional styling
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryColor, width: 2.5),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Content with professional formatting
          pw.Container(
            child: pw.Text(
              content,
              style: pw.TextStyle(
                fontSize: 11,
                lineSpacing: 1.6,
                color: darkGray,
                height: 1.4,
              ),
              textAlign: pw.TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Skills section with categorization and ATS optimization
  pw.Widget _buildSkillsSection(PdfColor primaryColor, PdfColor darkGray) {
    if (_useSkillCategories) {
      return _buildCategorizedSkillsSection(primaryColor, darkGray);
    } else {
      return _buildRegularSkillsSection(primaryColor, darkGray);
    }
  }

  // Categorized skills for ATS optimization
  pw.Widget _buildCategorizedSkillsSection(
    PdfColor primaryColor,
    PdfColor darkGray,
  ) {
    final validCategories = _categorizedSkills
        .where((category) => category['skills']!.trim().isNotEmpty)
        .toList();

    if (validCategories.isEmpty) return pw.Container();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24, top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryColor, width: 2.5),
              ),
            ),
            child: pw.Text(
              'CORE COMPETENCIES',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Skill categories
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: validCategories.map((category) {
              final skills = category['skills']!
                  .split(',')
                  .map((skill) => skill.trim())
                  .where((skill) => skill.isNotEmpty)
                  .toList();

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${category['category']!}:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: skills
                          .map(
                            (skill) => pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: primaryColor,
                                  width: 1,
                                ),
                                borderRadius: pw.BorderRadius.circular(12),
                              ),
                              child: pw.Text(
                                skill,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: darkGray,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Regular skills section
  pw.Widget _buildRegularSkillsSection(
    PdfColor primaryColor,
    PdfColor darkGray,
  ) {
    final skills = _skillsList
        .where((skill) => skill.trim().isNotEmpty)
        .toList();

    if (skills.isEmpty) return pw.Container();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24, top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryColor, width: 2.5),
              ),
            ),
            child: pw.Text(
              'CORE COMPETENCIES',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Skills in professional grid layout
          pw.Wrap(
            spacing: 12,
            runSpacing: 8,
            children: skills
                .map(
                  (skill) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: primaryColor, width: 1),
                      borderRadius: pw.BorderRadius.circular(16),
                    ),
                    child: pw.Text(
                      skill.trim(),
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: darkGray,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Experience section with ATS-friendly formatting
  pw.Widget _buildExperienceSection(
    PdfColor primaryColor,
    PdfColor darkGray,
    PdfColor mediumGray,
  ) {
    final experiences = _experienceList
        .where((exp) => exp['title']!.isNotEmpty)
        .toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24, top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryColor, width: 2.5),
              ),
            ),
            child: pw.Text(
              'PROFESSIONAL EXPERIENCE',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Experience entries
          pw.Column(
            children: experiences
                .map(
                  (exp) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Job title and company
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    exp['title']!,
                                    style: pw.TextStyle(
                                      fontSize: 13,
                                      fontWeight: pw.FontWeight.bold,
                                      color: darkGray,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    exp['company']!,
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.normal,
                                      color: primaryColor,
                                      fontStyle: pw.FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Duration
                            pw.Text(
                              exp['duration']!,
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: mediumGray,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                          ],
                        ),

                        pw.SizedBox(height: 8),

                        // Description with bullet points
                        pw.Text(
                          _formatDescription(exp['description']!),
                          style: pw.TextStyle(
                            fontSize: 11,
                            lineSpacing: 1.5,
                            color: darkGray,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Education section with professional formatting
  pw.Widget _buildEducationSection(
    PdfColor primaryColor,
    PdfColor darkGray,
    PdfColor mediumGray,
  ) {
    final education = _educationList
        .where((edu) => edu['degree']!.isNotEmpty)
        .toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24, top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryColor, width: 2.5),
              ),
            ),
            child: pw.Text(
              'EDUCATION',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Education entries
          pw.Column(
            children: education
                .map(
                  (edu) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 16),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                edu['degree']!,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkGray,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                edu['school']!,
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  color: primaryColor,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                              if (edu['details']!.isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  edu['details']!,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    color: mediumGray,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        pw.Text(
                          edu['year']!,
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: mediumGray,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Certifications section with professional layout
  pw.Widget _buildCertificationsSection(
    PdfColor primaryColor,
    PdfColor darkGray,
    PdfColor mediumGray,
  ) {
    final certifications = _certificationsList
        .where((cert) => cert['name']!.isNotEmpty)
        .toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24, top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryColor, width: 2.5),
              ),
            ),
            child: pw.Text(
              'CERTIFICATIONS & PROFESSIONAL DEVELOPMENT',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Certification entries
          pw.Column(
            children: certifications
                .map(
                  (cert) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                cert['name']!,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkGray,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                cert['issuer']!,
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  color: primaryColor,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          cert['date']!,
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: mediumGray,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // Helper method to extract professional title from summary
  String _extractProfessionalTitle() {
    final summary = _summaryController.text.trim();
    if (summary.isEmpty) return '';

    // Extract first sentence or first 60 characters as professional title
    final sentences = summary.split('.');
    if (sentences.isNotEmpty && sentences[0].length <= 60) {
      return sentences[0].trim();
    }

    return summary.length <= 60 ? summary : '${summary.substring(0, 57)}...';
  }

  // Helper method to format job descriptions with bullet points
  String _formatDescription(String description) {
    if (description.trim().isEmpty) return '';

    // If description doesn't start with bullet points, add them
    final lines = description
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length > 1) {
      return lines
          .map((line) => line.trim().startsWith('•') ? line : '• $line')
          .join('\n');
    }

    return description.trim().startsWith('•') ? description : '• $description';
  }

  Future<void> _savePDF(pw.Document pdf) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'resume_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      _showSnackBar('Resume saved successfully!', isError: false);

      // Try to open the file
      try {
        await OpenFile.open(file.path);
      } catch (e) {
        _showSnackBar('File saved at: ${file.path}', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error saving PDF: ${e.toString()}', isError: true);
    }
  }

  // DOCX generation implementation
  Future<void> _generateDOCX() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please correct the errors in the form', isError: true);
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _createDOCXFile();
    } catch (e) {
      _showSnackBar('Error generating DOCX: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _createDOCXFile() async {
    try {
      // Create the DOCX content as XML
      final docxContent = _buildDOCXContent();

      // Create the DOCX file structure
      final archive = Archive();

      // Add required DOCX files
      archive.addFile(
        ArchiveFile(
          '[Content_Types].xml',
          docxContent['contentTypes']!.length,
          docxContent['contentTypes']!,
        ),
      );
      archive.addFile(
        ArchiveFile(
          '_rels/.rels',
          docxContent['rels']!.length,
          docxContent['rels']!,
        ),
      );
      archive.addFile(
        ArchiveFile(
          'word/_rels/document.xml.rels',
          docxContent['documentRels']!.length,
          docxContent['documentRels']!,
        ),
      );
      archive.addFile(
        ArchiveFile(
          'word/document.xml',
          docxContent['document']!.length,
          docxContent['document']!,
        ),
      );
      archive.addFile(
        ArchiveFile(
          'word/styles.xml',
          docxContent['styles']!.length,
          docxContent['styles']!,
        ),
      );

      // Encode the archive as ZIP
      final zipData = ZipEncoder().encode(archive);

      if (zipData.isNotEmpty) {
        await _saveDOCX(Uint8List.fromList(zipData));
      } else {
        throw Exception('Failed to create DOCX file');
      }
    } catch (e) {
      throw Exception('Error creating DOCX: $e');
    }
  }

  Map<String, Uint8List> _buildDOCXContent() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();
    final linkedin = _linkedinController.text.trim();
    final portfolio = _portfolioController.text.trim();
    final summary = _summaryController.text.trim();

    // Build contact information
    final contactInfo = <String>[];
    if (email.isNotEmpty) contactInfo.add('Email: $email');
    if (phone.isNotEmpty) contactInfo.add('Phone: $phone');
    if (location.isNotEmpty) contactInfo.add('Location: $location');
    if (linkedin.isNotEmpty) contactInfo.add('LinkedIn: $linkedin');
    if (portfolio.isNotEmpty) contactInfo.add('Portfolio: $portfolio');

    // Build experience content
    final experienceContent = _experienceList
        .where((exp) => exp['title']!.isNotEmpty)
        .map(
          (exp) =>
              '''
          <w:p>
            <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
            <w:r><w:t>${_escapeXml(exp['title']!)} at ${_escapeXml(exp['company']!)}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:rPr><w:i/></w:rPr><w:t>${_escapeXml(exp['duration']!)}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>${_escapeXml(exp['description']!)}</w:t></w:r>
          </w:p>
        ''',
        )
        .join('');

    // Build education content
    final educationContent = _educationList
        .where((edu) => edu['degree']!.isNotEmpty)
        .map(
          (edu) =>
              '''
          <w:p>
            <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
            <w:r><w:t>${_escapeXml(edu['degree']!)} - ${_escapeXml(edu['school']!)}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:rPr><w:i/></w:rPr><w:t>${_escapeXml(edu['year']!)}</w:t></w:r>
          </w:p>
          ${edu['details']!.isNotEmpty ? '<w:p><w:r><w:t>${_escapeXml(edu['details']!)}</w:t></w:r></w:p>' : ''}
        ''',
        )
        .join('');

    // Build skills content
    final skillsContent = _skillsList
        .where((skill) => skill.trim().isNotEmpty)
        .map(
          (skill) => '<w:p><w:r><w:t>• ${_escapeXml(skill)}</w:t></w:r></w:p>',
        )
        .join('');

    // Build certifications content
    final certificationsContent = _certificationsList
        .where((cert) => cert['name']!.isNotEmpty)
        .map(
          (cert) =>
              '''
          <w:p>
            <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
            <w:r><w:t>${_escapeXml(cert['name']!)} - ${_escapeXml(cert['issuer']!)}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:rPr><w:i/></w:rPr><w:t>${_escapeXml(cert['date']!)}</w:t></w:r>
          </w:p>
        ''',
        )
        .join('');

    // Main document XML
    final documentXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <!-- Header with Name -->
    <w:p>
      <w:pPr><w:pStyle w:val="Title"/></w:pPr>
      <w:r><w:t>${_escapeXml(name.toUpperCase())}</w:t></w:r>
    </w:p>
    
    <!-- Contact Information -->
    ${contactInfo.isNotEmpty ? '''
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>CONTACT INFORMATION</w:t></w:r>
    </w:p>
    ${contactInfo.map((info) => '<w:p><w:r><w:t>${_escapeXml(info)}</w:t></w:r></w:p>').join('')}
    ''' : ''}
    
    <!-- Professional Summary -->
    ${summary.isNotEmpty ? '''
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>PROFESSIONAL SUMMARY</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>${_escapeXml(summary)}</w:t></w:r>
    </w:p>
    ''' : ''}
    
    <!-- Work Experience -->
    ${experienceContent.isNotEmpty ? '''
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>WORK EXPERIENCE</w:t></w:r>
    </w:p>
    $experienceContent
    ''' : ''}
    
    <!-- Education -->
    ${educationContent.isNotEmpty ? '''
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>EDUCATION</w:t></w:r>
    </w:p>
    $educationContent
    ''' : ''}
    
    <!-- Skills -->
    ${skillsContent.isNotEmpty ? '''
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>SKILLS</w:t></w:r>
    </w:p>
    $skillsContent
    ''' : ''}
    
    <!-- Certifications -->
    ${certificationsContent.isNotEmpty ? '''
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>CERTIFICATIONS</w:t></w:r>
    </w:p>
    $certificationsContent
    ''' : ''}
    
  </w:body>
</w:document>''';

    // Content Types XML
    final contentTypesXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

    // Main relationships XML
    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    // Document relationships XML
    final documentRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

    // Styles XML
    final stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:pPr>
      <w:jc w:val="center"/>
    </w:pPr>
    <w:rPr>
      <w:sz w:val="32"/>
      <w:szCs w:val="32"/>
      <w:b/>
      <w:color w:val="2563EB"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="Heading1"/>
    <w:rPr>
      <w:sz w:val="24"/>
      <w:szCs w:val="24"/>
      <w:b/>
      <w:color w:val="2563EB"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="Heading2"/>
    <w:rPr>
      <w:sz w:val="20"/>
      <w:szCs w:val="20"/>
      <w:b/>
    </w:rPr>
  </w:style>
</w:styles>''';

    return {
      'contentTypes': utf8.encode(contentTypesXml),
      'rels': utf8.encode(relsXml),
      'documentRels': utf8.encode(documentRelsXml),
      'document': utf8.encode(documentXml),
      'styles': utf8.encode(stylesXml),
    };
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  Future<void> _saveDOCX(Uint8List docxData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'resume_${DateTime.now().millisecondsSinceEpoch}.docx';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(docxData);

      _showSnackBar('DOCX resume saved successfully!', isError: false);

      // Try to open the file
      try {
        await OpenFile.open(file.path);
      } catch (e) {
        _showSnackBar('DOCX saved at: ${file.path}', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error saving DOCX: ${e.toString()}', isError: true);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  Widget _buildDynamicTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 12,
          ),
        ),
        maxLines: maxLines,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Builder'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Professional Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1f2937), const Color(0xFF3b82f6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.description, color: Colors.white, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Professional Resume Builder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ATS-Friendly • Professional Templates • AI-Powered',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Photo Section
            ExpansionTile(
              title: const Text(
                'Photo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.photo_camera),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: _profileImage != null
                            ? FileImage(File(_profileImage!.path))
                            : null,
                        backgroundColor: Colors.grey.shade200,
                        child: _profileImage == null
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(
                            _profileImage == null
                                ? 'Add Photo'
                                : 'Change Photo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Contact Information
            ExpansionTile(
              title: const Text(
                'Contact Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.contact_mail),
              initiallyExpanded: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTextField(
                        label: 'Full Name *',
                        controller: _nameController,
                        validator: (value) =>
                            _validateRequired(value, 'Full Name'),
                      ),
                      _buildTextField(
                        label: 'Email *',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      _buildTextField(
                        label: 'Phone',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                      ),
                      _buildTextField(
                        label: 'Location',
                        controller: _locationController,
                        hint: 'City, State/Country',
                      ),
                      _buildTextField(
                        label: 'LinkedIn Profile',
                        controller: _linkedinController,
                        hint: 'https://linkedin.com/in/yourprofile',
                      ),
                      _buildTextField(
                        label: 'Portfolio/Website',
                        controller: _portfolioController,
                        hint: 'https://yourportfolio.com',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Summary
            ExpansionTile(
              title: const Text(
                'Professional Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.description),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ATS Tip: Start with your job title, highlight key achievements with numbers, and include relevant keywords from job descriptions.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildTextField(
                        label: 'Professional Summary',
                        controller: _summaryController,
                        hint:
                            'e.g., "Experienced Software Developer with 5+ years in mobile app development. Delivered 20+ successful projects, increasing user engagement by 40%. Expertise in Flutter, React Native, and agile methodologies."',
                        maxLines: 4,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (value.trim().length < 50) {
                              return 'Summary should be at least 50 characters for better ATS compatibility';
                            }
                            if (value.trim().length > 500) {
                              return 'Summary should be under 500 characters for optimal readability';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Experience
            ExpansionTile(
              title: const Text(
                'Work Experience',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.work),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.work_outline,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ATS Tips for Experience:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• Use action verbs (Developed, Implemented, Led, Achieved)\n• Include quantifiable results (increased by 25%, managed team of 10)\n• Add relevant keywords from job descriptions\n• List experiences in reverse chronological order',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...List.generate(_experienceList.length, (index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Experience ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_experienceList.length > 1)
                                      IconButton(
                                        onPressed: () =>
                                            _removeExperience(index),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                      ),
                                  ],
                                ),
                                _buildDynamicTextField(
                                  label: 'Job Title *',
                                  value: _experienceList[index]['title']!,
                                  onChanged: (value) =>
                                      _experienceList[index]['title'] = value,
                                  hint:
                                      'e.g., Senior Software Engineer, Project Manager',
                                ),
                                _buildDynamicTextField(
                                  label: 'Company *',
                                  value: _experienceList[index]['company']!,
                                  onChanged: (value) =>
                                      _experienceList[index]['company'] = value,
                                  hint: 'e.g., Tech Corp, ABC Industries',
                                ),
                                _buildDynamicTextField(
                                  label: 'Duration *',
                                  value: _experienceList[index]['duration']!,
                                  onChanged: (value) =>
                                      _experienceList[index]['duration'] =
                                          value,
                                  hint:
                                      'e.g., Jan 2020 - Present, Mar 2018 - Dec 2019',
                                ),
                                _buildDynamicTextField(
                                  label:
                                      'Key Achievements & Responsibilities *',
                                  value: _experienceList[index]['description']!,
                                  onChanged: (value) =>
                                      _experienceList[index]['description'] =
                                          value,
                                  maxLines: 4,
                                  hint:
                                      'Use bullet points starting with action verbs. Include metrics and results.\n• Developed mobile apps that increased user retention by 30%\n• Led cross-functional team of 8 engineers\n• Implemented CI/CD pipeline, reducing deployment time by 50%',
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      ElevatedButton.icon(
                        onPressed: _addExperience,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Experience'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Education
            ExpansionTile(
              title: const Text(
                'Education',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.school),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ...List.generate(_educationList.length, (index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Education ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_educationList.length > 1)
                                      IconButton(
                                        onPressed: () =>
                                            _removeEducation(index),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                      ),
                                  ],
                                ),
                                _buildDynamicTextField(
                                  label: 'Degree',
                                  value: _educationList[index]['degree']!,
                                  onChanged: (value) =>
                                      _educationList[index]['degree'] = value,
                                ),
                                _buildDynamicTextField(
                                  label: 'School/University',
                                  value: _educationList[index]['school']!,
                                  onChanged: (value) =>
                                      _educationList[index]['school'] = value,
                                ),
                                _buildDynamicTextField(
                                  label: 'Year',
                                  value: _educationList[index]['year']!,
                                  onChanged: (value) =>
                                      _educationList[index]['year'] = value,
                                  hint: 'e.g., 2020 or 2018-2022',
                                ),
                                _buildDynamicTextField(
                                  label: 'Additional Details',
                                  value: _educationList[index]['details']!,
                                  onChanged: (value) =>
                                      _educationList[index]['details'] = value,
                                  maxLines: 2,
                                  hint:
                                      'GPA, honors, relevant coursework, etc.',
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      ElevatedButton.icon(
                        onPressed: _addEducation,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Education'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Skills
            ExpansionTile(
              title: const Text(
                'Skills & Competencies',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.star),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ATS Optimization Toggle
                      Row(
                        children: [
                          Switch(
                            value: _useSkillCategories,
                            onChanged: (value) {
                              setState(() {
                                _useSkillCategories = value;
                                if (value) {
                                  // Convert existing skills to categorized format
                                  _migrateSkillsToCategories();
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Use ATS-Optimized Skill Categories',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Skill input based on categorization preference
                      if (_useSkillCategories) ...[
                        ...List.generate(_categorizedSkills.length, (index) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _categorizedSkills[index]['category']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDynamicTextField(
                                    label: 'Skills (separate with commas)',
                                    value: _categorizedSkills[index]['skills']!,
                                    onChanged: (value) =>
                                        _categorizedSkills[index]['skills'] =
                                            value,
                                    hint: 'e.g., Flutter, Dart, Firebase, Git',
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        ElevatedButton.icon(
                          onPressed: _addSkillCategory,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Skill Category'),
                        ),
                      ] else ...[
                        ...List.generate(_skillsList.length, (index) {
                          return Row(
                            children: [
                              Expanded(
                                child: _buildDynamicTextField(
                                  label: 'Skill ${index + 1}',
                                  value: _skillsList[index],
                                  onChanged: (value) =>
                                      _skillsList[index] = value,
                                  hint:
                                      'e.g., Flutter, Project Management, etc.',
                                ),
                              ),
                              if (_skillsList.length > 1)
                                IconButton(
                                  onPressed: () => _removeSkill(index),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          );
                        }),
                        ElevatedButton.icon(
                          onPressed: _addSkill,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Skill'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Certifications
            ExpansionTile(
              title: const Text(
                'Certifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.verified),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ...List.generate(_certificationsList.length, (index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Certification ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_certificationsList.length > 1)
                                      IconButton(
                                        onPressed: () =>
                                            _removeCertification(index),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                      ),
                                  ],
                                ),
                                _buildDynamicTextField(
                                  label: 'Certification Name',
                                  value: _certificationsList[index]['name']!,
                                  onChanged: (value) =>
                                      _certificationsList[index]['name'] =
                                          value,
                                ),
                                _buildDynamicTextField(
                                  label: 'Issuing Organization',
                                  value: _certificationsList[index]['issuer']!,
                                  onChanged: (value) =>
                                      _certificationsList[index]['issuer'] =
                                          value,
                                ),
                                _buildDynamicTextField(
                                  label: 'Date',
                                  value: _certificationsList[index]['date']!,
                                  onChanged: (value) =>
                                      _certificationsList[index]['date'] =
                                          value,
                                  hint: 'e.g., March 2023',
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      ElevatedButton.icon(
                        onPressed: _addCertification,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Certification'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ENHANCED: Template Selection
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.palette, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Resume Template',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTemplateOption(
                            'professional',
                            'Professional',
                            'Clean & ATS-friendly',
                            Icons.business_center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTemplateOption(
                            'modern',
                            'Modern',
                            'Contemporary design',
                            Icons.design_services,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTemplateOption(
                            'classic',
                            'Classic',
                            'Traditional layout',
                            Icons.article,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _generatePDF,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _loading ? 'Generating...' : 'Generate PDF Resume',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: const Color(0xFF1f2937),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _generateDOCX,
                    icon: const Icon(Icons.description),
                    label: const Text('Generate DOCX Resume'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: const Color(0xFF3b82f6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Professional Tips Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates,
                        color: Colors.amber,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Professional Resume Tips',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '✓ Keep it to 1-2 pages maximum\n✓ Use consistent formatting throughout\n✓ Include relevant keywords for ATS systems\n✓ Quantify achievements with numbers\n✓ Proofread for grammar and spelling errors\n✓ Save in both PDF and DOCX formats',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ENHANCED: Template option builder
  Widget _buildTemplateOption(
    String templateId,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedTemplate == templateId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTemplate = templateId;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _summaryController.dispose();
    super.dispose();
  }
}
