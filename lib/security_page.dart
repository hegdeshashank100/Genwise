import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'change_password_page.dart';
import 'forgot_password_page.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _twoFactorEnabled = false;
  bool _loginAlertsEnabled = true;
  bool _securityNotifications = true;

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
    final tipsBackgroundColor = isDark
        ? colorScheme.primary.withOpacity(0.1)
        : Colors.blue[50];
    final tipsBorderColor = isDark
        ? colorScheme.primary.withOpacity(0.3)
        : Colors.blue[200];
    final tipsTextColor = isDark ? colorScheme.primary : Colors.blue[700];

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Security & Privacy'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                    // 🔒 Password Security with Theme Support
                    _buildSecurityCard(
                      title: 'Password Security',
                      icon: Icons.lock,
                      children: [
                        _buildSecurityItem(
                          icon: Icons.lock_reset,
                          title: 'Change Password',
                          subtitle: 'Update your current password',
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
                        _buildSecurityItem(
                          icon: Icons.help_outline,
                          title: 'Forgot Password',
                          subtitle: 'Reset password via email',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 30 : 20),

                    // 🔐 Two-Factor Authentication with Theme Support
                    _buildSecurityCard(
                      title: 'Two-Factor Authentication',
                      icon: Icons.security,
                      children: [
                        _buildSecurityToggle(
                          title: 'Enable 2FA',
                          subtitle: 'Add extra security to your account',
                          value: _twoFactorEnabled,
                          onChanged: (value) {
                            setState(() {
                              _twoFactorEnabled = value;
                            });
                            if (value) {
                              _showTwoFactorSetup();
                            }
                          },
                        ),
                        if (_twoFactorEnabled) ...[
                          Divider(color: dividerColor),
                          _buildSecurityItem(
                            icon: Icons.phone_android,
                            title: 'Authenticator App',
                            subtitle: 'Use Google Authenticator or similar',
                            onTap: () => _showAuthenticatorSetup(),
                          ),
                          Divider(color: dividerColor),
                          _buildSecurityItem(
                            icon: Icons.sms,
                            title: 'SMS Backup',
                            subtitle: 'Add phone number for backup codes',
                            onTap: () => _showSMSSetup(),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: isTablet ? 30 : 20),

                    // 🔑 Login Security with Theme Support
                    _buildSecurityCard(
                      title: 'Login Security',
                      icon: Icons.login,
                      children: [
                        _buildSecurityToggle(
                          title: 'Login Alerts',
                          subtitle: 'Get notified of new sign-ins',
                          value: _loginAlertsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _loginAlertsEnabled = value;
                            });
                          },
                        ),
                        Divider(color: dividerColor),
                        _buildSecurityItem(
                          icon: Icons.devices,
                          title: 'Active Sessions',
                          subtitle: 'Manage your logged-in devices',
                          onTap: () => _showActiveSessions(),
                        ),
                        Divider(color: dividerColor),
                        _buildSecurityItem(
                          icon: Icons.history,
                          title: 'Login History',
                          subtitle: 'View recent login activity',
                          onTap: () => _showLoginHistory(),
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 30 : 20),

                    // 🔐 Privacy Settings with Theme Support
                    _buildSecurityCard(
                      title: 'Privacy Settings',
                      icon: Icons.privacy_tip,
                      children: [
                        _buildSecurityToggle(
                          title: 'Security Notifications',
                          subtitle: 'Receive security-related emails',
                          value: _securityNotifications,
                          onChanged: (value) {
                            setState(() {
                              _securityNotifications = value;
                            });
                          },
                        ),
                        Divider(color: dividerColor),
                        _buildSecurityItem(
                          icon: Icons.download,
                          title: 'Download My Data',
                          subtitle: 'Export all your account data',
                          onTap: () => _requestDataExport(),
                        ),
                        Divider(color: dividerColor),
                        _buildSecurityItem(
                          icon: Icons.delete_forever,
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account',
                          onTap: () => _showDeleteConfirmation(),
                          isDestructive: true,
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 30 : 20),

                    // 💡 Security Tips with Theme Support
                    _buildSecurityTips(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecurityCard({
    required String title,
    required IconData icon,
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
            Row(
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
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];
    final primaryTextColor = isDark ? colorScheme.onBackground : Colors.black87;
    final secondaryTextColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];
    final arrowColor = isDark ? Colors.grey[500] : Colors.grey[400];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isDestructive ? Colors.red : iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : primaryTextColor,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: secondaryTextColor)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: arrowColor),
      onTap: onTap,
    );
  }

  Widget _buildSecurityToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryTextColor = isDark ? colorScheme.onBackground : Colors.black87;
    final secondaryTextColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: secondaryTextColor)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }

  Widget _buildSecurityTips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final tipsBackgroundColor = isDark
        ? colorScheme.primary.withOpacity(0.1)
        : Colors.blue[50];
    final tipsBorderColor = isDark
        ? colorScheme.primary.withOpacity(0.3)
        : Colors.blue[200];
    final tipsTextColor = isDark ? colorScheme.primary : Colors.blue[700];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tipsBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tipsBorderColor!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: tipsTextColor),
                const SizedBox(width: 12),
                Text(
                  'Security Tips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tipsTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTip('Use a strong, unique password'),
            _buildTip('Enable two-factor authentication'),
            _buildTip('Keep your email secure'),
            _buildTip('Review login activity regularly'),
            _buildTip('Don\'t share your account credentials'),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String tip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final tipsTextColor = isDark ? colorScheme.primary : Colors.blue[700];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: tipsTextColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(color: tipsTextColor?.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTwoFactorSetup() {
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
                    Icons.security,
                    color: colorScheme.primary,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    'Enable Two-Factor Authentication',
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
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield,
                          color: Colors.green,
                          size: isTablet ? 24 : 20,
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        Expanded(
                          child: Text(
                            'Two-factor authentication adds an extra layer of security to your account.',
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
                    'Benefits:',
                    style: TextStyle(
                      color: textColor,
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  ...[
                    'Enhanced account security',
                    'Protection against unauthorized access',
                    'Peace of mind for sensitive data',
                  ].map(
                    (benefit) => Padding(
                      padding: EdgeInsets.only(bottom: isTablet ? 6 : 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: isTablet ? 18 : 16,
                          ),
                          SizedBox(width: isTablet ? 10 : 8),
                          Expanded(
                            child: Text(
                              benefit,
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: isTablet ? 14 : 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    'Would you like to set it up now?',
                    style: TextStyle(
                      color: textColor,
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.w500,
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
                      onPressed: () {
                        setState(() {
                          _twoFactorEnabled = false;
                        });
                        Navigator.pop(context);
                      },
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
                        'Maybe Later',
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
                        _showAuthenticatorSetup();
                      },
                      child: Text(
                        'Set Up Now',
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

  void _showAuthenticatorSetup() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          'Authenticator App Setup',
          style: TextStyle(color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '1. Download Google Authenticator or Authy',
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              '2. Scan the QR code below',
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 16),
            // Add QR code widget here
            Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.qr_code,
                size: 80,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '3. Enter the 6-digit code from your app',
              style: TextStyle(color: textColor),
            ),
          ],
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
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Complete Setup'),
          ),
        ],
      ),
    );
  }

  void _showSMSSetup() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('SMS Backup', style: TextStyle(color: textColor)),
        content: TextField(
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Phone Number',
            labelStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
            prefixText: '+',
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.primary),
            ),
          ),
          keyboardType: TextInputType.phone,
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
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Add Number'),
          ),
        ],
      ),
    );
  }

  void _showActiveSessions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;
    final iconColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Active Sessions', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.phone_android, color: iconColor),
              title: Text('Current Device', style: TextStyle(color: textColor)),
              subtitle: Text(
                'Last active: Now',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
              trailing: const Text(
                'Active',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showLoginHistory() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;
    final iconColor = isDark
        ? colorScheme.onSurface.withOpacity(0.7)
        : Colors.grey[600];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Login History', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.login, color: iconColor),
              title: Text(
                'Successful Login',
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                'Today, 9:30 AM',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            ListTile(
              leading: Icon(Icons.login, color: iconColor),
              title: Text(
                'Successful Login',
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                'Yesterday, 2:15 PM',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _requestDataExport() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Download My Data', style: TextStyle(color: textColor)),
        content: Text(
          'We\'ll prepare your data and send a download link to your email within 24 hours.',
          style: TextStyle(color: textColor),
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
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data export requested')),
              );
            },
            child: const Text('Request Export'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Delete Account', style: TextStyle(color: textColor)),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(color: textColor),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              // Navigate to account deletion flow
            },
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
