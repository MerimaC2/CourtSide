import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/availability_slot.dart';
import '../../models/court.dart';
import '../../providers/availability_provider.dart';
import '../../utils/util.dart';
import 'booking_form_screen.dart';

class AvailabilityScreen extends StatefulWidget {
  final Court court;

  const AvailabilityScreen({super.key, required this.court});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  DateTime _selectedDate = DateTime.now();
  List<AvailabilitySlot> _slots = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots =
          await context.read<AvailabilityProvider>().getSlots(widget.court.id, _selectedDate);
      if (!mounted) return;
      setState(() => _slots = slots);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSlots();
    }
  }

  void _selectSlot(AvailabilitySlot slot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BookingFormScreen(court: widget.court, date: _selectedDate, slot: slot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dostupnost — ${widget.court.name}'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildDateBar(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildDateBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: kPrimaryColor, size: 20),
              const SizedBox(width: 10),
              Text(formatDisplayDate(formatApiDate(_selectedDate)),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadSlots, child: const Text('Pokušaj ponovo')),
            ],
          ),
        ),
      );
    }
    if (_slots.isEmpty) {
      return const Center(child: Text('Nema definisanih termina za odabrani datum.'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legend(),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: _slots.length,
              itemBuilder: (_, i) => _slotTile(_slots[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 16,
      children: [
        _legendItem(kPrimaryColor, 'Slobodno'),
        _legendItem(Colors.grey, 'Zauzeto'),
        _legendItem(Colors.red.shade300, 'Blokirano'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _slotTile(AvailabilitySlot slot) {
    final Color color;
    switch (slot.status) {
      case 'Available':
        color = kPrimaryColor;
        break;
      case 'Blocked':
        color = Colors.red.shade300;
        break;
      default:
        color = Colors.grey;
    }
    return InkWell(
      onTap: slot.isAvailable ? () => _selectSlot(slot) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: slot.isAvailable ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: slot.isAvailable ? color : Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(
          slot.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: slot.isAvailable ? color : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
