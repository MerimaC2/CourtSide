import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../l10n/translations.dart';
import '../../utils/util.dart';
import '../../widgets/dialog_header.dart';

class CoordinateResult {
  final double latitude;
  final double longitude;
  final String displayName;

  CoordinateResult({required this.latitude, required this.longitude, required this.displayName});
}

/// Picks a sport centre's location on a map, so coordinates are never typed by hand.
/// The address box is a shortcut that recentres the map via OpenStreetMap's Nominatim
/// geocoder; the pin itself is always what decides the saved coordinates.
class CoordinatePickerDialog extends StatefulWidget {
  final String? initialQuery;
  final double? initialLatitude;
  final double? initialLongitude;

  const CoordinatePickerDialog({
    super.key,
    this.initialQuery,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<CoordinatePickerDialog> createState() => _CoordinatePickerDialogState();
}

class _CoordinatePickerDialogState extends State<CoordinatePickerDialog> {
  /// Falls back to the centre of Bosnia and Herzegovina when nothing is set yet.
  static const _fallbackCenter = LatLng(43.9159, 17.6791);

  final _mapController = MapController();
  late final TextEditingController _queryController;
  LatLng? _selected;
  String _displayName = '';
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selected = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
      });
      final response = await http.get(uri, headers: {'User-Agent': 'CourtSide-Admin/1.0'});
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final data = jsonDecode(response.body) as List;
      if (data.isEmpty) {
        if (mounted) setState(() => _error = 'Adresa nije pronađena. Označite lokaciju na karti.');
        return;
      }
      final first = data.first;
      final point = LatLng(
        double.parse(first['lat'] as String),
        double.parse(first['lon'] as String),
      );
      if (!mounted) return;
      setState(() {
        _selected = point;
        _displayName = first['display_name'] as String? ?? '';
      });
      _mapController.move(point, 15);
    } catch (_) {
      if (mounted) setState(() => _error = 'Pretraga koordinata nije uspjela. Pokušajte ponovo.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _selected = point;
      _displayName = '';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return AlertDialog(
      title: dialogHeader(context, tr(context, 'Odaberi lokaciju na karti')),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(labelText: tr(context, 'Adresa ili grad')),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  tooltip: tr(context, 'Pretraži'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(tr(context, 'Kliknite na kartu da postavite oznaku.'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: selected ?? _fallbackCenter,
                    initialZoom: selected != null ? 15 : 7,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.courtside.courtside_admin',
                    ),
                    if (selected != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selected,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(trMessage(context, _error!), style: const TextStyle(color: Colors.red, fontSize: 12))
            else
              Text(
                selected == null
                    ? tr(context, 'Lokacija nije odabrana')
                    : '${selected.latitude.toStringAsFixed(5)}, ${selected.longitude.toStringAsFixed(5)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected == null ? Colors.grey.shade600 : kPrimaryColor,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: selected == null
              ? null
              : () => Navigator.of(context).pop(CoordinateResult(
                    latitude: selected.latitude,
                    longitude: selected.longitude,
                    displayName: _displayName,
                  )),
          child: Text(tr(context, 'Sačuvaj')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(context, 'Odustani')),
        ),
      ],
    );
  }
}
