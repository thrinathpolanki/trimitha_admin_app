import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/contact.dart';
import '../theme/app_theme.dart';

class ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback onView;
  final VoidCallback onToggleStar;
  final VoidCallback onDelete;

  const ContactCard({
    super.key,
    required this.contact,
    required this.onView,
    required this.onToggleStar,
    required this.onDelete,
  });

  String get _initials {
    final parts = contact.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color get _avatarColor {
    final hash = contact.name.codeUnits.fold<int>(0, (a, b) => a + b);
    return AppColors.palette[hash % AppColors.palette.length];
  }

  void _copy(BuildContext context) {
    final text =
        '${contact.name}\n${contact.email}\nSubject: ${contact.subject}\n\n${contact.message}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _share() {
    Share.share(
      '${contact.name} (${contact.email})\nSubject: ${contact.subject}\n\n${contact.message}',
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this submission?'),
        content: Text(
            'This will remove ${contact.name}\'s message. This can\'t be undone from the app.'),
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
    final dateStr = contact.timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(contact.timestamp!)
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _avatarColor.withValues(alpha: 0.2),
                  child: Text(_initials,
                      style: TextStyle(
                          color: _avatarColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onToggleStar,
                            child: Icon(
                              contact.starred
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: contact.starred
                                  ? AppColors.warning
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(contact.email,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12.5),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (dateStr.isNotEmpty)
                      Text(dateStr,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10.5)),
                    const SizedBox(height: 6),
                    StatusPill(
                      label: contact.isUnread ? 'Unread' : 'Read',
                      color: contact.isUnread
                          ? AppColors.teal
                          : AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contact.subject.isNotEmpty) ...[
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                        text: 'Subject: ',
                        style: TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    TextSpan(
                        text: contact.subject,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              contact.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.public_rounded,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(contact.source,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _ActionButton(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    color: AppColors.info,
                    onTap: onView),
                _ActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Share',
                    color: AppColors.teal,
                    onTap: _share),
                _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    color: AppColors.purple,
                    onTap: () => _copy(context)),
                _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: AppColors.danger,
                    onTap: () => _confirmDelete(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
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
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
