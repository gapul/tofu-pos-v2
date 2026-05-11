import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/value_objects/ticket_number.dart';
import '../../../../domain/value_objects/ticket_number_pool.dart';
import '../../../../providers/repository_providers.dart';

/// 商品マスタ（削除済を除く）を Stream で公開。
final StreamProvider<List<Product>> activeProductsProvider =
    StreamProvider<List<Product>>(
      (ref) =>
          ref.watch(productRepositoryProvider).watchAll(),
    );

/// 注文履歴（最新順）を Stream で公開。
final StreamProvider<List<Order>> orderHistoryProvider =
    StreamProvider<List<Order>>(
      (ref) =>
          ref.watch(orderRepositoryProvider).watchAll(),
    );

/// 整理券プールの現在状態。
///
/// 永続化層が Stream を持たないため、UI 側では明示リフレッシュで再取得する。
final FutureProvider<TicketNumberPool> ticketPoolProvider =
    FutureProvider<TicketNumberPool>(
      (ref) =>
          ref.watch(ticketNumberPoolRepositoryProvider).load(),
    );

/// 「次回番号」（仕様書 §9.1）。プールから払い出す予定の番号。
final Provider<AsyncValue<TicketNumber?>> upcomingTicketProvider =
    Provider<AsyncValue<TicketNumber?>>(
      (ref) => ref
          .watch(ticketPoolProvider)
          .whenData((p) => p.peekNext()),
    );
