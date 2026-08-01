import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class ContactDetailScreen extends StatefulWidget {
  final Contact contact;
  final String sheet;

  const ContactDetailScreen(
      {super.key, required this.contact, required this.sheet});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late Contact _contact;
  late TextEditingController _notesController;
  bool _savingNotes = false;
  bool _editingNotes = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _notesController = TextEditingController(text: _contact.notes);
    // Opening the detail view counts as "reading" it.
    if (_contact.isUnread) _markRead();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final result = await ApiService.instance
        .updateContact(widget.sheet, _contact.row, status: 'Read');
    if (result['success'] == true && mounted) {
      setState(() => _contact = _contact.copyWith(status: 'Read'));
      NotificationService.instance.refreshNow();
    }
  }

  Future<void> _toggleStar() async {
    final newVal = !_contact.starred;
    setState(() => _contact = _contact.copyWith(starred: newVal)); // optimistic
    final result = await ApiService.instance
        .updateContact(widget.sheet, _contact.row, starred: newVal);
    if (result['success'] != true && mounted) {
      setState(() => _contact = _contact.copyWith(starred: !newVal)); // revert
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    final result = await ApiService.instance.updateContact(
        widget.sheet, _contact.row,
        notes: _notesController.text.trim());
    if (mounted) {
      setState(() {
        _savingNotes = false;
        _editingNotes = false;
        if (result['success'] == true) {
          _contact = _contact.copyWith(notes: _notesController.text.trim());
        }
      });
      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result['error']?.toString() ?? 'Could not save notes')),
        );
      }
    }
  }

  Future<void> _emailContact() async {
    final uri = Uri(
        scheme: 'mailto',
        path: _contact.email,
        queryParameters: {'subject': 'Re: ${_contact.subject}'});
    if (!await launchUrl(uri)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open email app')));
    }
  }

  void _copyAll(BuildContext context) {
    final text =
        '${_contact.name}\n${_contact.email}\nSubject: ${_contact.subject}\n\n${_contact.message}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copied to clipboard'), duration: Duration(seconds: 1)));
  }

  void _share() {
    Share.share(
        '${_contact.name} (${_contact.email})\nSubject: ${_contact.subject}\n\n${_contact.message}');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this submission?'),
        content: const Text('This can\'t be undone from the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result =
        await ApiService.instance.deleteContact(widget.sheet, _contact.row);
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pop(context, true); // tell the list to remove/refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['error']?.toString() ?? 'Could not delete')),
      );
    }
  }

  String get _initials {
    final parts = _contact.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _contact.timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(_contact.timestamp!)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Detail'),
        actions: [
          IconButton(
            icon: Icon(
                _contact.starred
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: _contact.starred ? AppColors.warning : null),
            onPressed: _toggleStar,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.teal.withOpacity(0.18),
                    child: Text(_initials,
                        style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_contact.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        StatusPill(
                            label: _contact.isUnread ? 'Unread' : 'Read',
                            color: _contact.isUnread
                                ? AppColors.teal
                                : AppColors.textMuted),
                        const SizedBox(height: 6),
                        Text(_contact.email,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (dateStr.isNotEmpty)
                    Text(dateStr,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                        textAlign: TextAlign.right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _QuickAction(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  color: AppColors.info,
                  onTap: _emailContact),
              _QuickAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  color: AppColors.purple,
                  onTap: () => _copyAll(context)),
              _QuickAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  color: AppColors.teal,
                  onTap: _share),
              _QuickAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: AppColors.danger,
                  onTap: _delete),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                      icon: Icons.label_outline_rounded,
                      label: 'Subject',
                      value: _contact.subject),
                  const Divider(height: 24),
                  _DetailRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Message',
                      value: _contact.message),
                  const Divider(height: 24),
                  _DetailRow(
                      icon: Icons.public_rounded,
                      label: 'Source',
                      value: _contact.source),
                  if (dateStr.isNotEmpty) ...[
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.event_outlined,
                        label: 'Submitted',
                        value: dateStr),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 8),
                      const Text('Notes',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (!_editingNotes)
                        TextButton.icon(
                          onPressed: () => setState(() => _editingNotes = true),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Add Notes'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_editingNotes) ...[
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          hintText: 'Private follow-up notes...'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _savingNotes
                              ? null
                              : () => setState(() => _editingNotes = false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _savingNotes ? null : _saveNotes,
                          child: _savingNotes
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      _contact.notes.isEmpty ? 'No notes yet.' : _contact.notes,
                      style: TextStyle(
                          color: _contact.notes.isEmpty
                              ? AppColors.textMuted
                              : AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13.5, height: 1.4)),
        ),
      ],
    );
  }
}
