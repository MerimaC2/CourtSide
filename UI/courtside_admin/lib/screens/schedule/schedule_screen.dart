import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/availability_block.dart';
import '../../models/availability_slot.dart';
import '../../models/court.dart';
import '../../providers/availability_block_provider.dart';
import '../../providers/availability_provider.dart';
import '../../providers/court_provider.dart';
import '../../utils/util.dart';
import '../../widgets/dialog_header.dart';

class ScheduleScreen extends StatefulWidget {
  /// Whether this is the currently selected section. The admin shell keeps every
  /// section alive in an [IndexedStack], so the court list is reloaded whenever the
  /// section becomes visible again — courts added elsewhere appear right away.
  final bool isActive;

  const ScheduleScreen({super.key, this.isActive = true});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Court> _courts = [];
  int? _courtId;
  DateTime _selectedDate = DateTime.now();
  List<AvailabilitySlot> _slots = [];
  List<AvailabilityBlock> _blocks = [];
  bool _loadingCourts = true;
  bool _loadingSlots = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  @override
  void didUpdateWidget(covariant ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _refreshCourts();
  }

  Future<void> _loadCourts() async {
    try {
      final result =
          await context.read<CourtProvider>().get(filter: {'page': 1, 'pageSize': 200});
      if (!mounted) return;
      setState(() {
        _courts = result.result;
        _courtId = result.result.isNotEmpty ? result.result.first.id : null;
        _loadingCourts = false;
      });
      if (_courtId != null) _loadSchedule();
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _error = trMessage(context, message);
          _loadingCourts = false;
        });
      }
    }
  }

  Future<void> _loadSchedule() async {
    if (_courtId == null) return;
    setState(() {
      _loadingSlots = true;
      _error = null;
    });
    final availabilityProvider = context.read<AvailabilityProvider>();
    final blockProvider = context.read<AvailabilityBlockProvider>();
    try {
      final slots = await availabilityProvider.getSlots(_courtId!, _selectedDate);
      final blocks = await blockProvider.getBlocks(_courtId!, _selectedDate);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _blocks = blocks;
      });
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  /// Reloads the court list, keeping the current selection when that court still
  /// exists. The schedule is reloaded too, since blocks and reservations for the
  /// selected day may have changed while another section was open.
  Future<void> _refreshCourts() async {
    try {
      final result =
          await context.read<CourtProvider>().get(filter: {'page': 1, 'pageSize': 200});
      if (!mounted) return;
      final courts = result.result;
      setState(() {
        _courts = courts;
        if (_courtId == null || !courts.any((c) => c.id == _courtId)) {
          _courtId = courts.isNotEmpty ? courts.first.id : null;
        }
      });
      if (_courtId != null) await _loadSchedule();
    } catch (_) {
      // Keep the existing list if the refresh fails; the dropdown just stays as-is.
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSchedule();
    }
  }

  Future<void> _onSlotTap(AvailabilitySlot slot) async {
    if (slot.status == 'Reserved') {
      showSuccess(context, 'Termin je već rezervisan.');
      return;
    }
    if (slot.status == 'Blocked') {
      await _unblock(slot);
    } else {
      await _block(slot);
    }
  }

  Future<void> _block(AvailabilitySlot slot) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: dialogHeader(ctx, '${tr(ctx, 'Blokiraj termin')} ${slot.label}'),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(labelText: tr(ctx, 'Razlog (opciono)')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr(ctx, 'Odustani'))),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(reasonController.text.trim()),
            child: Text(tr(ctx, 'Blokiraj')),
          ),
        ],
      ),
    );
    if (reason == null) return;
    if (!mounted) return;
    final blockProvider = context.read<AvailabilityBlockProvider>();
    try {
      await blockProvider.block(
        courtId: _courtId!,
        date: _selectedDate,
        startTime: slot.startTime,
        endTime: slot.endTime,
        reason: reason,
      );
      if (mounted) showSuccess(context, 'Termin je blokiran.');
      _loadSchedule();
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _unblock(AvailabilitySlot slot) async {
    final matches = _blocks.where((b) => b.startTime == slot.startTime);
    final block = matches.isEmpty ? null : matches.first;
    if (block == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${tr(ctx, 'Odblokiraj termin')} ${slot.label}'),
        content: Text(block.reason?.isNotEmpty == true
            ? '${tr(ctx, 'Razlog blokade')}: ${block.reason}'
            : tr(ctx, 'Ukloniti blokadu ovog termina?')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr(ctx, 'Odustani'))),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr(ctx, 'Odblokiraj'))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final blockProvider = context.read<AvailabilityBlockProvider>();
    try {
      await blockProvider.deleteById(block.id);
      if (mounted) showSuccess(context, 'Blokada je uklonjena.');
      _loadSchedule();
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCourts) return const Center(child: CircularProgressIndicator());
    if (_courts.isEmpty) {
      return Center(child: Text(tr(context, 'Nema terena. Prvo dodajte teren.')));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _courtId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr(context, 'Teren')),
                  items: _courts
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _courtId = v);
                    _loadSchedule();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: tr(context, 'Datum')),
                    child: Row(
                      children: [
                        Text(formatDisplayDate(formatApiDate(_selectedDate))),
                        const Spacer(),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingSlots) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadSchedule, child: Text(tr(context, 'Pokušaj ponovo'))),
          ],
        ),
      );
    }
    if (_slots.isEmpty) {
      return Center(child: Text(tr(context, 'Nema definisanih termina za odabrani datum.')));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legend(),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemCount: _slots.length,
            itemBuilder: (_, i) => _slotTile(_slots[i]),
          ),
        ),
      ],
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 16,
      children: [
        _legendItem(kPrimaryColor, 'Slobodno (klik za blokiranje)'),
        _legendItem(Colors.grey, 'Rezervisano'),
        _legendItem(Colors.red.shade300, 'Blokirano (klik za odblokiranje)'),
        _legendItem(Colors.grey.shade400, 'Istekao termin', struck: true),
      ],
    );
  }

  Widget _legendItem(Color color, String label, {bool struck = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          tr(context, label),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            decoration: struck ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _slotTile(AvailabilitySlot slot) {
    final Color color;
    switch (slot.status) {
      case 'Blocked':
        color = Colors.red.shade300;
        break;
      case 'Reserved':
        color = Colors.grey;
        break;
      default:
        color = kPrimaryColor;
    }

    // A slot that has started keeps its status colour but is drawn faded and struck through,
    // so a reserved past slot still reads as reserved while being clearly spent.
    final tile = Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: slot.isPast ? 0.04 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: slot.isPast ? color.withValues(alpha: 0.35) : color),
      ),
      alignment: Alignment.center,
      child: Text(
        slot.label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: slot.isPast ? color.withValues(alpha: 0.5) : color,
          decoration: slot.isPast ? TextDecoration.lineThrough : null,
          decorationColor: color.withValues(alpha: 0.5),
        ),
      ),
    );

    if (slot.isPast) {
      return Tooltip(message: tr(context, 'Termin je istekao.'), child: tile);
    }

    return InkWell(
      onTap: () => _onSlotTap(slot),
      borderRadius: BorderRadius.circular(10),
      child: tile,
    );
  }
}
