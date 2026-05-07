import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/telemetry/telemetry.dart';
import 'package:tofu_pos/core/telemetry/telemetry_event.dart';
import 'package:tofu_pos/core/telemetry/telemetry_sink.dart';

class _RecordingSink implements TelemetrySink {
  final List<TelemetryEvent> enqueued = <TelemetryEvent>[];
  int flushCount = 0;

  @override
  void enqueue(TelemetryEvent event) => enqueued.add(event);

  @override
  Future<void> flush() async {
    flushCount++;
  }
}

void main() {
  setUp(Telemetry.instance.reset);

  test('未 configure 時は何も emit しない（Noop）', () {
    final _RecordingSink sink = _RecordingSink();
    // configure を呼ばずに event を投げる
    Telemetry.instance.event('order.created');
    expect(sink.enqueued, isEmpty);
  });

  test('configure 後に event を Sink に積む', () {
    final _RecordingSink sink = _RecordingSink();
    Telemetry.instance.configure(
      sink: sink,
      shopId: 'shop_a',
      deviceId: 'dev1',
      deviceRole: 'register',
      now: () => DateTime.utc(2026, 5, 8, 9),
    );
    Telemetry.instance.event(
      'order.created',
      attrs: <String, Object?>{'order_id': 42},
    );

    expect(sink.enqueued, hasLength(1));
    final e = sink.enqueued.single;
    expect(e.kind, 'order.created');
    expect(e.shopId, 'shop_a');
    expect(e.deviceId, 'dev1');
    expect(e.deviceRole, 'register');
    expect(e.level, TelemetryLevel.info);
    expect(e.attrs['order_id'], 42);
  });

  test('error は error と stack を attrs に展開する', () {
    final _RecordingSink sink = _RecordingSink();
    Telemetry.instance.configure(
      sink: sink,
      shopId: 'shop_a',
      deviceId: 'dev1',
      deviceRole: 'register',
    );
    final StateError err = StateError('boom');
    Telemetry.instance.error(
      'transport.send.failed',
      message: 'failed',
      error: err,
      stackTrace: StackTrace.fromString('stack-line'),
    );
    final e = sink.enqueued.single;
    expect(e.level, TelemetryLevel.error);
    expect(e.attrs['error'], contains('boom'));
    expect(e.attrs['stack'], contains('stack-line'));
  });

  test('scenarioId が event に伝播する', () {
    final _RecordingSink sink = _RecordingSink();
    Telemetry.instance.configure(
      sink: sink,
      shopId: 'shop_a',
      deviceId: 'dev1',
      deviceRole: 'register',
    );
    Telemetry.instance.scenarioId = 'scn-1';
    Telemetry.instance.event('order.created');
    Telemetry.instance.scenarioId = null;
    Telemetry.instance.event('order.created');

    expect(sink.enqueued[0].scenarioId, 'scn-1');
    expect(sink.enqueued[1].scenarioId, isNull);
  });

  test('flush は Sink に委譲', () async {
    final _RecordingSink sink = _RecordingSink();
    Telemetry.instance.configure(
      sink: sink,
      shopId: 'shop_a',
      deviceId: 'dev1',
      deviceRole: 'register',
    );
    await Telemetry.instance.flush();
    expect(sink.flushCount, 1);
  });
}
