import '../models/availability_block.dart';
import '../utils/util.dart';
import 'base_provider.dart';

class AvailabilityBlockProvider extends BaseProvider<AvailabilityBlock> {
  AvailabilityBlockProvider() : super('availability/blocks');

  @override
  AvailabilityBlock fromJson(Map<String, dynamic> json) => AvailabilityBlock.fromJson(json);

  Future<List<AvailabilityBlock>> getBlocks(int courtId, DateTime date) async {
    final result = await get(filter: {'courtId': courtId, 'date': formatApiDate(date)});
    return result.result;
  }

  Future<AvailabilityBlock> block({
    required int courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? reason,
  }) {
    return addAsync({
      'courtId': courtId,
      'date': formatApiDate(date),
      'startTime': startTime,
      'endTime': endTime,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }
}
