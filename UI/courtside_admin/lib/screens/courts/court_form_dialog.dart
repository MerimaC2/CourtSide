import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../../models/court.dart';
import '../../models/court_working_hours.dart';
import '../../models/sport.dart';
import '../../models/sport_center.dart';
import '../../providers/base_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/image_validation.dart';
import '../../widgets/dialog_header.dart';

class CourtFormResult {
  final String name;
  final String? description;
  final int sportId;
  final int sportCenterId;
  final double pricePerHour;
  final bool isActive;
  final Uint8List? imageBytes;
  final String? imageFilename;
  final String? imageContentType;
  final List<CourtWorkingHours> workingHours;

  CourtFormResult({
    required this.name,
    this.description,
    required this.sportId,
    required this.sportCenterId,
    required this.pricePerHour,
    required this.isActive,
    this.imageBytes,
    this.imageFilename,
    this.imageContentType,
    this.workingHours = const [],
  });

  Map<String, dynamic> toBody() => {
        'name': name,
        if (description != null && description!.isNotEmpty) 'description': description,
        'sportId': sportId,
        'sportCenterId': sportCenterId,
        'pricePerHour': pricePerHour,
        'isActive': isActive,
        'workingHours': workingHours.map((w) => w.toJson()).toList(),
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
  Uint8List? _imageBytes;
  String? _imageError;
  String? _workingHoursError;
  String? _imageFilename;
  String? _imageContentType;

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
    _loadWorkingHours(court?.workingHours ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Slika', extensions: ['jpg', 'jpeg', 'png', 'webp']),
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

  /// Drops the rejected pick and restores whatever the court already had.
  void _clearImagePick() => setState(() => _imageError = null);

  Widget _buildImagePreview() {
    if (_imageError != null) return _rejectedImagePlaceholder();
    if (_imageBytes != null) {
      return Image.memory(_imageBytes!, fit: BoxFit.cover);
    }
    final court = widget.court;
    if (court?.primaryImageId != null) {
      return Image.network(
        '${BaseProvider.baseUrl}courts/${court!.id}/images/${court.primaryImageId}',
        headers: {'Authorization': 'Bearer ${Authorization.token}'},
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() => Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
      );

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

  /// One row per weekday: whether the court is open and, if so, between which hours.
  /// Availability is generated from these, so a court with no open days can never be booked.
  static const _dayNames = [
    'Ponedjeljak',
    'Utorak',
    'Srijeda',
    'Četvrtak',
    'Petak',
    'Subota',
    'Nedjelja',
  ];

  /// Row order is Monday-first; the API identifies days by their DayOfWeek name.
  static const _apiDayOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<bool> _dayOpen = List<bool>.filled(7, true);
  final List<TimeOfDay> _dayOpenTime =
      List<TimeOfDay>.filled(7, const TimeOfDay(hour: 8, minute: 0));
  final List<TimeOfDay> _dayCloseTime =
      List<TimeOfDay>.filled(7, const TimeOfDay(hour: 22, minute: 0));

  void _loadWorkingHours(List<CourtWorkingHours> hours) {
    if (hours.isEmpty) return;
    for (var i = 0; i < 7; i++) {
      final match = hours.where((h) => h.dayOfWeek == _apiDayOfWeek[i]);
      if (match.isEmpty) {
        _dayOpen[i] = false;
        continue;
      }
      _dayOpen[i] = true;
      _dayOpenTime[i] = _parseTime(match.first.openTime, const TimeOfDay(hour: 8, minute: 0));
      _dayCloseTime[i] = _parseTime(match.first.closeTime, const TimeOfDay(hour: 22, minute: 0));
    }
  }

  static TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatApiTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  List<CourtWorkingHours> _collectWorkingHours() {
    final result = <CourtWorkingHours>[];
    for (var i = 0; i < 7; i++) {
      if (!_dayOpen[i]) continue;
      result.add(CourtWorkingHours(
        dayOfWeek: _apiDayOfWeek[i],
        openTime: _formatApiTime(_dayOpenTime[i]),
        closeTime: _formatApiTime(_dayCloseTime[i]),
      ));
    }
    return result;
  }

  Future<void> _pickTime(int dayIndex, {required bool opening}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: opening ? _dayOpenTime[dayIndex] : _dayCloseTime[dayIndex],
    );
    if (picked == null) return;
    setState(() {
      if (opening) {
        _dayOpenTime[dayIndex] = picked;
      } else {
        _dayCloseTime[dayIndex] = picked;
      }
    });
  }

  bool _workingHoursValid() {
    for (var i = 0; i < 7; i++) {
      if (!_dayOpen[i]) continue;
      final open = _dayOpenTime[i].hour * 60 + _dayOpenTime[i].minute;
      final close = _dayCloseTime[i].hour * 60 + _dayCloseTime[i].minute;
      if (close <= open) return false;
    }
    return _dayOpen.any((open) => open);
  }

  Widget _buildWorkingHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, 'Radno vrijeme'),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(tr(context, 'Termini se generišu iz radnog vremena.'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        for (var i = 0; i < 7; i++)
          Row(
            children: [
              SizedBox(
                width: 150,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _dayOpen[i],
                  title: Text(tr(context, _dayNames[i]), style: const TextStyle(fontSize: 13)),
                  onChanged: (v) => setState(() => _dayOpen[i] = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _dayOpen[i] ? () => _pickTime(i, opening: true) : null,
                child: Text(_dayOpenTime[i].format(context)),
              ),
              const Text('–'),
              TextButton(
                onPressed: _dayOpen[i] ? () => _pickTime(i, opening: false) : null,
                child: Text(_dayCloseTime[i].format(context)),
              ),
            ],
          ),
        if (_workingHoursError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trMessage(context, _workingHoursError!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_sportId == null || _sportCenterId == null) return;
    if (!_workingHoursValid()) {
      // Shown inside the dialog: a snackbar would land behind the modal barrier.
      setState(() => _workingHoursError =
          "Teren mora biti otvoren barem jedan dan, a zatvaranje mora biti nakon otvaranja.");
      return;
    }
    setState(() => _workingHoursError = null);
    Navigator.of(context).pop(
      CourtFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        sportId: _sportId!,
        sportCenterId: _sportCenterId!,
        pricePerHour: double.parse(_priceController.text.trim().replaceAll(',', '.')),
        isActive: _isActive,
        imageBytes: _imageBytes,
        imageFilename: _imageFilename,
        imageContentType: _imageContentType,
        workingHours: _collectWorkingHours(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: dialogHeader(context, tr(context, widget.court == null ? 'Novi teren' : 'Uređivanje terena')),
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
                  initialValue: _sportId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sport'),
                  items: widget.sports
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _sportId = v),
                  validator: (v) => v == null ? tr(context, 'Odaberite sport') : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _sportCenterId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr(context, 'Sportski centar')),
                  items: widget.sportCenters
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _sportCenterId = v),
                  validator: (v) => v == null ? tr(context, 'Odaberite sportski centar') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr(context, 'Cijena po satu (KM)')),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                    if (value == null || value <= 0) return tr(context, 'Unesite ispravnu cijenu');
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: tr(context, 'Opis (opciono)')),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: _buildImagePreview(),
                      ),
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
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(context, 'Aktivan')),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const Divider(height: 24),
                _buildWorkingHours(),
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
