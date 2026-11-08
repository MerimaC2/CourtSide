import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../../widgets/dialog_header.dart';
import '../../models/news.dart';
import '../../providers/base_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/image_validation.dart';
import '../../utils/util.dart';

class NewsFormResult {
  final String title;
  final String text;
  final DateTime publishedAt;
  final Uint8List? imageBytes;
  final String? imageFilename;
  final String? imageContentType;

  NewsFormResult({
    required this.title,
    required this.text,
    required this.publishedAt,
    this.imageBytes,
    this.imageFilename,
    this.imageContentType,
  });

  Map<String, dynamic> toBody() => {
        'title': title,
        'text': text,
        'publishedAt': publishedAt.toIso8601String(),
      };
}

/// Add/edit form for a [News] item, shown as a modal dialog. Returns a [NewsFormResult]
/// on save, or null if cancelled.
class NewsFormDialog extends StatefulWidget {
  final News? news;

  const NewsFormDialog({super.key, this.news});

  @override
  State<NewsFormDialog> createState() => _NewsFormDialogState();
}

class _NewsFormDialogState extends State<NewsFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _textController;
  late DateTime _publishedAt;
  Uint8List? _imageBytes;
  String? _imageError;
  String? _imageFilename;
  String? _imageContentType;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.news?.title ?? '');
    _textController = TextEditingController(text: widget.news?.text ?? '');
    _publishedAt = widget.news?.publishedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishedAt,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) setState(() => _publishedAt = picked);
  }

  Future<void> _pickImage() async {
    final file = await openFile(acceptedTypeGroups: [
      XTypeGroup(label: trMessage(context, 'Slika'), extensions: const ['jpg', 'jpeg', 'png', 'webp']),
    ]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final contentType = imageContentTypeFor(file.name);
    final error = validateImage(bytes, contentType);
    if (error != null) {
      // The rejected file replaces the preview so the form never shows an image it is not
      // going to save. Saving stays blocked until a valid file is picked or the pick is undone.
      setState(() {
        _imageError = error;
        _imageBytes = null;
        _imageFilename = null;
        _imageContentType = null;
      });
      return;
    }
    setState(() {
      _imageError = null;
      _imageBytes = bytes;
      _imageFilename = file.name;
      _imageContentType = contentType;
    });
  }

  /// Drops the rejected pick and restores whatever the announcement already had.
  void _clearImagePick() => setState(() => _imageError = null);

  Widget _buildImagePreview() {
    if (_imageError != null) return _rejectedImagePlaceholder();
    if (_imageBytes != null) return Image.memory(_imageBytes!, fit: BoxFit.cover);
    final news = widget.news;
    if (news != null && news.hasImage) {
      return Image.network(
        '${BaseProvider.baseUrl}news/${news.id}/image',
        headers: {'Authorization': 'Bearer ${Authorization.token}'},
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _rejectedImagePlaceholder() {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.08),
        border: Border.all(color: error),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: error),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
      );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      NewsFormResult(
        title: _titleController.text.trim(),
        text: _textController.text.trim(),
        publishedAt: _publishedAt,
        imageBytes: _imageBytes,
        imageFilename: _imageFilename,
        imageContentType: _imageContentType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: dialogHeader(context, tr(context, widget.news == null ? 'Nova obavijest' : 'Uređivanje obavijesti')),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: tr(context, 'Naslov')),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? trMessage(context, 'Unesite naslov') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _textController,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: tr(context, 'Tekst')),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? trMessage(context, 'Unesite tekst') : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: tr(context, 'Datum objave')),
                    child: Row(
                      children: [
                        Text(formatDisplayDate(formatApiDate(_publishedAt))),
                        const Spacer(),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(width: 64, height: 64, child: _buildImagePreview()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_outlined),
                        label: Text(tr(context, 'Odaberi sliku')),
                      ),
                    ),
                  ],
                ),
                if (_imageError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            trMessage(context, _imageError!),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearImagePick,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(tr(context, 'Poništi odabir'),
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(context, 'Odustani')),
        ),
        Tooltip(
          message: _imageError == null
              ? ''
              : tr(context, 'Odaberite ispravnu sliku ili poništite odabir.'),
          child: FilledButton(
            onPressed: _imageError == null ? _save : null,
            child: Text(tr(context, 'Sačuvaj')),
          ),
        ),
      ],
    );
  }
}
