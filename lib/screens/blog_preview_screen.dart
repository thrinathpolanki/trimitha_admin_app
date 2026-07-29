import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/blog.dart';
import '../theme/app_theme.dart';

/// A read-only preview of exactly what the post's content is — the same
/// way a visitor would see it on the website (Title, cover image,
/// category, then the plain-text content).
class BlogPreviewScreen extends StatelessWidget {
  final Blog blog;
  const BlogPreviewScreen({super.key, required this.blog});

  @override
  Widget build(BuildContext context) {
    final dateStr = blog.date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(blog.date!)
        : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: ListView(
        children: [
          if (blog.image.isNotEmpty)
            Image.network(
              blog.image,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: AppColors.surfaceAlt,
                child: const Icon(Icons.image_outlined,
                    size: 40, color: AppColors.textMuted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    if (blog.category.isNotEmpty)
                      StatusPill(label: blog.category, color: AppColors.purple),
                    StatusPill(
                        label: blog.status,
                        color: blog.status == 'Published'
                            ? AppColors.success
                            : AppColors.info),
                    if (blog.featured)
                      StatusPill(label: '★ Featured', color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: 12),
                Text(blog.title,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (blog.author.isNotEmpty) ...[
                      Text(blog.author,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const Text('  •  ',
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                    if (dateStr.isNotEmpty)
                      Text(dateStr,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    const Icon(Icons.visibility_outlined,
                        size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('${blog.views}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
                const Divider(height: 32),
                if (blog.overview.isNotEmpty) ...[
                  Text(blog.overview,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.5)),
                  const SizedBox(height: 16),
                ],
                Text(blog.content,
                    style: const TextStyle(fontSize: 15, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
