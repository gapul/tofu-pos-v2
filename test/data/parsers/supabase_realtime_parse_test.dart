import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tofu_pos/core/sync/supabase_realtime_listener.dart';

PostgresChangePayload _payload(
  PostgresChangeEvent type,
  Map<String, dynamic> newRecord, {
  Map<String, dynamic>? oldRecord,
}) {
  return PostgresChangePayload(
    schema: 'public',
    table: 'order_lines',
    commitTimestamp: DateTime.utc(2026, 5, 11, 10),
    eventType: type,
    newRecord: newRecord,
    oldRecord: oldRecord ?? <String, dynamic>{},
    errors: null,
  );
}

void main() {
  group(
    'SupabaseRealtimeListener.parsePayload (boundary input validation)',
    () {
      test('valid INSERT payload returns event', () {
        final RealtimeOrderLineEvent? ev =
            SupabaseRealtimeListener.parsePayload(
              _payload(
                PostgresChangeEvent.insert,
                <String, dynamic>{
                  'shop_id': 's1',
                  'local_order_id': 10,
                  'line_no': 1,
                  'ticket_number': 7,
                  'product_name': 'Yakisoba',
                  'quantity': 2,
                  'is_cancelled': false,
                  'order_status': 'served',
                },
              ),
            );
        expect(ev, isNotNull);
        expect(ev!.shopId, 's1');
        expect(ev.localOrderId, 10);
        expect(ev.lineNo, 1);
      });

      test('empty newRecord on insert returns null (drop, no throw)', () {
        final RealtimeOrderLineEvent? ev =
            SupabaseRealtimeListener.parsePayload(
              _payload(PostgresChangeEvent.insert, <String, dynamic>{}),
            );
        expect(ev, isNull);
      });

      test('missing shop_id returns null (drop)', () {
        final RealtimeOrderLineEvent? ev =
            SupabaseRealtimeListener.parsePayload(
              _payload(
                PostgresChangeEvent.insert,
                <String, dynamic>{
                  'local_order_id': 10,
                  'line_no': 1,
                },
              ),
            );
        expect(ev, isNull);
      });

      test('missing local_order_id returns null (drop)', () {
        final RealtimeOrderLineEvent? ev =
            SupabaseRealtimeListener.parsePayload(
              _payload(
                PostgresChangeEvent.insert,
                <String, dynamic>{
                  'shop_id': 's1',
                  'line_no': 1,
                },
              ),
            );
        expect(ev, isNull);
      });

      test('DELETE uses oldRecord and works the same', () {
        final RealtimeOrderLineEvent? ev =
            SupabaseRealtimeListener.parsePayload(
              _payload(
                PostgresChangeEvent.delete,
                <String, dynamic>{},
                oldRecord: <String, dynamic>{
                  'shop_id': 's1',
                  'local_order_id': 10,
                  'line_no': 1,
                  'ticket_number': 7,
                  'product_name': 'X',
                  'quantity': 1,
                  'is_cancelled': true,
                  'order_status': 'cancelled',
                },
              ),
            );
        expect(ev, isNotNull);
        expect(ev!.isCancelled, isTrue);
      });
    },
  );
}
