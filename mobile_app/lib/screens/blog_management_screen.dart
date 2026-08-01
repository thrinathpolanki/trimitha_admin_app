import 'package:flutter/material.dart';
import '../models/blog.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/blog_card.dart';
import 'blog_editor_screen.dart';
import 'blog_preview_screen.dart';

enum _SortOrder { newest, oldest, mostViewed }

class BlogManagementScreen extends StatefulWidget {
  const BlogManagementScreen({super.key});

  @override
  State<BlogManagementScreen> createState() => _BlogManagementScreenState();
}

class _BlogManagementScreenState extends State<BlogManagementScreen> {
  final _searchController = TextEditingController();
  _SortOrder _sort = _SortOrder.newest;

  bool _isLoading = true;
  String? _error;
  List<Blog> _blogs = [];

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
        .getBlogsAdmin(search: _searchController.text.trim());
    if (!mounted) return;
    if (result['success'] == true) {
      final list = (result['data'] as List)
          .map((e) => Blog.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _blogs = list;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error']?.toString() ?? 'Could not load blogs';
        _isLoading = false;
      });
    }
  }

  List<Blog> get _sorted {
    final list = [..._blogs];
    switch (_sort) {
      case _SortOrder.newest:
        list.sort(
            (a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
        break;
      case _SortOrder.oldest:
        list.sort(
            (a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
        break;
      case _SortOrder.mostViewed:
        list.sort((a, b) => b.views.compareTo(a.views));
        break;
    }
    return list;
  }

  Future<void> _changeStatus(Blog b, String newStatus) async {
    final result = await ApiService.instance
        .updateBlog({'row': b.row, 'status': newStatus});
    if (!mounted) return;
    if (result['success'] == true) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(result['error']?.toString() ?? 'Could not update status')),
      );
    }
  }

  Future<void> _delete(Blog b) async {
    final result = await ApiService.instance.deleteBlog(b.row);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _blogs.removeWhere((x) => x.row == b.row));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['error']?.toString() ?? 'Could not delete')),
      );
    }
  }

  Future<void> _openEditor({Blog? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BlogEditorScreen(existing: existing)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = _blogs.length;
    final totalViews = _blogs.fold<int>(0, (sum, b) => sum + b.views);
    final featured = _blogs.where((b) => b.featured).length;
    final drafts = _blogs.where((b) => b.status == 'Draft').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Blog Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Blog'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    children: [
                      _buildStatsRow(total, totalViews, featured, drafts),
                      const SizedBox(height: 16),
                      _buildSearchAndSort(),
                      const SizedBox(height: 14),
                      if (_sorted.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.article_outlined,
                                    size: 44, color: AppColors.textMuted),
                                SizedBox(height: 12),
                                Text('No blog posts yet',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._sorted.map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BlogCard(
                                blog: b,
                                onPreview: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          BlogPreviewScreen(blog: b)),
                                ),
                                onEdit: () => _openEditor(existing: b),
                                onDelete: () => _delete(b),
                                onChangeStatus: (status) =>
                                    _changeStatus(b, status),
                              ),
                            )),
                    ],
                  ),
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
                onPressed: _load, child: const Text('Try Again'))),
      ],
    );
  }

  Widget _buildStatsRow(int total, int views, int featured, int drafts) {
    Widget stat(String value, String label, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              IconBadge(icon: icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('$total', 'Total Blogs', Icons.description_outlined,
            AppColors.teal),
        const SizedBox(width: 8),
        stat(
            '$views', 'Total Views', Icons.visibility_outlined, AppColors.info),
        const SizedBox(width: 8),
        stat('$featured', 'Featured', Icons.star_border_rounded,
            AppColors.warning),
        const SizedBox(width: 8),
        stat('$drafts', 'Drafts', Icons.edit_note_rounded, AppColors.purple),
      ],
    );
  }

  Widget _buildSearchAndSort() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search blogs...',
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _load();
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<_SortOrder>(
          icon: const Icon(Icons.swap_vert_rounded),
          initialValue: _sort,
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (context) => const [
            PopupMenuItem(
                value: _SortOrder.newest, child: Text('Newest First')),
            PopupMenuItem(
                value: _SortOrder.oldest, child: Text('Oldest First')),
            PopupMenuItem(
                value: _SortOrder.mostViewed, child: Text('Most Viewed')),
          ],
        ),
      ],
    );
  }
}
