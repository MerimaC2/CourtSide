import 'package:flutter/material.dart';

import '../../models/court.dart';
import '../../models/sport.dart';
import '../../models/sport_center.dart';

class CourtFormResult {
  final String name;
  final String? description;
  final int sportId;
  final int sportCenterId;
  final double pricePerHour;
  final bool isActive;

  CourtFormResult({
    required this.name,
    this.description,
    required this.sportId,
    required this.sportCenterId,
    required this.pricePerHour,
    required this.isActive,
  });

  Map<String, dynamic> toBody() => {
        'name': name,
        if (description != null && description!.isNotEmpty) 'description': description,
        'sportId': sportId,
        'sportCenterId': sportCenterId,
        'pricePerHour': pricePerHour,
        'isActive': isActive,
      };
}

/// Add/edit form for a [Court], shown as a modal dialog. Returns a [CourtFormResult]
/// on save, or null if cancelled.
class CourtFormDialog extends StatefulWidget {
  final Court? court;
  final List<Sport> sports;
  final List<SportCenter> sportCenters;

  const CourtFormDialog({
    super.key,
    this.court,
    required this.sports,
    required this.sportCenters,
  });

  @override
  State<CourtFormDialog> createState() => _CourtFormDialogState();
}

class _CourtFormDialogState extends State<CourtFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  int? _sportId;
  int? _sportCenterId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final court = widget.court;
    _nameController = TextEditingController(text: court?.name ?? '');
    _descriptionController = TextEditingController(text: court?.description ?? '');
    _priceController = TextEditingController(text: court?.pricePerHour.toString() ?? '');
    _sportId = court?.sportId;
    _sportCenterId = court?.sportCenterId;
    _isActive = court?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_sportId == null || _sportCenterId == null) return;
    Navigator.of(context).pop(
      CourtFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        sportId: _sportId!,
        sportCenterId: _sportCenterId!,
        pricePerHour: double.parse(_priceController.text.trim().replaceAll(',', '.')),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.court == null ? 'Novi teren' : 'Uređivanje terena'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Naziv'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Unesite naziv' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _sportId,
                  decoration: const InputDecoration(labelText: 'Sport'),
                  items: widget.sports
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _sportId = v),
                  validator: (v) => v == null ? 'Odaberite sport' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _sportCenterId,
                  decoration: const InputDecoration(labelText: 'Sportski centar'),
                  items: widget.sportCenters
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _sportCenterId = v),
                  validator: (v) => v == null ? 'Odaberite sportski centar' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cijena po satu (KM)'),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                    if (value == null || value <= 0) return 'Unesite ispravnu cijenu';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Opis (opciono)'),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktivan'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(onPressed: _save, child: const Text('Sačuvaj')),
      ],
    );
  }
}
