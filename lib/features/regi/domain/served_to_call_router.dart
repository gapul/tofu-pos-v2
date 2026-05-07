import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/repositories/settings_repository.dart';
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
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  }) : _transport = transport,
       _settings = settingsRepository,
       _shopId = shopId,
       _uuid = uuid,
       _now = now;

  final Transport _transport;
  final SettingsRepository _settings;
  final String _shopId;
  final Uuid _uuid;
  final DateTime Function() _now;

  StreamSubscription<TransportEvent>? _sub;
  bool get isRunning => _sub != null;

  void start() {
    _sub ??= _transport.events().listen(_onEvent);
    AppLogger.i('ServedToCallRouter started');
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onEvent(TransportEvent event) async {
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
      AppLogger.d('Auto-routed served → call: ticket=${event.ticketNumber}');
    } catch (e, st) {
      AppLogger.w(
        'ServedToCallRouter: forward failed for ticket=${event.ticketNumber}',
        error: e,
        stackTrace: st,
      );
    }
  }
}
