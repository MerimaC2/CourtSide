import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../../widgets/dialog_header.dart';
import '../../models/city.dart';
import '../../models/country.dart';

class CityFormResult {
  final String name;
  final String? postalCode;
  final int countryId;

  CityFormResult({required this.name, this.postalCode, required this.countryId});

  Map<String, dynamic> toBody() => {
        'name': name,
        if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
        'countryId': countryId,
      };
}

/// Add/edit form for a [City], shown as a modal dialog. Returns a [CityFormResult]
/// on save, or null if cancelled.
class CityFormDialog extends StatefulWidget {
  final City? city;
  final List<Country> countries;

  const CityFormDialog({super.key, this.city, required this.countries});

  @override
  State<CityFormDialog> createState() => _CityFormDialogState();
}

class _CityFormDialogState extends State<CityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _postalCodeController;
  int? _countryId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.city?.name ?? '');
    _postalCodeController = TextEditingController(text: widget.city?.postalCode ?? '');
    _countryId = widget.city?.countryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_countryId == null) return;
    Navigator.of(context).pop(
      CityFormResult(
        name: _nameController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        countryId: _countryId!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: dialogHeader(context, tr(context, widget.city == null ? 'Novi grad' : 'Uređivanje grada')),
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
                    (v == null || v.trim().isEmpty) ? tr(context, 'Unesite naziv') : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _countryId,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr(context, 'Država')),
                items: widget.countries
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _countryId = v),
                validator: (v) => v == null ? tr(context, 'Odaberite državu') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _postalCodeController,
                decoration: InputDecoration(labelText: tr(context, 'Poštanski broj (opciono)')),
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
