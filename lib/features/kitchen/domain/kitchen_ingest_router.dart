import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport.dart';
import '../../../core/transport/transport_event.dart';
import 'kitchen_ingest_usecase.dart';
import 'product_master_ingest_usecase.dart';

/// キッチン端末で動くイベントルーター（仕様書 §6.2 / §6.5 / §6.6.5）。
///
/// Transport.events() を購読し、event 種別に応じて適切な UseCase を呼ぶ:
///  - OrderSubmittedEvent      → KitchenIngestUseCase.ingestSubmitted
///  - OrderCancelledEvent      → KitchenIngestUseCase.ingestCancelled
///  - ProductMasterUpdateEvent → ProductMasterIngestUseCase.ingest
///
/// shop_id が一致しないイベントは無視する。
class KitchenIngestRouter {
  KitchenIngestRouter({
    required Transport transport,
    required KitchenIngestUseCase ingest,
    required ProductMasterIngestUseCase productIngest,
    required String shopId,
  }) : _transport = transport,
       _ingest = ingest,
       _productIngest = productIngest,
       _shopId = shopId;

  final Transport _transport;
  final KitchenIngestUseCase _ingest;
  final ProductMasterIngestUseCase _productIngest;
  final String _shopId;

  StreamSubscription<TransportEvent>? _sub;
  bool get isRunning => _sub != null;

  void start() {
    _sub ??= _transport.events().listen(_onEvent);
    AppLogger.event(
      'kitchen',
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
      return; // 他店舗のイベントは無視
    }
    try {
      if (event is OrderSubmittedEvent) {
        await _ingest.ingestSubmitted(event);
      } else if (event is OrderCancelledEvent) {
        await _ingest.ingestCancelled(event);
      } else if (event is ProductMasterUpdateEvent) {
        await _productIngest.ingest(event);
      }
      // OrderServedEvent / CallNumberEvent はキッチン側で扱わない
    } catch (e, st) {
      AppLogger.e(
        'KitchenIngestRouter: event handler failed for ${event.runtimeType}',
        error: e,
        stackTrace: st,
      );
    }
  }
}
