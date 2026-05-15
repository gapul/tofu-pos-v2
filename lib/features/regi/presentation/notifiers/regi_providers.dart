import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/value_objects/ticket_number.dart';
import '../../../../domain/value_objects/ticket_number_pool.dart';
import '../../../../providers/repository_providers.dart';

/// 商品マスタ（削除済を除く）を Stream で公開。
///
/// 画面遷移で listener が消えたら購読も止める（autoDispose, M4）。
/// 商品マスタは Stream で常時更新されるので、毎回開き直しでも問題ない。
final StreamProvider<List<Product>> activeProductsProvider =
    StreamProvider.autoDispose<List<Product>>(
      (ref) =>
          ref.watch(productRepositoryProvider).watchAll(),
    );

/// 注文履歴（最新順）を Stream で公開。
///
/// 注文履歴画面でのみ使われるため autoDispose（M4）。
/// 画面を閉じたら DB 購読を解放する。
final StreamProvider<List<Order>> orderHistoryProvider =
    StreamProvider.autoDispose<List<Order>>(
      (ref) =>
          ref.watch(orderRepositoryProvider).watchAll(),
    );

/// 整理券プールの現在状態。
///
/// 永続化層が Stream を持たないため、UI 側では明示リフレッシュで再取得する。
/// 多数の画面（レジホーム / 会計 / 顧客属性 / 商品選択）から監視されるため、
/// 画面遷移ごとに再フェッチを避ける目的で **autoDispose しない**（永続化）。
/// `ref.invalidate(ticketPoolProvider)` で確定後に明示的にリフレッシュする。
final FutureProvider<TicketNumberPool> ticketPoolProvider =
    FutureProvider<TicketNumberPool>(
      (ref) =>
          ref.watch(ticketNumberPoolRepositoryProvider).load(),
    );

/// 「次回番号」（仕様書 §9.1）。プールから払い出す予定の番号。
///
/// `ticketPoolProvider` に追随。プール側を永続化するためこちらも非 autoDispose。
final Provider<AsyncValue<TicketNumber?>> upcomingTicketProvider =
    Provider<AsyncValue<TicketNumber?>>(
      (ref) => ref
          .watch(ticketPoolProvider)
          .whenData((p) => p.peekNext()),
    );
