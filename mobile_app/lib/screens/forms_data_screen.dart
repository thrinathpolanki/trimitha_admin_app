import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/contact_card.dart';
import 'contact_detail_screen.dart';

enum _SortFilter { newest, oldest, unread, starred }

class FormsDataScreen extends StatefulWidget {
  const FormsDataScreen({super.key});

  @override
  State<FormsDataScreen> createState() => _FormsDataScreenState();
}

class _FormsDataScreenState extends State<FormsDataScreen> {
  static const _sheets = ['Trimitha', 'Thrinath', 'Thripura'];
  static const _sheetIcons = {
    'Trimitha': Icons.change_history_rounded,
    'Thrinath': Icons.person_outline_rounded,
    'Thripura': Icons.groups_outlined,
  };

  String _selectedSheet = 'Trimitha';
  _SortFilter _filter = _SortFilter.newest;
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ApiService.instance
        .getForms(_selectedSheet, search: _searchController.text.trim());
    if (!mounted) return;
    if (result['success'] == true) {
      final list = (result['data'] as List)
          .map((e) => Contact.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _contacts = list;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error']?.toString() ?? 'Could not load submissions';
        _isLoading = false;
      });
    }
  }

  List<Contact> get _visibleContacts {
    var list = _contacts.where((c) => c.status != 'Deleted').toList();
    switch (_filter) {
      case _SortFilter.newest:
        list.sort((a, b) =>
            (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
        break;
      case _SortFilter.oldest:
        list.sort((a, b) =>
            (a.timestamp ?? DateTime(0)).compareTo(b.timestamp ?? DateTime(0)));
        break;
      case _SortFilter.unread:
        list = list.where((c) => c.isUnread).toList();
        break;
      case _SortFilter.starred:
        list = list.where((c) => c.starred).toList();
        break;
    }
    return list;
  }

  int get _unreadCount => _contacts.where((c) => c.isUnread).length;

  Future<void> _toggleStar(Contact c) async {
    setState(() {
      final i = _contacts.indexWhere((x) => x.row == c.row);
      if (i != -1) _contacts[i] = c.copyWith(starred: !c.starred);
    });
    final result = await ApiService.instance
        .updateContact(_selectedSheet, c.row, starred: !c.starred);
    if (result['success'] != true && mounted) {
      setState(() {
        final i = _contacts.indexWhere((x) => x.row == c.row);
        if (i != -1) _contacts[i] = c; // revert
      });
    }
  }

  Future<void> _delete(Contact c) async {
    final result =
        await ApiService.instance.deleteContact(_selectedSheet, c.row);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _contacts.removeWhere((x) => x.row == c.row));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['error']?.toString() ?? 'Could not delete')),
      );
    }
  }

  Future<void> _openDetail(Contact c) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) =>
              ContactDetailScreen(contact: c, sheet: _selectedSheet)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forms Data'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: _sheets.map((sheet) {
                final selected = sheet == _selectedSheet;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedSheet = sheet);
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.teal.withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  selected ? AppColors.teal : AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Icon(_sheetIcons[sheet],
                                size: 18,
                                color: selected
                                    ? AppColors.teal
                                    : AppColors.textSecondary),
                            const SizedBox(height: 2),
                            Text(sheet,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.teal
                                      : AppColors.textSecondary,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search submissions...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tune_rounded,
                        color: AppColors.textMuted),
                    onPressed: _load,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Newest',
                      icon: Icons.bolt_rounded,
                      selected: _filter == _SortFilter.newest,
                      onTap: () => setState(() => _filter = _SortFilter.newest),
                    ),
                    _FilterChip(
                      label: 'Oldest',
                      icon: Icons.calendar_today_rounded,
                      selected: _filter == _SortFilter.oldest,
                      onTap: () => setState(() => _filter = _SortFilter.oldest),
                    ),
                    _FilterChip(
                      label: 'Unread',
                      icon: Icons.mail_outline_rounded,
                      selected: _filter == _SortFilter.unread,
                      badge: _unreadCount > 0 ? '$_unreadCount' : null,
                      onTap: () => setState(() => _filter = _SortFilter.unread),
                    ),
                    _FilterChip(
                      label: 'Starred',
                      icon: Icons.star_border_rounded,
                      selected: _filter == _SortFilter.starred,
                      onTap: () =>
                          setState(() => _filter = _SortFilter.starred),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
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
    final list = _visibleContacts;
    if (list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 60),
          Icon(Icons.inbox_outlined, size: 44, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(
              child: Text('No submissions found',
                  style: TextStyle(color: AppColors.textSecondary))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final c = list[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ContactCard(
            contact: c,
            onView: () => _openDetail(c),
            onToggleStar: () => _toggleStar(c),
            onDelete: () => _delete(c),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? AppColors.teal : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? AppColors.teal : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      color:
                          selected ? AppColors.teal : AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(badge!,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
