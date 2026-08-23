import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../../models/city.dart';
import '../../models/sport_center.dart';
import '../../widgets/dialog_header.dart';
import 'coordinate_picker_dialog.dart';

class SportCenterFormResult {
  final String name;
  final String address;
  final String? description;
  final int cityId;
  final double? latitude;
  final double? longitude;

  SportCenterFormResult({
    required this.name,
    required this.address,
    this.description,
    required this.cityId,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toBody() => {
        'name': name,
        'address': address,
        if (description != null && description!.isNotEmpty) 'description': description,
        'cityId': cityId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// Add/edit form for a [SportCenter], shown as a modal dialog. Coordinates are never typed
/// directly — they are only ever set by placing a pin in [CoordinatePickerDialog].
/// Returns a [SportCenterFormResult] on save, or null if cancelled.
class SportCenterFormDialog extends StatefulWidget {
  final SportCenter? sportCenter;
  final List<City> cities;

  const SportCenterFormDialog({super.key, this.sportCenter, required this.cities});

  @override
  State<SportCenterFormDialog> createState() => _SportCenterFormDialogState();
}

class _SportCenterFormDialogState extends State<SportCenterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  int? _cityId;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sportCenter?.name ?? '');
    _addressController = TextEditingController(text: widget.sportCenter?.address ?? '');
    _descriptionController = TextEditingController(text: widget.sportCenter?.description ?? '');
    _cityId = widget.sportCenter?.cityId;
    _latitude = widget.sportCenter?.latitude;
    _longitude = widget.sportCenter?.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCoordinates() async {
    final result = await showDialog<CoordinateResult>(
      context: context,
      builder: (_) => CoordinatePickerDialog(
        initialQuery: _addressController.text.trim(),
        initialLatitude: _latitude,
        initialLongitude: _longitude,
      ),
    );
    if (result == null) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_cityId == null) return;
    Navigator.of(context).pop(
      SportCenterFormResult(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim(),
        cityId: _cityId!,
        latitude: _latitude,
        longitude: _longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: dialogHeader(context,
          tr(context, widget.sportCenter == null ? 'Novi sportski centar' : 'Uređivanje sportskog centra')),
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
                  controller: _nameController,
                  decoration: InputDecoration(labelText: tr(context, 'Naziv')),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? tr(context, 'Unesite naziv') : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _cityId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr(context, 'Grad')),
                  items: widget.cities
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _cityId = v),
                  validator: (v) => v == null ? tr(context, 'Odaberite grad') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(labelText: tr(context, 'Adresa')),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? tr(context, 'Unesite adresu') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: tr(context, 'Opis (opciono)')),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _latitude != null && _longitude != null
                              ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                              : tr(context, 'Koordinate nisu postavljene'),
                          style: TextStyle(
                              color: _latitude != null ? null : Colors.grey.shade600),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickCoordinates,
                        child: Text(tr(context, 'Odaberi na karti')),
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
        FilledButton(onPressed: _save, child: Text(tr(context, 'Sačuvaj'))),
      ],
    );
  }
}
