import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:courtside_admin/models/availability_block.dart';
import 'package:courtside_admin/models/availability_slot.dart';
import 'package:courtside_admin/models/court.dart';
import 'package:courtside_admin/models/search_result.dart';
import 'package:courtside_admin/providers/availability_block_provider.dart';
import 'package:courtside_admin/providers/availability_provider.dart';
import 'package:courtside_admin/providers/court_provider.dart';
import 'package:courtside_admin/screens/schedule/schedule_screen.dart';
import 'package:courtside_admin/utils/app_locale.dart';

AvailabilitySlot _slot(String start, String end) =>
    AvailabilitySlot(startTime: start, endTime: end, status: 'Blocked', isPast: false);

class _OneCourtProvider extends CourtProvider {
  @override
  Future<SearchResult<Court>> get({Map<String, dynamic>? filter}) async => SearchResult<Court>()
    ..result.add(Court(
        id: 1, name: 'Teren 1', sportId: 1, sportCenterId: 1, pricePerHour: 20, isActive: true));
}

class _ReservedSlotProvider extends AvailabilityProvider {
  @override
  Future<List<AvailabilitySlot>> getSlots(int courtId, DateTime date) async => [
        AvailabilitySlot(
            startTime: '10:00:00', endTime: '11:00:00', status: 'Reserved', isPast: false),
      ];
}

/// Records whether a block was sent to the API, without touching the network.
class _RecordingBlockProvider extends AvailabilityBlockProvider {
  int blockCalls = 0;

  @override
  Future<List<AvailabilityBlock>> getBlocks(int courtId, DateTime date) async => [];

  @override
  Future<AvailabilityBlock> block({
    required int courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    blockCalls++;
    throw Exception('U tom periodu već postoji rezervacija pa se ne može blokirati.');
  }
}

void main() {
  final twoHourBlock = AvailabilityBlock(
      id: 7, courtId: 1, date: '2026-11-10', startTime: '10:00:00', endTime: '12:00:00');
  final oneHourBlock = AvailabilityBlock(
      id: 8, courtId: 1, date: '2026-11-10', startTime: '15:00:00', endTime: '16:00:00');
  final blocks = [twoHourBlock, oneHourBlock];

  test('every slot inside a multi-slot block resolves to that block', () {
    expect(blockCoveringSlot(blocks, _slot('10:00:00', '11:00:00'))?.id, 7);
    expect(blockCoveringSlot(blocks, _slot('11:00:00', '12:00:00'))?.id, 7);
  });

  test('a single-slot block resolves to itself', () {
    expect(blockCoveringSlot(blocks, _slot('15:00:00', '16:00:00'))?.id, 8);
  });

  test('slots next to a block are not covered by it', () {
    expect(blockCoveringSlot(blocks, _slot('09:00:00', '10:00:00')), isNull);
    expect(blockCoveringSlot(blocks, _slot('12:00:00', '13:00:00')), isNull);
  });

  testWidgets('a reserved slot is refused with the same error the server gives',
      (WidgetTester tester) async {
    final blockProvider = _RecordingBlockProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<CourtProvider>(create: (_) => _OneCourtProvider()),
          ChangeNotifierProvider<AvailabilityProvider>(create: (_) => _ReservedSlotProvider()),
          ChangeNotifierProvider<AvailabilityBlockProvider>.value(value: blockProvider),
        ],
        child: const MaterialApp(home: Scaffold(body: ScheduleScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('10:00 - 11:00'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('U tom periodu već postoji rezervacija pa se ne može blokirati.'),
        findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, Colors.red);
    expect(find.byType(AlertDialog), findsNothing);
    expect(blockProvider.blockCalls, 0);
  });
}
