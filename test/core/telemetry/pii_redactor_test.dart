import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/telemetry/pii_redactor.dart';
import 'package:tofu_pos/core/telemetry/telemetry_event.dart';
import 'package:tofu_pos/core/telemetry/telemetry_sink.dart';

class _RecordingSink implements TelemetrySink {
  final List<TelemetryEvent> events = <TelemetryEvent>[];
  int flushCount = 0;

  @override
  void enqueue(TelemetryEvent event) => events.add(event);

  @override
  Future<void> flush() async {
    flushCount++;
  }
}

void main() {
  group('PiiRedactor.redact', () {
    const PiiRedactor redactor = PiiRedactor();

    test('email は値を捨てて *_hash に置換する', () {
      final out = redactor.redact(<String, Object?>{
        'email': 'alice@example.com',
        'order_id': 42,
      });
      expect(out.containsKey('email'), isFalse);
      expect(out['email_hash'], isA<String>());
      expect((out['email_hash']! as String).length, 8);
      expect(out['order_id'], 42);
    });

    test('phone / tel / name / username も hash 化される', () {
      final out = redactor.redact(<String, Object?>{
        'phone': '090-1234-5678',
        'tel': '03-0000-0000',
        'name': 'Yuki Tofu',
        'username': 'yuki',
      });
      expect(out['phone_hash'], isA<String>());
      expect(out['tel_hash'], isA<String>());
      expect(out['name_hash'], isA<String>());
      expect(out['username_hash'], isA<String>());
      expect(out.containsKey('phone'), isFalse);
      expect(out.containsKey('tel'), isFalse);
      expect(out.containsKey('name'), isFalse);
      expect(out.containsKey('username'), isFalse);
    });

    test('同じ値は同じ hash になる（決定的）', () {
      final a = redactor.redact(<String, Object?>{'email': 'a@b.com'});
      final b = redactor.redact(<String, Object?>{'email': 'a@b.com'});
      expect(a['email_hash'], b['email_hash']);
    });

    test('age は 10 歳刻みのバケットに丸める', () {
      expect(redactor.redact(<String, Object?>{'age': 7})['age_bucket'], '0s');
      expect(redactor.redact(<String, Object?>{'age': 13})['age_bucket'], '10s');
      expect(redactor.redact(<String, Object?>{'age': 25})['age_bucket'], '20s');
      expect(redactor.redact(<String, Object?>{'age': 39})['age_bucket'], '30s');
      expect(redactor.redact(<String, Object?>{'age': 60})['age_bucket'], '60s+');
      expect(redactor.redact(<String, Object?>{'age': 99})['age_bucket'], '60s+');
    });

    test('age が文字列でもパースしてバケット化する', () {
      expect(redactor.redact(<String, Object?>{'age': '24'})['age_bucket'], '20s');
      expect(redactor.redact(<String, Object?>{'age': 'unknown'})['age_bucket'], 'unknown');
      expect(redactor.redact(<String, Object?>{'age': -1})['age_bucket'], 'unknown');
    });

    test('PII でないキーは素通しする', () {
      final out = redactor.redact(<String, Object?>{
        'order_id': 'o-1',
        'ticket': 7,
        'total_yen': 1200,
        'customer_age': 'twenties',
        'customer_gender': 'female',
      });
      expect(out['order_id'], 'o-1');
      expect(out['ticket'], 7);
      expect(out['total_yen'], 1200);
      expect(out['customer_age'], 'twenties');
      expect(out['customer_gender'], 'female');
    });

    test('null 値の PII フィールドは捨てるだけ', () {
      final out = redactor.redact(<String, Object?>{
        'email': null,
        'order_id': 1,
      });
      expect(out.containsKey('email'), isFalse);
      expect(out.containsKey('email_hash'), isFalse);
      expect(out['order_id'], 1);
    });

    test('空 attrs はそのまま返す', () {
      final out = redactor.redact(const <String, Object?>{});
      expect(out, isEmpty);
    });
  });

  group('PiiRedactor.redactEvent', () {
    test('attrs だけが redact され、他のメタは保持される', () {
      const PiiRedactor redactor = PiiRedactor();
      final TelemetryEvent e = TelemetryEvent(
        shopId: 'shop_a',
        deviceId: 'd1',
        deviceRole: 'register',
        kind: 'order.created',
        level: TelemetryLevel.info,
        occurredAt: DateTime.utc(2026, 5, 8, 9),
        message: 'msg',
        scenarioId: 'scn-1',
        appVersion: '1.0.0',
        attrs: <String, Object?>{'email': 'x@y.z', 'order_id': 1},
      );
      final TelemetryEvent r = redactor.redactEvent(e);
      expect(r.shopId, 'shop_a');
      expect(r.deviceId, 'd1');
      expect(r.deviceRole, 'register');
      expect(r.kind, 'order.created');
      expect(r.level, TelemetryLevel.info);
      expect(r.message, 'msg');
      expect(r.scenarioId, 'scn-1');
      expect(r.appVersion, '1.0.0');
      expect(r.attrs.containsKey('email'), isFalse);
      expect(r.attrs['email_hash'], isA<String>());
      expect(r.attrs['order_id'], 1);
    });
  });

  group('RedactingTelemetrySink', () {
    test('inner Sink に渡される前に attrs が redact される', () {
      final _RecordingSink inner = _RecordingSink();
      final RedactingTelemetrySink sink = RedactingTelemetrySink(inner);
      sink.enqueue(
        TelemetryEvent(
          shopId: 's',
          deviceId: 'd',
          deviceRole: 'r',
          kind: 'k',
          level: TelemetryLevel.info,
          occurredAt: DateTime.utc(2026),
          attrs: const <String, Object?>{'email': 'a@b.c'},
        ),
      );
      expect(inner.events, hasLength(1));
      expect(inner.events.single.attrs.containsKey('email'), isFalse);
      expect(inner.events.single.attrs['email_hash'], isA<String>());
    });

    test('flush は inner にそのまま委譲', () async {
      final _RecordingSink inner = _RecordingSink();
      final RedactingTelemetrySink sink = RedactingTelemetrySink(inner);
      await sink.flush();
      expect(inner.flushCount, 1);
    });
  });
}
