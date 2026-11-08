import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../../widgets/dialog_header.dart';
import '../../models/country.dart';

class CountryFormResult {
  final String name;
  final String? isoCode;

  CountryFormResult({required this.name, this.isoCode});

  Map<String, dynamic> toBody() => {
        'name': name,
        if (isoCode != null && isoCode!.isNotEmpty) 'isoCode': isoCode,
      };
}

/// Add/edit form for a [Country], shown as a modal dialog. Returns a [CountryFormResult]
/// on save, or null if cancelled.
class CountryFormDialog extends StatefulWidget {
  final Country? country;

  const CountryFormDialog({super.key, this.country});

  @override
  State<CountryFormDialog> createState() => _CountryFormDialogState();
}

class _CountryFormDialogState extends State<CountryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _isoCodeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.country?.name ?? '');
    _isoCodeController = TextEditingController(text: widget.country?.isoCode ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isoCodeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CountryFormResult(
        name: _nameController.text.trim(),
        isoCode: _isoCodeController.text.trim().toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: dialogHeader(context, tr(context, widget.country == null ? 'Nova država' : 'Uređivanje države')),
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
                controller: _isoCodeController,
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: tr(context, 'ISO kod (opciono)'),
                  hintText: 'BIH',
                ),
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
