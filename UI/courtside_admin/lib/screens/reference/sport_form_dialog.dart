import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../../widgets/dialog_header.dart';
import '../../models/sport.dart';

class SportFormResult {
  final String name;
  final String? description;

  SportFormResult({required this.name, this.description});

  Map<String, dynamic> toBody() => {
        'name': name,
        if (description != null && description!.isNotEmpty) 'description': description,
      };
}

/// Add/edit form for a [Sport], shown as a modal dialog. Returns a [SportFormResult]
/// on save, or null if cancelled.
class SportFormDialog extends StatefulWidget {
  final Sport? sport;

  const SportFormDialog({super.key, this.sport});

  @override
  State<SportFormDialog> createState() => _SportFormDialogState();
}

class _SportFormDialogState extends State<SportFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sport?.name ?? '');
    _descriptionController = TextEditingController(text: widget.sport?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      SportFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: dialogHeader(context, tr(context, widget.sport == null ? 'Novi sport' : 'Uređivanje sporta')),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: tr(context, 'Naziv')),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? trMessage(context, 'Unesite naziv') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(labelText: tr(context, 'Opis (opciono)')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(context, 'Odustani')),
        ),
        FilledButton(onPressed: _save, child: Text(tr(context, 'Sačuvaj'))),
      ],
    );
  }
}
