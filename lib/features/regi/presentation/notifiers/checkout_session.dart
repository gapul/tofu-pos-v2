import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exceptions.dart';
import '../../../../domain/entities/customer_attributes.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/value_objects/checkout_draft.dart';
import '../../../../domain/value_objects/discount.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../providers/usecase_providers.dart';
import '../../domain/checkout_flow_usecase.dart';
import 'regi_providers.dart';

/// 会計セッション（仕様書 §6.1）。
///
/// 顧客属性入力 → 商品選択 → 会計 → 確定 までの間、レジ画面間で
/// 引き継がれるカート状態を保持する。確定後はリセットされる。
class CheckoutSession {
  const CheckoutSession({
    required this.items,
    required this.customerAttributes,
    required this.discount,
    required this.receivedCash,
    required this.cashDelta,
  });

  factory CheckoutSession.empty() => const CheckoutSession(
    items: <OrderItem>[],
    customerAttributes: CustomerAttributes.empty,
    discount: Discount.none,
    receivedCash: Money.zero,
    cashDelta: <int, int>{},
  );

  final List<OrderItem> items;
  final CustomerAttributes customerAttributes;
  final Discount discount;
  final Money receivedCash;
  final Map<int, int> cashDelta;

  bool get isEmpty => items.isEmpty;

  Money get totalPrice {
    Money sum = Money.zero;
    for (final OrderItem it in items) {
      sum = sum + it.subtotal;
    }
    return sum;
  }

  Money get finalPrice => discount.applyTo(totalPrice);
  Money get changeCash => receivedCash - finalPrice;

  int countOf(String productId) {
    for (final OrderItem it in items) {
      if (it.productId == productId) {
        return it.quantity;
      }
    }
    return 0;
  }

  CheckoutSession copyWith({
    List<OrderItem>? items,
    CustomerAttributes? customerAttributes,
    Discount? discount,
    Money? receivedCash,
    Map<int, int>? cashDelta,
  }) {
    return CheckoutSession(
      items: items ?? this.items,
      customerAttributes: customerAttributes ?? this.customerAttributes,
      discount: discount ?? this.discount,
      receivedCash: receivedCash ?? this.receivedCash,
      cashDelta: cashDelta ?? this.cashDelta,
    );
  }

  CheckoutDraft toDraft() => CheckoutDraft(
    items: items,
    discount: discount,
    receivedCash: receivedCash,
    cashDelta: cashDelta,
    customerAttributes: customerAttributes,
  );
}

/// 会計セッションの Notifier（Riverpod 3 系の `Notifier` ベース）。
///
/// 旧 `StateNotifier` から移行（M1）。API（メソッド名・引数）は互換のまま、
/// `state = state.copyWith(...)` のミューテーション方式も同じ。
class CheckoutSessionNotifier extends Notifier<CheckoutSession> {
  @override
  CheckoutSession build() => CheckoutSession.empty();

  /// 商品をカートに追加（既存なら quantity += delta）。
  /// [maxStock] が指定された場合、上限を超える追加は無視する（仕様書 §9.2）。
  void addProduct(Product product, {int delta = 1, int? maxStock}) {
    final List<OrderItem> next = List<OrderItem>.from(state.items);
    final int existing = next.indexWhere(
      (it) => it.productId == product.id,
    );
    if (existing >= 0) {
      final int newQty = next[existing].quantity + delta;
      if (newQty <= 0) {
        next.removeAt(existing);
      } else if (maxStock != null && newQty > maxStock) {
        next[existing] = next[existing].copyWith(quantity: maxStock);
      } else {
        next[existing] = next[existing].copyWith(quantity: newQty);
      }
    } else if (delta > 0) {
      final int qty = (maxStock != null && delta > maxStock) ? maxStock : delta;
      if (qty <= 0) {
        return;
      }
      next.add(
        OrderItem(
          productId: product.id,
          productName: product.name,
          priceAtTime: product.price,
          quantity: qty,
        ),
      );
    }
    state = state.copyWith(items: next);
  }

  /// 直前の追加操作を 1 件分だけ巻き戻す（Figma `03-Register-Products` の
   /// カートヘッダ「直前取消」リンクから呼ぶ）。
   ///
   /// 仕様（純粋な state 操作のみ。`addProduct` の逆向きでロールバック）:
   /// - カートが空なら no-op。
   /// - 末尾エントリの `quantity > 1` のときは `quantity -= 1`。
   /// - 末尾エントリの `quantity == 1` のときは行ごと削除。
   ///
   /// 「直前に追加された行」を末尾エントリと同一視するのは、`addProduct`
   /// が新規行を末尾 push、既存行を in-place 更新する仕様によるもの。
   /// 厳密な操作履歴は持たないため、`setQuantity` 等を挟んだ場合は
   /// 末尾行への 1 件分ロールバックとして振る舞う。
  void undoLast() {
    if (state.items.isEmpty) {
      return;
    }
    final List<OrderItem> next = List<OrderItem>.from(state.items);
    final OrderItem last = next.last;
    if (last.quantity > 1) {
      next[next.length - 1] = last.copyWith(quantity: last.quantity - 1);
    } else {
      next.removeLast();
    }
    state = state.copyWith(items: next);
  }

  void removeProduct(String productId) {
    state = state.copyWith(
      items: state.items
          .where((it) => it.productId != productId)
          .toList(),
    );
  }

