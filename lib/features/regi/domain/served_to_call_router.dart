import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../domain/repositories/ticket_number_pool_repository.dart';
import '../../../domain/value_objects/feature_flags.dart';

/// レジ端末で動くイベントルーター。
///
/// **仕様書 §6.3 キッチン連携オン時の自動転送**:
/// キッチン → レジに OrderServedEvent が届いた瞬間、レジは
/// 呼び出し連携がオンなら CallNumberEvent を呼び出し端末に転送する。
///
/// レジ端末起動時に [start] を呼び、終了時に [stop] を呼ぶ想定。
class ServedToCallRouter {
  ServedToCallRouter({
    required Transport transport,
    required SettingsRepository settingsRepository,
    required String shopId,
    TicketNumberPoolRepository? ticketPoolRepository,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  }) : _transport = transport,
       _settings = settingsRepository,
       _shopId = shopId,
       _ticketPool = ticketPoolRepository,
       _uuid = uuid,
       _now = now;

  final Transport _transport;
  final SettingsRepository _settings;
  final String _shopId;
  final TicketNumberPoolRepository? _ticketPool;
  final Uuid _uuid;
  final DateTime Function() _now;

  StreamSubscription<TransportEvent>? _sub;
  bool get isRunning => _sub != null;

  void start() {
    _sub ??= _transport.events().listen(_onEvent);
    AppLogger.event('regi', 'served_to_call_router_started');
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onEvent(TransportEvent event) async {
    if (event is OrderPickedUpEvent) {
      if (event.shopId != _shopId) return;
      // 受取完了 → ticket pool に return（3 分クールタイムは pool 内部で吸収）。
      final TicketNumberPoolRepository? pool = _ticketPool;
      if (pool == null) return;
      try {
        await pool.release(event.ticketNumber);
        AppLogger.event(
          'regi',
          'ticket_returned_on_picked_up',
          fields: <String, Object?>{'ticket': event.ticketNumber.value},
          level: AppLogLevel.debug,
        );
      } catch (e, st) {
        AppLogger.w(
          'ServedToCallRouter: release on picked_up failed',
          error: e,
          stackTrace: st,
        );
      }
      return;
    }
    if (event is! OrderServedEvent) {
      return;
    }
    if (event.shopId != _shopId) {
      return; // 他店舗のイベントは無視
    }
    final FeatureFlags flags = await _settings.getFeatureFlags();
    // キッチン連携オン + 呼び出し連携オンの組み合わせのみ自動転送する。
    // キッチン連携オフ時は手動「呼び出す」ボタン経由（仕様書 §6.3 後段）
    if (!flags.kitchenLink || !flags.callingLink) {
      // P3 調査用: 「キッチンで提供完了を押しても呼び出し端末に番号が出ない」
      // 報告の主因の一つ。レジ側のフィーチャーフラグが OFF のとき、
      // OrderServedEvent は受信できているのに自動転送されない、という
      // ことを telemetry で見えるようにしておく。
      AppLogger.event(
        'regi',
        'auto_route_skipped_flags_off',
        fields: <String, Object?>{
          'ticket': event.ticketNumber.value,
          'kitchen_link': flags.kitchenLink,
          'calling_link': flags.callingLink,
        },
        level: AppLogLevel.warn,
      );
      return;
    }

    final CallNumberEvent ev = CallNumberEvent(
      shopId: _shopId,
      eventId: _uuid.v4(),
      occurredAt: _now(),
      orderId: event.orderId,
      ticketNumber: event.ticketNumber,
    );

    try {
      await _transport.send(ev);
      AppLogger.event(
        'regi',
        'auto_route_served_to_call',
        fields: <String, Object?>{'ticket': event.ticketNumber.value},
        level: AppLogLevel.debug,
      );
    } catch (e, st) {
      AppLogger.w(
        AppLogger.formatEvent(
          'regi',
          'auto_route_failed',
          <String, Object?>{'ticket': event.ticketNumber.value},
        ),
        error: e,
        stackTrace: st,
      );
    }
  }
}
