import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:provider/provider.dart';

import '../../models/availability_slot.dart';
import '../../models/court.dart';
import '../../models/reservation.dart';
import '../../providers/payment_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import 'booking_confirmation_screen.dart';

class BookingFormScreen extends StatefulWidget {
  final Court court;
  final DateTime date;
  final AvailabilitySlot slot;

  const BookingFormScreen({
    super.key,
    required this.court,
    required this.date,
    required this.slot,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  String _paymentMethod = 'Cash';
  bool _submitting = false;

  double get _hours {
    double toHours(String time) {
      final parts = time.split(':');
      return int.parse(parts[0]) + int.parse(parts[1]) / 60;
    }

    return toHours(widget.slot.endTime) - toHours(widget.slot.startTime);
  }

  double get _totalPrice => widget.court.pricePerHour * _hours;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: Authorization.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final reservation = await context.read<ReservationProvider>().create(
            courtId: widget.court.id,
            date: widget.date,
            startTime: widget.slot.startTime,
            endTime: widget.slot.endTime,
            contactName: _nameController.text.trim(),
            contactPhone: _phoneController.text.trim(),
            note: _noteController.text.trim(),
            paymentMethod: _paymentMethod,
          );

      if (_paymentMethod == 'Cash') {
        _goToConfirmation(reservation, paid: false);
        return;
      }

      await _payWithStripe(reservation.id);
      _goToConfirmation(reservation, paid: true);
    } on StripeException catch (e) {
      if (mounted) {
        showError(context,
            'Plaćanje nije završeno (${e.error.localizedMessage ?? e.error.code}). Rezervacija je kreirana kao neplaćena.');
      }
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _payWithStripe(int reservationId) async {
    final intent = await context.read<PaymentProvider>().createIntent(reservationId);
    Stripe.publishableKey = intent.publishableKey;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: intent.clientSecret,
        merchantDisplayName: 'CourtSide',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }

  void _goToConfirmation(Reservation reservation, {required bool paid}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(reservation: reservation, paid: paid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forma za rezervaciju'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryCard(),
              const SizedBox(height: 20),
              const Text('Podaci za rezervaciju',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ime i prezime',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Unesite ime i prezime' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Broj telefona',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Unesite broj telefona' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Napomena (opciono)',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Način plaćanja',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _paymentOption('Cash', Icons.payments_outlined, 'Gotovina pri dolasku'),
              _paymentOption('Stripe', Icons.credit_card, 'Online plaćanje karticom'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _submitting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _submit, child: const Text('Rezerviši')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Teren', widget.court.name),
            _summaryRow('Datum', formatDisplayDate(formatApiDate(widget.date))),
            _summaryRow('Termin', widget.slot.label),
            _summaryRow('Ukupno', formatPrice(_totalPrice)),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _paymentOption(String value, IconData icon, String label) {
    final selected = _paymentMethod == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kPrimaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? kPrimaryColor : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? kPrimaryColor : Colors.grey.shade600),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? kPrimaryColor : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
