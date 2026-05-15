import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';

void main() {
  group('OrderStatus.canTransitionTo', () {
    test('unsent → sent は許可', () {
      expect(OrderStatus.unsent.canTransitionTo(OrderStatus.sent), isTrue);
    });

    test('sent → served は許可', () {
      expect(OrderStatus.sent.canTransitionTo(OrderStatus.served), isTrue);
    });

    test('unsent → cancelled は許可', () {
      expect(OrderStatus.unsent.canTransitionTo(OrderStatus.cancelled), isTrue);
    });

    test('sent → cancelled は許可', () {
      expect(OrderStatus.sent.canTransitionTo(OrderStatus.cancelled), isTrue);
    });

    test('unsent → served は不可（中間 sent をスキップ）', () {
      expect(OrderStatus.unsent.canTransitionTo(OrderStatus.served), isFalse);
    });

    test('sent → unsent は不可（後退）', () {
      expect(OrderStatus.sent.canTransitionTo(OrderStatus.unsent), isFalse);
    });

    test('終端 served はどこへも行けない', () {
      expect(OrderStatus.served.canTransitionTo(OrderStatus.unsent), isFalse);
      expect(OrderStatus.served.canTransitionTo(OrderStatus.sent), isFalse);
      expect(
        OrderStatus.served.canTransitionTo(OrderStatus.cancelled),
        isFalse,
      );
    });

    test('終端 cancelled はどこへも行けない', () {
      expect(
        OrderStatus.cancelled.canTransitionTo(OrderStatus.unsent),
        isFalse,
      );
      expect(OrderStatus.cancelled.canTransitionTo(OrderStatus.sent), isFalse);
      expect(
        OrderStatus.cancelled.canTransitionTo(OrderStatus.served),
        isFalse,
      );
    });

    test('同一状態への遷移は no-op として許可', () {
      for (final OrderStatus s in OrderStatus.values) {
        expect(s.canTransitionTo(s), isTrue, reason: '$s → $s should be no-op');
      }
    });
  });

  group('OrderStatus.transitionTo', () {
    test('正当な遷移は次状態を返す', () {
      expect(
        OrderStatus.unsent.transitionTo(OrderStatus.sent),
        OrderStatus.sent,
      );
    });

    test('不正な遷移は StateError を投げる', () {
      expect(
        () => OrderStatus.unsent.transitionTo(OrderStatus.served),
        throwsStateError,
      );
      expect(
        () => OrderStatus.served.transitionTo(OrderStatus.unsent),
        throwsStateError,
      );
    });
  });

  group('OrderStatus.isTerminal', () {
    test('served / cancelled のみ終端', () {
      expect(OrderStatus.unsent.isTerminal, isFalse);
      expect(OrderStatus.sent.isTerminal, isFalse);
      expect(OrderStatus.served.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
    });
  });
}
