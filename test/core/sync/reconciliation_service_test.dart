import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/sync/reconciliation_service.dart';
import 'package:tofu_pos/domain/entities/calling_order.dart';
import 'package:tofu_pos/domain/entities/kitchen_order.dart';
import 'package:tofu_pos/domain/enums/calling_status.dart';
import 'package:tofu_pos/domain/enums/kitchen_status.dart';
import 'package:tofu_pos/domain/repositories/calling_order_repository.dart';
import 'package:tofu_pos/domain/repositories/kitchen_order_repository.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

/// テスト用 in-memory KitchenOrderRepository。
class _MemKitchenRepo implements KitchenOrderRepository {
  final Map<int, KitchenOrder> _store = <int, KitchenOrder>{};

  @override
  Future<KitchenOrder?> findByOrderId(int orderId) async => _store[orderId];

  @override
  Future<List<KitchenOrder>> findAll() async => _store.values.toList();

  @override
  Stream<List<KitchenOrder>> watchAll() async* {
    yield _store.values.toList();
  }

  @override
  Future<void> upsert(KitchenOrder order) async {
    _store[order.orderId] = order;
  }

  @override
  Future<void> updateStatus(int orderId, KitchenStatus status) async {
    final KitchenOrder? cur = _store[orderId];
    if (cur != null) {
      _store[orderId] = cur.copyWith(status: status);
    }
  }
}

class _MemCallingRepo implements CallingOrderRepository {
  final Map<int, CallingOrder> _store = <int, CallingOrder>{};

  @override
  Future<CallingOrder?> findByOrderId(int orderId) async => _store[orderId];

  @override
  Future<List<CallingOrder>> findAll() async => _store.values.toList();

  @override
  Stream<List<CallingOrder>> watchAll() async* {
    yield _store.values.toList();
  }

  @override
  Future<void> upsert(CallingOrder order) async {
    _store[order.orderId] = order;
  }

  @override
  Future<void> updateStatus(int orderId, CallingStatus status) async {
    final CallingOrder? cur = _store[orderId];
    if (cur != null) {
      _store[orderId] = cur.copyWith(status: status);
    }
  }
}

class _ScriptedProbe implements ServerStateProbe {
  _ScriptedProbe(this._snapshots);
  final List<ServerOrderSnapshot?> _snapshots;
  int callCount = 0;

  @override
  Future<ServerOrderSnapshot?> fetch() async {
    final ServerOrderSnapshot? r =
        callCount < _snapshots.length ? _snapshots[callCount] : null;
    callCount += 1;
    return r;
  }
}

KitchenOrder _kPending(int id) => KitchenOrder(
      orderId: id,
      ticketNumber: TicketNumber(id),
      itemsJson: '[]',
      status: KitchenStatus.pending,
      receivedAt: DateTime(2026, 5, 16),
    );