  void clearItems() {
    state = state.copyWith(items: const <OrderItem>[]);
  }

  void setQuantity(String productId, int quantity, {int? maxStock}) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }
    final int clamped = (maxStock != null && quantity > maxStock)
        ? maxStock
        : quantity;
    final List<OrderItem> next = state.items
        .map(
          (it) =>
              it.productId == productId ? it.copyWith(quantity: clamped) : it,
        )
        .toList();
    state = state.copyWith(items: next);
  }

  void setCustomerAttributes(CustomerAttributes attrs) {
    state = state.copyWith(customerAttributes: attrs);
  }

  void setDiscount(Discount discount) {
    state = state.copyWith(discount: discount);
  }

  void setReceivedCash(Money amount) {
    state = state.copyWith(receivedCash: amount);
  }

  void setCashDelta(Map<int, int> cashDelta) {
    state = state.copyWith(cashDelta: cashDelta);
  }

  void reset() {
    state = CheckoutSession.empty();
  }
}

/// 会計セッション Provider（旧 `StateNotifierProvider` → `NotifierProvider`、M1）。
///
/// レジ全体フローで共有されるため autoDispose にしない（画面遷移で状態破棄禁止）。
final NotifierProvider<CheckoutSessionNotifier, CheckoutSession>
checkoutSessionProvider =
    NotifierProvider<CheckoutSessionNotifier, CheckoutSession>(
      CheckoutSessionNotifier.new,
    );

/// 会計確定アクションの結果状態（M3）。
///
/// 画面側 (`checkout_screen`) はこの `AsyncValue` を listen して
/// SnackBar / 遷移を行う。例外は Notifier 内で AsyncValue.error に変換し、
/// 業務例外を画面コードから追い出すのが目的。
class CheckoutConfirmController extends AsyncNotifier<Order?> {
  @override
  Future<Order?> build() async => null;

  /// 会計確定アクション。
  ///
  /// 戻り値:
  ///  - `Order`: ローカル保存 + 配信成功。完了画面へ進む。
  ///  - `null`: 入力不備や前提未充足（預り金不足・店舗未設定）。SnackBar のみ。
  ///
  /// 失敗時は `AsyncValue.error` を state にセットして throw する。
  /// 画面は `listen` で error を拾い、SnackBar を表示する。
  ///
  /// [TransportDeliveryException] は「ローカル保存は成功・配信のみ失敗」を
  /// 表す特殊なケース。state.error にセットしつつも、すでに `saved` は確定
  /// しているのでメンバ `_lastTransportError` 経由で画面に通知する。
  Future<Order?> confirm() async {
    final CheckoutSession session = ref.read(checkoutSessionProvider);
    final FeatureFlags flags =
        ref.read(featureFlagsProvider).value ?? FeatureFlags.allOff;

    if (session.changeCash.isNegative) {
      state = AsyncValue<Order?>.error(
        const _CheckoutValidationError('預り金が不足しています'),
        StackTrace.current,
      );
      return null;
    }
    final CheckoutFlowUseCase? flow = await ref.read(
      checkoutFlowUseCaseProvider.future,
    );
    if (flow == null) {
      state = AsyncValue<Order?>.error(
        const _CheckoutValidationError('店舗IDが未設定です。設定画面から構成してください'),
        StackTrace.current,
      );
      return null;
    }

    state = const AsyncValue<Order?>.loading();
    try {
      final Order saved = await flow.execute(
        draft: session.toDraft(),
        flags: flags,
      );
      ref.invalidate(ticketPoolProvider);
      ref.read(checkoutSessionProvider.notifier).reset();
      state = AsyncValue<Order?>.data(saved);
      return saved;
    } on TransportDeliveryException catch (e, st) {
      // ローカル保存は完了している。配信エラーは別扱い。
      ref.invalidate(ticketPoolProvider);
      ref.read(checkoutSessionProvider.notifier).reset();
      state = AsyncValue<Order?>.error(e, st);
      rethrow;
    } on InsufficientStockException catch (e, st) {
      state = AsyncValue<Order?>.error(e, st);
      rethrow;
    } on TicketPoolExhaustedException catch (e, st) {
      state = AsyncValue<Order?>.error(e, st);
      rethrow;
    }
  }
}

/// 会計確定コントローラ Provider（M3）。
///
/// 画面スコープのアクション状態のため autoDispose（M4）。
/// CheckoutScreen を離れたらアクション状態を破棄して、次回会計時に
/// 古い error が残らないようにする。
final AsyncNotifierProvider<CheckoutConfirmController, Order?>
checkoutConfirmControllerProvider =
    AsyncNotifierProvider.autoDispose<CheckoutConfirmController, Order?>(
      CheckoutConfirmController.new,
    );

/// 預り金不足など、ユーザー入力起因の軽量バリデーションエラー。
///
/// 画面側で `is _CheckoutValidationError` を判定して SnackBar を出す。
class _CheckoutValidationError implements Exception {
  const _CheckoutValidationError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 会計バリデーションエラーかどうか（画面側からの判定用）。
bool isCheckoutValidationError(Object error) =>
    error is _CheckoutValidationError;

/// バリデーションエラーのメッセージ抽出。
String checkoutValidationMessage(Object error) =>
    error is _CheckoutValidationError ? error.message : '$error';

/// `TransportDeliveryException` かどうかの判定（画面側からの判定用）。
bool isTransportDeliveryError(Object error) =>
    error is TransportDeliveryException;
