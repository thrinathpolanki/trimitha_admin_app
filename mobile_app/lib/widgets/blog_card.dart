import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/blog.dart';
import '../theme/app_theme.dart';

class BlogCard extends StatelessWidget {
  final Blog blog;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String newStatus) onChangeStatus;

  const BlogCard({
    super.key,
    required this.blog,
    required this.onPreview,
    required this.onEdit,
    required this.onDelete,
    required this.onChangeStatus,
  });

  Color get _statusColor {
    switch (blog.status) {
      case 'Published':
        return AppColors.success;
      case 'Archived':
        return AppColors.textMuted;
      default:
        return AppColors.info; // Draft
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this post?'),
        content: Text(
            '"${blog.title}" will be removed. This can\'t be undone from the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        blog.date != null ? DateFormat('dd MMM yyyy').format(blog.date!) : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.only(topLeft: Radius.circular(18)),
                child: blog.image.isNotEmpty
                    ? Image.network(
                        blog.image,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(),
                      )
                    : _fallbackThumb(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (blog.featured) ...[
                            const Icon(Icons.star_rounded,
                                color: AppColors.warning, size: 16),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              blog.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (blog.category.isNotEmpty)
                            StatusPill(
                                label: blog.category, color: AppColors.purple),
                          StatusPill(label: blog.status, color: _statusColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                if (dateStr.isNotEmpty) ...[
                  const Icon(Icons.event_outlined,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(dateStr,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11.5)),
                  const SizedBox(width: 14),
                ],
                const Icon(Icons.visibility_outlined,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('${blog.views}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5)),
                if (blog.author.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  const Icon(Icons.person_outline_rounded,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(blog.author,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11.5)),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Row(
              children: [
                _ActionBtn(
                    icon: Icons.visibility_outlined,
                    label: 'Preview',
                    color: AppColors.info,
                    onTap: onPreview),
                _ActionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: AppColors.teal,
                    onTap: onEdit),
                if (blog.status == 'Draft')
                  _ActionBtn(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Publish',
                      color: AppColors.success,
                      onTap: () => onChangeStatus('Published'))
                else if (blog.status == 'Published')
                  _ActionBtn(
                      icon: Icons.archive_outlined,
                      label: 'Archive',
                      color: AppColors.warning,
                      onTap: () => onChangeStatus('Archived'))
                else
                  _ActionBtn(
                      icon: Icons.unarchive_outlined,
                      label: 'Unarchive',
                      color: AppColors.info,
                      onTap: () => onChangeStatus('Published')),
                _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: AppColors.danger,
                    onTap: () => _confirmDelete(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackThumb() {
    return Container(
      width: 96,
      height: 96,
      color: AppColors.surfaceAlt,
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
