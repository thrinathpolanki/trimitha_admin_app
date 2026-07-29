import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/blog.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BlogEditorScreen extends StatefulWidget {
  final Blog? existing; // null = creating a new post
  const BlogEditorScreen({super.key, this.existing});

  @override
  State<BlogEditorScreen> createState() => _BlogEditorScreenState();
}

class _BlogEditorScreenState extends State<BlogEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _slugController;
  late final TextEditingController _overviewController;
  late final TextEditingController _contentController;
  late final TextEditingController _seoController;
  late final TextEditingController _metaController;
  late final TextEditingController _authorController;

  String _status = 'Draft';
  bool _featured = false;
  String _imageUrl = '';
  bool _uploadingImage = false;
  bool _saving = false;
  bool _slugManuallyEdited = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _titleController = TextEditingController(text: b?.title ?? '');
    _categoryController = TextEditingController(text: b?.category ?? '');
    _slugController = TextEditingController(text: b?.slug ?? '');
    _overviewController = TextEditingController(text: b?.overview ?? '');
    _contentController = TextEditingController(text: b?.content ?? '');
    _seoController = TextEditingController(text: b?.seoKeywords ?? '');
    _metaController = TextEditingController(text: b?.metaDescription ?? '');
    _authorController = TextEditingController(text: b?.author ?? '');
    _status = b?.status ?? 'Draft';
    _featured = b?.featured ?? false;
    _imageUrl = b?.image ?? '';
    _slugManuallyEdited = _isEditing; // don't auto-overwrite an existing slug

    _titleController.addListener(_autoFillSlug);
    _slugController.addListener(() => _slugManuallyEdited = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _slugController.dispose();
    _overviewController.dispose();
    _contentController.dispose();
    _seoController.dispose();
    _metaController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _autoFillSlug() {
    if (_slugManuallyEdited) return;
    final slug = _titleController.text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    _slugController.text = slug;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (file == null) return;

    setState(() => _uploadingImage = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      final base64Data = base64Encode(bytes);
      final ext = file.path.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      final result = await ApiService.instance
          .uploadImage(base64Data, file.name, mimeType);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _imageUrl = result['url'] as String);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result['error']?.toString() ?? 'Image upload failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read image: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save({required String statusOverride}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'category': _categoryController.text.trim(),
      'slug': _slugController.text.trim(),
      'overview': _overviewController.text.trim(),
      'content': _contentController.text.trim(),
      'status': statusOverride,
      'featured': _featured,
      'image': _imageUrl,
      'seoKeywords': _seoController.text.trim(),
      'metaDescription': _metaController.text.trim(),
      if (_authorController.text.trim().isNotEmpty)
        'author': _authorController.text.trim(),
    };

    final result = _isEditing
        ? await ApiService.instance
            .updateBlog({...data, 'row': widget.existing!.row})
        : await ApiService.instance.createBlog(data);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                result['error']?.toString() ?? 'Could not save this post')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Blog' : 'Create New Blog'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImagePicker(),
            const SizedBox(height: 20),
            _label('Title *'),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  hintText: 'Enter an engaging title for your blog...'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Category *'),
                      TextFormField(
                        controller: _categoryController,
                        decoration:
                            const InputDecoration(hintText: 'e.g. Technology'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Slug *'),
                      TextFormField(
                        controller: _slugController,
                        decoration:
                            const InputDecoration(hintText: 'your-blog-slug'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label('Overview *'),
            TextFormField(
              controller: _overviewController,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                  hintText:
                      'Write a short overview or excerpt for your blog...'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Overview is required'
                  : null,
            ),
            const SizedBox(height: 8),
            _label('Content *'),
            TextFormField(
              controller: _contentController,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: 'Start writing your blog content here...',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Content is required'
                  : null,
            ),
            const SizedBox(height: 16),
            _label('SEO Keywords'),
            TextFormField(
              controller: _seoController,
              decoration: const InputDecoration(
                  hintText: 'e.g. AI, Technology, Future (comma separated)'),
            ),
            const SizedBox(height: 16),
            _label('Meta Description'),
            TextFormField(
              controller: _metaController,
              maxLines: 2,
              maxLength: 160,
              decoration:
                  const InputDecoration(hintText: 'Write meta description...'),
            ),
            const SizedBox(height: 16),
            _label('Author'),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(
                  hintText: 'Defaults to "Admin" if left blank'),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured'),
                  subtitle: const Text('Show this blog on the homepage',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  value: _featured,
                  activeThumbColor: AppColors.teal,
                  onChanged: (v) => setState(() => _featured = v),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _label('Status'),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                DropdownMenuItem(value: 'Published', child: Text('Published')),
                DropdownMenuItem(value: 'Archived', child: Text('Archived')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'Draft'),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => _save(statusOverride: 'Draft'),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _save(
                            statusOverride: _status == 'Archived'
                                ? 'Archived'
                                : 'Published'),
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isEditing ? 'Save & Publish' : 'Publish Blog'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      );

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _uploadingImage ? null : _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        clipBehavior: Clip.antiAlias,
        child: _uploadingImage
            ? const Center(child: CircularProgressIndicator())
            : _imageUrl.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: AppColors.textMuted, size: 40),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.white, size: 18),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_outlined,
                          size: 34, color: AppColors.teal),
                      const SizedBox(height: 10),
                      const Text('Upload Cover Image',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Optional — JPG, PNG or WebP (max 8MB)',
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.textSecondary)),
                    ],
                  ),
      ),
    );
  }
}
