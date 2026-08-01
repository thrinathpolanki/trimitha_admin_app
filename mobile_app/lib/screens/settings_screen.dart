import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _username;
  bool _exportingContacts = false;
  bool _exportingBlogs = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await ApiService.instance.whoAmI();
    if (mounted && result['success'] == true) {
      setState(() => _username = result['username']?.toString());
    }
  }

  // ---------------------------------------------------------------------
  // CHANGE PASSWORD
  // ---------------------------------------------------------------------
  Future<void> _showChangePasswordDialog() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Change Password'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorText != null) ...[
                    Text(errorText!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13)),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    controller: oldController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Current Password'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'New Password'),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'At least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Confirm New Password'),
                    validator: (v) => (v != newController.text)
                        ? 'Passwords do not match'
                        : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorText = null;
                        });
                        final result = await ApiService.instance.changePassword(
                            oldController.text, newController.text);
                        if (result['success'] == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Password updated successfully')),
                            );
                          }
                        } else {
                          setDialogState(() {
                            isSaving = false;
                            errorText = result['error']?.toString() ??
                                'Could not update password';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Update'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // EXPORT
  // ---------------------------------------------------------------------
  String _csvEscape(dynamic value) {
    final str = value?.toString() ?? '';
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  Future<void> _shareCsv(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  Future<void> _exportContacts() async {
    setState(() => _exportingContacts = true);
    final result = await ApiService.instance.exportData('contacts');
    if (mounted) setState(() => _exportingContacts = false);
    if (result['success'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['error']?.toString() ?? 'Export failed')),
        );
      }
      return;
    }
    final data = result['data'] as Map<String, dynamic>;
    final buffer = StringBuffer();
    data.forEach((sheetName, rows) {
      buffer.writeln('--- $sheetName ---');
      for (final row in (rows as List)) {
        buffer.writeln((row as List).map(_csvEscape).join(','));
      }
      buffer.writeln();
    });
    await _shareCsv(buffer.toString(), 'contacts_export.csv');
  }

  Future<void> _exportBlogs() async {
    setState(() => _exportingBlogs = true);
    final result = await ApiService.instance.exportData('blogs');
    if (mounted) setState(() => _exportingBlogs = false);
    if (result['success'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['error']?.toString() ?? 'Export failed')),
        );
      }
      return;
    }
    final rows = result['data'] as List;
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln((row as List).map(_csvEscape).join(','));
    }
    await _shareCsv(buffer.toString(), 'blogs_export.csv');
  }

  // ---------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Log out?'),
        content:
            const Text('You will need to sign in again to manage your site.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log Out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.teal,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_username ?? '...',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('Administrator',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Account'),
          Card(
            child: ListTile(
              leading: const IconBadge(
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.info,
                  size: 38),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: _showChangePasswordDialog,
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const IconBadge(
                      icon: Icons.file_download_outlined,
                      color: AppColors.teal,
                      size: 38),
                  title: const Text('Export Contacts'),
                  subtitle: const Text('Trimitha, Thrinath & Thripura as CSV',
                      style: TextStyle(fontSize: 11.5)),
                  trailing: _exportingContacts
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded,
                          color: AppColors.textMuted, size: 20),
                  onTap: _exportingContacts ? null : _exportContacts,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const IconBadge(
                      icon: Icons.article_outlined,
                      color: AppColors.purple,
                      size: 38),
                  title: const Text('Export Blogs'),
                  subtitle: const Text('All posts as CSV',
                      style: TextStyle(fontSize: 11.5)),
                  trailing: _exportingBlogs
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded,
                          color: AppColors.textMuted, size: 20),
                  onTap: _exportingBlogs ? null : _exportBlogs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('About'),
          const Card(
            child: ListTile(
              leading: IconBadge(
                  icon: Icons.info_outline_rounded,
                  color: AppColors.textMuted,
                  size: 38),
              title: Text('Personal Admin App'),
              subtitle: Text('Version 1.0.0', style: TextStyle(fontSize: 11.5)),
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      );
}
