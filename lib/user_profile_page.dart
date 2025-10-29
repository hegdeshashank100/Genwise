import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'security_page.dart';
import 'change_password_page.dart';
import 'login_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final user = AuthService.instance.currentUser;
  bool _isEditing = false;
  bool _isVerificationEmailSending = false;
  DateTime? _lastVerificationSentTime;
  final _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayNameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    // Prevent multiple clicks
    if (_isVerificationEmailSending) return;

    // Check cooldown (60 seconds)
    final now = DateTime.now();
    if (_lastVerificationSentTime != null &&
        now.difference(_lastVerificationSentTime!).inSeconds < 60) {
      final remainingSeconds =
          60 - now.difference(_lastVerificationSentTime!).inSeconds;
      _showSnackBar(
        'Please wait $remainingSeconds seconds before trying again.',
      );
      return;
    }

    setState(() {
      _isVerificationEmailSending = true;
    });

    try {
      await user?.sendEmailVerification();
      setState(() {
        _lastVerificationSentTime = now;
      });
      _showSnackBar(
        'Verification email sent! Please check your inbox.',
        isSuccess: true,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'too-many-requests':
          message = 'Too many attempts. Please wait before trying again.';
          break;
        case 'user-disabled':
          message = 'Your account has been disabled.';
          break;
        default:
          message =
              'Failed to send verification email. Please try again later.';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar(
        'An unexpected error occurred. Please try again later.',
        isError: true,
      );
    } finally {
      setState(() {
        _isVerificationEmailSending = false;
      });
    }
  }

  void _showSnackBar(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? Colors.green
            : isError
            ? Colors.red
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting account...'),
            ],
          ),
        ),
      );

      // Delete user data from Firestore first
      await AuthService.instance.deleteUserData();

      // Delete the Firebase Auth account
      await user?.delete();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Navigate to login screen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );

        _showSnackBar('Account deleted successfully', isSuccess: true);
      }
    } on FirebaseAuthException catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      String message;
      switch (e.code) {
        case 'requires-recent-login':
          message =
              'Please log in again before deleting your account for security reasons.';
          // You might want to implement re-authentication here
          break;
        case 'user-disabled':
          message = 'Your account has been disabled.';
          break;
        case 'user-not-found':
          message = 'Account not found.';
          break;
        default:
          message = 'Failed to delete account: ${e.message}';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showSnackBar(
        'An unexpected error occurred while deleting account: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌙 Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // 🎨 Dynamic Colors Based on Theme
    final backgroundColor = isDark ? colorScheme.background : Colors.grey[50];
    final cardColor = isDark ? colorScheme.surface : Colors.white;
    final primaryTextColor = isDark ? colorScheme.onBackground : Colors.black87;
    final secondaryTextColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];
    final iconColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];
    final dividerColor = isDark ? colorScheme.outline : Colors.grey[300];
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Account Details'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
              if (!_isEditing) {
                _saveProfile();
              }
            },
            child: Text(
              _isEditing ? 'Save' : 'Edit',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
          final maxWidth = isTablet ? 600.0 : double.infinity;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isTablet ? 32 : 20),
                child: Column(
                  children: [
                    // 👤 Profile Picture Section with Theme Support
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: isTablet ? 140 : 120,
                            height: isTablet ? 140 : 120,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                isTablet ? 70 : 60,
                              ),
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: shadowColor,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person,
                              size: isTablet ? 70 : 60,
                              color: colorScheme.primary,
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: shadowColor,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    _showImagePickerDialog();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: isTablet ? 40 : 30),

                    // 📋 Account Information with Theme Support
                    _buildInfoCard(
                      title: 'Account Information',
                      children: [
                        _buildInfoItem(
                          icon: Icons.email,
                          label: 'Email',
                          value: user?.email ?? 'Not provided',
                          isEditable: false,
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildInfoItem(
                          icon: Icons.person,
                          label: 'Display Name',
                          value: user?.displayName ?? 'Not set',
                          isEditable: _isEditing,
                          controller: _displayNameController,
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildInfoItem(
                          icon: Icons.verified_user,
                          label: 'Account Status',
                          value: user?.emailVerified == true
                              ? 'Verified'
                              : 'Unverified',
                          isEditable: false,
                          trailing: _buildVerificationWidget(),
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildInfoItem(
                          icon: Icons.calendar_today,
                          label: 'Member Since',
                          value: _formatDate(user?.metadata.creationTime),
                          isEditable: false,
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 30 : 20),

                    // ⚡ Quick Actions with Theme Support
                    _buildInfoCard(
                      title: 'Quick Actions',
                      children: [
                        _buildActionItem(
                          icon: Icons.lock_reset,
                          title: 'Change Password',
                          subtitle: 'Update your password',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordPage(),
                              ),
                            );
                          },
                        ),
                        Divider(color: dividerColor),
                        _buildActionItem(
                          icon: Icons.security,
                          title: 'Security Settings',
                          subtitle: 'Manage security preferences',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SecurityPage(),
                              ),
                            );
                          },
                        ),
                        Divider(color: dividerColor),
                        _buildActionItem(
                          icon: Icons.download,
                          title: 'Download Data',
                          subtitle: 'Export your account data',
                          onTap: _downloadUserData,
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 30 : 20),

                    // ⚠️ Danger Zone with Theme Support
                    _buildInfoCard(
                      title: 'Danger Zone',
                      children: [
                        _buildActionItem(
                          icon: Icons.delete_forever,
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account',
                          onTap: _showDeleteAccountDialog,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationWidget() {
    final isVerified = user?.emailVerified == true;
    final colorScheme = Theme.of(context).colorScheme;

    if (isVerified) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return TextButton(
      onPressed: _isVerificationEmailSending ? null : _sendVerificationEmail,
      child: _isVerificationEmailSending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              'Verify',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final cardColor = isDark ? colorScheme.surface : Colors.white;
    final primaryTextColor = isDark ? colorScheme.onBackground : Colors.black87;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.05);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: isTablet ? 15 : 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isDark
            ? Border.all(color: colorScheme.outline.withOpacity(0.2))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 28 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isEditable = false,
    TextEditingController? controller,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final iconColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];
    final secondaryTextColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];
    final primaryTextColor = isDark ? colorScheme.onBackground : Colors.black87;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 12 : 10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: isTablet ? 24 : 20,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: isTablet ? 6 : 4),
              isEditable && controller != null
                  ? TextField(
                      controller: controller,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : 8,
                          ),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : 8,
                          ),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: isDark
                            ? colorScheme.surface.withOpacity(0.5)
                            : Colors.grey[50],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 12,
                          vertical: isTablet ? 14 : 12,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w500,
                        color: primaryTextColor,
                        height: 1.2,
                      ),
                    ),
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: isTablet ? 12 : 8), trailing],
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final primaryTextColor = isDark ? colorScheme.onBackground : Colors.black87;
    final secondaryTextColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];
    final arrowColor = isDark ? Colors.grey[500] : Colors.grey[400];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 16 : 12,
            horizontal: isTablet ? 4 : 0,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withOpacity(0.1)
                      : colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : colorScheme.primary,
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 18 : 16,
                        color: isDestructive ? Colors.red : primaryTextColor,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: isTablet ? 4 : 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: isTablet ? 15 : 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Icon(
                Icons.arrow_forward_ios,
                size: isTablet ? 18 : 16,
                color: arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _saveProfile() async {
    try {
      await user?.updateDisplayName(_displayNameController.text);
      _showSnackBar('Profile updated successfully', isSuccess: true);
    } catch (e) {
      _showSnackBar('Error updating profile: $e', isError: true);
    }
  }

  void _showImagePickerDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          return AlertDialog(
            backgroundColor: backgroundColor,
            surfaceTintColor: colorScheme.primary.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: colorScheme.primary,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    'Change Profile Picture',
                    style: TextStyle(
                      color: textColor,
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: BoxConstraints(maxWidth: isTablet ? 400 : 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 24 : 20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: isTablet ? 48 : 40,
                          color: colorScheme.primary,
                        ),
                        SizedBox(height: isTablet ? 12 : 8),
                        Text(
                          'This feature will be available soon!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: isTablet ? 16 : 14,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: isTablet ? 8 : 4),
                        Text(
                          'You\'ll be able to upload and customize your profile picture.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: isTablet ? 14 : 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 20,
              0,
              isTablet ? 24 : 20,
              isTablet ? 24 : 20,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _downloadUserData() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          return AlertDialog(
            backgroundColor: backgroundColor,
            surfaceTintColor: colorScheme.primary.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: colorScheme.primary,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    'Download Data',
                    style: TextStyle(
                      color: textColor,
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: BoxConstraints(maxWidth: isTablet ? 400 : 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: isTablet ? 24 : 20,
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        Expanded(
                          child: Text(
                            'Your data export will be sent to your email within 24 hours.',
                            style: TextStyle(
                              color: textColor,
                              fontSize: isTablet ? 15 : 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    'Export includes:',
                    style: TextStyle(
                      color: textColor,
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  ...[
                    'Account information',
                    'Generated content',
                    'Usage history',
                    'Preferences',
                  ].map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: isTablet ? 6 : 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: isTablet ? 18 : 16,
                          ),
                          SizedBox(width: isTablet ? 10 : 8),
                          Text(
                            item,
                            style: TextStyle(
                              color: textColor.withOpacity(0.8),
                              fontSize: isTablet ? 14 : 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 20,
              0,
              isTablet ? 24 : 20,
              isTablet ? 24 : 20,
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : 8,
                          ),
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
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : 8,
                          ),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showSnackBar('Data export requested', isSuccess: true);
                      },
                      child: Text(
                        'Request Export',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          return AlertDialog(
            backgroundColor: backgroundColor,
            surfaceTintColor: Colors.red.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: BoxConstraints(maxWidth: isTablet ? 400 : 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: isTablet ? 24 : 20,
                            ),
                            SizedBox(width: isTablet ? 12 : 8),
                            Expanded(
                              child: Text(
                                'This action cannot be undone',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 12 : 8),
                        Text(
                          'All your data will be permanently deleted, including:',
                          style: TextStyle(
                            color: textColor,
                            fontSize: isTablet ? 15 : 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  ...[
                    'Account information',
                    'Generated content',
                    'Chat history',
                    'Preferences & settings',
                  ].map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: isTablet ? 8 : 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.close,
                            color: Colors.red,
                            size: isTablet ? 18 : 16,
                          ),
                          SizedBox(width: isTablet ? 12 : 8),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: isTablet ? 14 : 13,
                                height: 1.3,
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
            actionsPadding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 20,
              0,
              isTablet ? 24 : 20,
              isTablet ? 24 : 20,
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : 8,
                          ),
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
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : 8,
                          ),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteAccount();
                      },
                      child: Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
