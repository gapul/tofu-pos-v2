import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/data/datasources/lan/lan_protocol.dart';

void main() {
  group('LanProtocol.tryDecode (boundary input validation)', () {
    test('valid CallNumber payload returns LanDecodeOk', () {
      const String wire =
          '{"kind":"CallNumber","shopId":"s1","eventId":"e1",'
          '"occurredAt":"2026-05-11T10:00:00Z","orderId":42,'
          '"ticketNumber":7}';
      final LanDecodeResult r = LanProtocol.tryDecode(wire);
      expect(r, isA<LanDecodeOk>());
      final LanDecodeOk ok = r as LanDecodeOk;
      expect(ok.event, isA<CallNumberEvent>());
      expect((ok.event as CallNumberEvent).orderId, 42);
    });

    test('malformed JSON returns LanDecodeFailure (no throw)', () {
      final LanDecodeResult r = LanProtocol.tryDecode('{not json');
      expect(r, isA<LanDecodeFailure>());
      expect((r as LanDecodeFailure).reason, startsWith('invalid_json'));
    });

    test('JSON that is not an object returns failure', () {
      final LanDecodeResult r = LanProtocol.tryDecode('[1,2,3]');
      expect(r, isA<LanDecodeFailure>());
      expect((r as LanDecodeFailure).reason, 'not_a_json_object');
    });

    test('missing kind returns failure', () {
      final LanDecodeResult r = LanProtocol.tryDecode('{"shopId":"s1"}');
      expect(r, isA<LanDecodeFailure>());
      expect((r as LanDecodeFailure).reason, 'missing_kind');
    });

    test('unknown kind returns failure', () {
      const String wire = '{"kind":"Bogus","shopId":"s1"}';
      final LanDecodeResult r = LanProtocol.tryDecode(wire);
      expect(r, isA<LanDecodeFailure>());
      expect((r as LanDecodeFailure).reason, startsWith('unknown_kind'));
    });

    test('type mismatch on required field returns failure (drop)', () {
      // 数値フィールドに文字列が来たら drop（strict cast で TypeError）。
      const String wire =
          '{"kind":"CallNumber","shopId":"s1","eventId":"e1",'
          '"occurredAt":"2026-05-11T10:00:00Z",'
          '"orderId":"not-a-number","ticketNumber":1}';
      final LanDecodeResult r = LanProtocol.tryDecode(wire);
      expect(r, isA<LanDecodeFailure>());
      expect((r as LanDecodeFailure).reason, startsWith('type_error'));
    });
  });
}
