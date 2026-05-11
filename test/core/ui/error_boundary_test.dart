import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/error/app_exceptions.dart';
import 'package:tofu_pos/core/telemetry/telemetry.dart';
import 'package:tofu_pos/core/telemetry/telemetry_event.dart';
import 'package:tofu_pos/core/telemetry/telemetry_sink.dart';
import 'package:tofu_pos/core/ui/error_boundary.dart';

class _RecordingSink implements TelemetrySink {
  final List<TelemetryEvent> events = <TelemetryEvent>[];

  @override
  void enqueue(TelemetryEvent event) => events.add(event);

  @override
  Future<void> flush() async {}
}

class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget({required this.exception});
  final Exception exception;

  @override
  Widget build(BuildContext context) {
    throw exception;
  }
}

void main() {
  late ErrorWidgetBuilder originalErrorBuilder;

  setUp(() {
    Telemetry.instance.reset();
    ErrorBoundary.debugReset();
    originalErrorBuilder = ErrorWidget.builder;
  });

  tearDown(() {
    // flutter_test は ErrorWidget.builder の差し替えを検知するため、
    // 各テストの後に元へ戻す。
    ErrorWidget.builder = originalErrorBuilder;
    ErrorBoundary.debugReset();
  });

  testWidgets('build エラーをフォールバック UI に置き換える', (tester) async {
    final _RecordingSink sink = _RecordingSink();
    Telemetry.instance.configure(
      sink: sink,
      shopId: 'shop_a',
      deviceId: 'dev1',
      deviceRole: 'register',
    );

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            label: 'route:/test',
            child: _ThrowingWidget(
              exception: TicketPoolExhaustedException(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Flutter は build 例外を framework に上げるので回収。
      final Object? captured = tester.takeException();
      expect(captured, isA<TicketPoolExhaustedException>());

      expect(find.text('エラーが発生しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
      // AppException.kind が表示される。
      expect(find.text('TicketPoolExhaustedException'), findsOneWidget);

      // Telemetry にエラーが流れる。
      expect(sink.events, isNotEmpty);
      final TelemetryEvent ev = sink.events.first;
      expect(ev.kind, 'ui.error_boundary');
      expect(ev.level, TelemetryLevel.error);
      expect(ev.attrs['kind'], 'TicketPoolExhaustedException');
    } finally {
      // テストフレームワークの差し替え検知に通すため、テスト本体の最後で
      // 必ず元へ戻す（tearDown では遅すぎる）。
      ErrorWidget.builder = originalErrorBuilder;
    }
  });

  testWidgets('正常な child はそのまま表示する', (tester) async {
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            label: 'route:/ok',
            child: Scaffold(body: Text('hello')),
          ),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('エラーが発生しました'), findsNothing);
    } finally {
      ErrorWidget.builder = originalErrorBuilder;
    }
  });
}
