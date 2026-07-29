import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_card.dart';
import 'login_screen.dart';

/// [onNavigateToTab] lets tapping a stat card jump straight to the
/// relevant bottom-nav tab (e.g. any contacts card -> Forms, index 1).
/// Optional so this screen still works fine on its own.
class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.instance.getDashboard();
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _stats = result['data'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error']?.toString() ?? 'Could not load dashboard';
        _isLoading = false;
      });
      if (_error!.toLowerCase().contains('unauthorized')) {
        await ApiService.instance.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    }
  }

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

  void _go(int tabIndex) => widget.onNavigateToTab?.call(tabIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trimitha Admin'),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => _go(3)),
          IconButton(
              icon: const Icon(Icons.logout_rounded), onPressed: _logout),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildStats(),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_rounded,
            size: 48, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Center(
            child: OutlinedButton(
                onPressed: _loadDashboard, child: const Text('Try Again'))),
      ],
    );
  }

  Widget _buildStats() {
    final s = _stats ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text("Here's what's happening today",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 18),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.02,
          children: [
            DashboardCard(
              label: 'Total Contacts',
              value: '${s['totalContacts'] ?? 0}',
              icon: Icons.groups_2_outlined,
              color: AppColors.teal,
              onTap: () => _go(1),
            ),
            DashboardCard(
              label: "Today's Contacts",
              value: '${s['todayContacts'] ?? 0}',
              icon: Icons.person_add_alt_outlined,
              color: AppColors.info,
              onTap: () => _go(1),
            ),
            DashboardCard(
              label: 'Trimitha',
              value: '${s['trimithaContacts'] ?? 0}',
              icon: Icons.change_history_rounded,
              color: AppColors.purple,
              onTap: () => _go(1),
            ),
            DashboardCard(
              label: 'Thrinath',
              value: '${s['thrinathContacts'] ?? 0}',
              icon: Icons.person_outline_rounded,
              color: AppColors.pink,
              onTap: () => _go(1),
            ),
            DashboardCard(
              label: 'Thripura',
              value: '${s['thripuraContacts'] ?? 0}',
              icon: Icons.groups_outlined,
              color: AppColors.orange,
              onTap: () => _go(1),
            ),
            DashboardCard(
              label: 'Published Blogs',
              value: '${s['publishedBlogs'] ?? 0}',
              icon: Icons.article_outlined,
              color: AppColors.success,
              onTap: () => _go(2),
            ),
            DashboardCard(
              label: 'Draft Blogs',
              value: '${s['draftBlogs'] ?? 0}',
              icon: Icons.edit_note_rounded,
              color: AppColors.warning,
              onTap: () => _go(2),
            ),
            DashboardCard(
              label: 'Unread Notifications',
              value: '${s['unreadNotifications'] ?? 0}',
              icon: Icons.notifications_active_outlined,
              color: AppColors.danger,
              onTap: () => _go(3),
            ),
          ],
        ),
      ],
    );
  }
}
