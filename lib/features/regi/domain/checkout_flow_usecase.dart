import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/error/app_exceptions.dart';
import '../../../core/transport/transport.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/entities/order_item.dart';
import '../../../domain/enums/order_status.dart';
import '../../../domain/repositories/order_repository.dart';
import '../../../domain/usecases/checkout_usecase.dart';
import '../../../domain/value_objects/checkout_draft.dart';
import '../../../domain/value_objects/feature_flags.dart';

/// 会計フロー全体（仕様書 §6.1）。
///
/// 1. CheckoutUseCase でローカル保存（不可分）
/// 2. キッチン連携オン時: Transport で注文を送信、注文ステータスを sent に更新
/// 3. 送信失敗時: ローカルは保存済みのまま、UI にエラー伝播（注文ステータスは unsent のまま）
///
/// データ厳格性: 通信失敗が起きても、ローカルに保存された会計データは失われない（§1.2）。
class CheckoutFlowUseCase {
  CheckoutFlowUseCase({
    required CheckoutUseCase checkoutUseCase,
    required Transport transport,
    required OrderRepository orderRepository,
    required String shopId,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  })  : _checkout = checkoutUseCase,
        _transport = transport,
        _orderRepo = orderRepository,
        _shopId = shopId,
        _uuid = uuid,
        _now = now;

  final CheckoutUseCase _checkout;
  final Transport _transport;
  final OrderRepository _orderRepo;
  final String _shopId;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// 会計確定 → キッチン送信。送信失敗時は [TransportDeliveryException]。
  /// **その場合でも注文はローカルに保存済み**（unsent ステータス）。
  Future<Order> execute({
    required CheckoutDraft draft,
    required FeatureFlags flags,
  }) async {
    // 1. ローカル保存（失敗したら例外がそのまま伝播）
    final Order saved = await _checkout.execute(draft: draft, flags: flags);

    // 2. キッチン連携オフ時は送信せず終了
    if (!flags.kitchenLink) {
      return saved;
    }

    // 3. 送信
    try {
      await _transport.send(_buildEvent(saved));
    } catch (e) {
      throw TransportDeliveryException('注文をキッチンに送信できませんでした: $e');
    }

    // 4. 送信成功 → ステータス更新
    await _orderRepo.updateStatus(saved.id, OrderStatus.sent);
    return saved.copyWith(orderStatus: OrderStatus.sent);
  }

  OrderSubmittedEvent _buildEvent(Order order) {
    final List<Map<String, Object>> items = <Map<String, Object>>[
      for (final OrderItem item in order.items)
        <String, Object>{
          'name': item.productName,
          'quantity': item.quantity,
        },
    ];
    return OrderSubmittedEvent(
      shopId: _shopId,
      eventId: _uuid.v4(),
      occurredAt: _now(),
      orderId: order.id,
      ticketNumber: order.ticketNumber,
      itemsJson: jsonEncode(items),
    );
  }
}
