import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'forms_data_screen.dart';
import 'blog_management_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

/// The main app frame after login — a bottom navigation bar with 5
/// destinations (Home, Forms, Blogs, Notifications, Settings), matching
/// the reference design. Each tab keeps its own state via IndexedStack.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _navigateToTab(int tabIndex) => setState(() => _index = tabIndex);

  @override
  void initState() {
    super.initState();
    // Now that we're logged in, start checking for new submissions.
    NotificationService.instance.startPolling();
  }

  @override
  void dispose() {
    NotificationService.instance.stopPolling();
    super.dispose();
  }

  List<Widget> get _screens => [
        DashboardScreen(onNavigateToTab: _navigateToTab),
        const FormsDataScreen(),
        const BlogManagementScreen(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: StreamBuilder<int>(
        stream: NotificationService.instance.unreadCountStream,
        builder: (context, snapshot) {
          final unread = snapshot.data ?? 0;
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home'),
              const NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  selectedIcon: Icon(Icons.description_rounded),
                  label: 'Forms'),
              const NavigationDestination(
                  icon: Icon(Icons.article_outlined),
                  selectedIcon: Icon(Icons.article_rounded),
                  label: 'Blogs'),
              NavigationDestination(
                icon: Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_rounded),
                ),
                label: 'Notifications',
              ),
              const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings'),
            ],
          );
        },
      ),
    );
  }
}
