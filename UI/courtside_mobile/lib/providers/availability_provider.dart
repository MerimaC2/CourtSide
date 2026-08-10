import '../models/availability_slot.dart';
import '../utils/util.dart';
import 'base_provider.dart';

class AvailabilityProvider extends BaseProvider<AvailabilitySlot> {
  AvailabilityProvider() : super('availability/slots');

  @override
  AvailabilitySlot fromJson(Map<String, dynamic> json) => AvailabilitySlot.fromJson(json);

  Future<List<AvailabilitySlot>> getSlots(int courtId, DateTime date) async {
    final result = await get(filter: {'courtId': courtId, 'date': formatApiDate(date)});
    return result.result;
  }
}