void main() {
  test('inSync: server と local が一致なら何もしない', () async {
    final _MemKitchenRepo repo = _MemKitchenRepo()
      ..upsert(_kPending(1))
      ..upsert(_kPending(2));
    final _ScriptedProbe probe = _ScriptedProbe(<ServerOrderSnapshot?>[
      ServerOrderSnapshot(
        kitchenPending: <int, TicketNumber>{
          1: const TicketNumber(1),
          2: const TicketNumber(2),
        },
        callingAwaiting: const <int, TicketNumber>{},
        callingCalled: const <int, TicketNumber>{},
      ),
    ]);
    final ReconciliationService svc = ReconciliationService(
      probe: probe,
      kitchenRepository: repo,
      retryDelay: const Duration(milliseconds: 1),
    );
    final ReconciliationOutcome r = await svc.runOnce();
    expect(r.kind, ReconciliationOutcomeKind.inSync);
    expect(probe.callCount, 1);
  });

  test('差分あり → retry で解消 (race を吸収) なら applied しない', () async {
    final _MemKitchenRepo repo = _MemKitchenRepo();
    // 1 回目: server に order=1 pending, local 空 → 差分あり。
    // しかしテスト中に「直後にイベントが届いた」想定で repo に 1 を追加して
    // 2 回目: 差分なしになる。
    final ServerOrderSnapshot snap = ServerOrderSnapshot(
      kitchenPending: <int, TicketNumber>{1: const TicketNumber(1)},
      callingAwaiting: const <int, TicketNumber>{},
      callingCalled: const <int, TicketNumber>{},
    );
    final _ScriptedProbe probe = _ScriptedProbe(<ServerOrderSnapshot?>[
      snap,
      snap,
    ]);
    final ReconciliationService svc = ReconciliationService(
      probe: probe,
      kitchenRepository: repo,
      retryDelay: const Duration(milliseconds: 10),
    );
    // 1 回目 detect の直後 (retry 待ちの 10ms 中) に local 側に届く想定。
    final Future<ReconciliationOutcome> fut = svc.runOnce();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.upsert(_kPending(1));
    final ReconciliationOutcome r = await fut;
    expect(r.kind, ReconciliationOutcomeKind.resolvedOnRetry);
    expect(probe.callCount, 2);
    // local は変更されない（自分で入れた 1 件のみ）。
    expect((await repo.findAll()).length, 1);
  });

  test('差分あり → retry でも残れば修正 (不足追加 + 余分 cancel)', () async {
    final _MemKitchenRepo kitchen = _MemKitchenRepo()
      // server には居ない余分な pending
      ..upsert(_kPending(99));
    final _MemCallingRepo calling = _MemCallingRepo()
      // 余分な called
      ..upsert(
        CallingOrder(
          orderId: 50,
          ticketNumber: const TicketNumber(50),
          status: CallingStatus.called,
          receivedAt: DateTime(2026, 5, 16),
        ),
      );

    final ServerOrderSnapshot snap = ServerOrderSnapshot(
      kitchenPending: <int, TicketNumber>{
        // server に必要な pending = order 7
        7: const TicketNumber(7),
      },
      callingAwaiting: <int, TicketNumber>{
        8: const TicketNumber(8), // local には無い
      },
      callingCalled: const <int, TicketNumber>{},
    );
    final _ScriptedProbe probe =
        _ScriptedProbe(<ServerOrderSnapshot?>[snap, snap]);
    final ReconciliationService svc = ReconciliationService(
      probe: probe,
      kitchenRepository: kitchen,
      callingRepository: calling,
      retryDelay: const Duration(milliseconds: 1),
      now: () => DateTime(2026, 5, 16, 12),
    );
    final ReconciliationOutcome r = await svc.runOnce();
    expect(r.kind, ReconciliationOutcomeKind.applied);
    expect(r.appliedDiff!.kitchenAdded, 1);
    expect(r.appliedDiff!.kitchenCancelled, 1);
    expect(r.appliedDiff!.callingAdded, 1);
    expect(r.appliedDiff!.callingCancelled, 1);

    // 検証: 7 が pending で追加され、99 は cancelled に。
    expect((await kitchen.findByOrderId(7))!.status, KitchenStatus.pending);
    expect((await kitchen.findByOrderId(99))!.status, KitchenStatus.cancelled);
    expect(
      (await calling.findByOrderId(8))!.status,
      CallingStatus.awaitingKitchen,
    );
    expect((await calling.findByOrderId(50))!.status, CallingStatus.cancelled);
  });

  test('done のキッチン注文は不足扱いで再追加しない (race-safe)', () async {
    final _MemKitchenRepo repo = _MemKitchenRepo()
      ..upsert(
        KitchenOrder(
          orderId: 42,
          ticketNumber: const TicketNumber(42),
          itemsJson: '[]',
          status: KitchenStatus.done,
          receivedAt: DateTime(2026, 5, 16),
        ),
      );
    // server がまだ pending と思い込んでいる（提供完了の通知が遅延中）
    final ServerOrderSnapshot snap = ServerOrderSnapshot(
      kitchenPending: <int, TicketNumber>{42: const TicketNumber(42)},
      callingAwaiting: const <int, TicketNumber>{},
      callingCalled: const <int, TicketNumber>{},
    );
    final _ScriptedProbe probe =
        _ScriptedProbe(<ServerOrderSnapshot?>[snap, snap]);
    final ReconciliationService svc = ReconciliationService(
      probe: probe,
      kitchenRepository: repo,
      retryDelay: const Duration(milliseconds: 1),
    );
    final ReconciliationOutcome r = await svc.runOnce();
    // local 視点では「差分なし」: done は missing 対象外。pending でもないので extra でもない。
    expect(r.kind, ReconciliationOutcomeKind.inSync);
    expect((await repo.findByOrderId(42))!.status, KitchenStatus.done);
  });
}
