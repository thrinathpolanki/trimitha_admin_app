import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'contact_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<Contact> _items = [];

  static const _sheetIcons = {
    'Trimitha': Icons.change_history_rounded,
    'Thrinath': Icons.person_outline_rounded,
    'Thripura': Icons.groups_outlined,
  };
  static const _sheetColors = {
    'Trimitha': AppColors.purple,
    'Thrinath': AppColors.teal,
    'Thripura': AppColors.orange,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _showAll => _tabController.index == 1;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ApiService.instance.getNotifications(all: _showAll);
    if (!mounted) return;
    if (result['success'] == true) {
      final list = (result['data'] as List)
          .map((e) => Contact.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error']?.toString() ?? 'Could not load notifications';
        _isLoading = false;
      });
    }
  }

  int get _unreadCount => _items.where((c) => c.isUnread).length;

  Future<void> _markAllRead() async {
    final result = await ApiService.instance.markAllNotificationsRead();
    if (!mounted) return;
    if (result['success'] == true) {
      _load();
      NotificationService.instance.refreshNow();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                result['error']?.toString() ?? 'Could not mark all as read')),
      );
    }
  }

  Future<void> _openDetail(Contact c) async {
    if (c.sheet == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ContactDetailScreen(contact: c, sheet: c.sheet!)),
    );
    _load(); // it may have just been marked Read by opening it
    NotificationService.instance.refreshNow();
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark All Read'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Unread${_unreadCount > 0 ? ' ($_unreadCount)' : ''}'),
            const Tab(text: 'All'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.cloud_off_rounded,
              size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Center(
              child: OutlinedButton(
                  onPressed: _load, child: const Text('Try Again'))),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(
              _showAll
                  ? Icons.notifications_none_rounded
                  : Icons.mark_email_read_outlined,
              size: 48,
              color: AppColors.textMuted),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _showAll ? 'No notifications yet' : "You're all caught up!",
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = _items[i];
        final color = _sheetColors[c.sheet] ?? AppColors.teal;
        final icon = _sheetIcons[c.sheet] ?? Icons.mail_outline_rounded;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openDetail(c),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: icon, color: color, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'New submission from ${c.name}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (c.isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6, top: 4),
                                decoration: const BoxDecoration(
                                    color: AppColors.teal,
                                    shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.message.isEmpty ? c.subject : c.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.35),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (c.sheet != null)
                              StatusPill(label: c.sheet!, color: color),
                            const Spacer(),
                            Text(_timeAgo(c.timestamp),
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
