import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport.dart';
import '../../../core/transport/transport_event.dart';
import 'calling_ingest_usecase.dart';

/// 呼び出し端末で動くイベントルーター（仕様書 §6.3 / §6.6.6）。
///
/// Transport.events() を購読し、event 種別に応じて適切な UseCase を呼ぶ:
///  - CallNumberEvent      → CallingIngestUseCase.ingestCallNumber
///  - OrderCancelledEvent  → CallingIngestUseCase.ingestCancelled
///
/// shop_id が一致しないイベントは無視する。
class CallingIngestRouter {
  CallingIngestRouter({
    required Transport transport,
    required CallingIngestUseCase ingest,
    required String shopId,
  }) : _transport = transport,
       _ingest = ingest,
       _shopId = shopId;

  final Transport _transport;
  final CallingIngestUseCase _ingest;
  final String _shopId;

  StreamSubscription<TransportEvent>? _sub;
  bool get isRunning => _sub != null;

  void start() {
    _sub ??= _transport.events().listen(_onEvent);
    AppLogger.event(
      'calling',
      'router_started',
      fields: <String, Object?>{'shop': _shopId},
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onEvent(TransportEvent event) async {
    if (event.shopId != _shopId) {
      return;
    }
    try {
      if (event is CallNumberEvent) {
        await _ingest.ingestCallNumber(event);
      } else if (event is OrderCancelledEvent) {
        await _ingest.ingestCancelled(event);
      }
    } catch (e, st) {
      AppLogger.e(
        'CallingIngestRouter: event handler failed for ${event.runtimeType}',
        error: e,
        stackTrace: st,
      );
    }
  }
}
