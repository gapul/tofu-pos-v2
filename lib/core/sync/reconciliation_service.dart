import 'dart:async';

import '../../domain/entities/calling_order.dart';
import '../../domain/entities/kitchen_order.dart';
import '../../domain/enums/calling_status.dart';
import '../../domain/enums/kitchen_status.dart';
import '../../domain/repositories/calling_order_repository.dart';
import '../../domain/repositories/kitchen_order_repository.dart';
import '../../domain/value_objects/ticket_number.dart';
import '../logging/app_logger.dart';
import '../telemetry/telemetry.dart';

/// 「レジ側 (= サーバ上の正のソース) が考える注文集合」のスナップショット。
///
/// 役割端末（kitchen / calling）はこれを定期的に取得して、自端末ローカル
/// ストアと突き合わせる。実装は Supabase の `device_events` / `order_lines`
/// から導出するのが基本（オフライン/BLE 経路では生成不能 = null を返す）。
class ServerOrderSnapshot {
  ServerOrderSnapshot({
    required this.kitchenPending,
    required this.callingAwaiting,
    required this.callingCalled,
  });

  /// キッチンが「未調理 (pending)」と認識すべき orderId の集合。
  /// レジ側で `sent` 状態（提供前）のものに相当。
  final Map<int, TicketNumber> kitchenPending;

  /// 呼び出し画面で「呼び出し前 (= awaitingKitchen + pending)」と認識すべき orderId。
  final Map<int, TicketNumber> callingAwaiting;

  /// 呼び出し画面で「呼び出し済 (called)」と認識すべき orderId。
  final Map<int, TicketNumber> callingCalled;
}

/// レジ側が考える「正しい状態」を取得する抽象。
///
/// 本番では Supabase に問い合わせる実装、テストでは固定値を返す実装を inject する。
abstract interface class ServerStateProbe {
  /// 失敗時は null を返す（reconciliation はその回スキップする）。
  Future<ServerOrderSnapshot?> fetch();
}

/// 定期整合性チェック。30 秒周期で `probe.fetch()` を呼び、ローカル drift を検出。
///
/// 仕様（プロンプト由来）:
///  - 齟齬を検出 → 5 秒待って再チェック（通信直後の race を吸収）。
///  - それでも残れば修正:
///    - kitchen: 不足を ingest（pending で追加）、余分を cancelled にマーク。
///    - calling: 同様。called 状態は ServedToCallRouter 経由判定なので、
///      余分 called → cancelled、不足 called → 何もしない（CallNumberEvent 経由で
///      自然に揃うことを期待）。
///
/// この service はレジ役では起動しない（プロンプト要件「レジ役は何もしない」）。
class ReconciliationService {
  ReconciliationService({
    required ServerStateProbe probe,
    this.kitchenRepository,
    this.callingRepository,
    Duration period = const Duration(seconds: 30),
    Duration retryDelay = const Duration(seconds: 5),
    DateTime Function() now = DateTime.now,
  })  : _probe = probe,
        _period = period,
        _retryDelay = retryDelay,
        _now = now;

  final ServerStateProbe _probe;
  final KitchenOrderRepository? kitchenRepository;
  final CallingOrderRepository? callingRepository;
  final Duration _period;
  final Duration _retryDelay;
  final DateTime Function() _now;

  Timer? _timer;
  bool _running = false;

  /// 起動。コンストラクタの `period` ごとに 1 回チェックを走らせる。多重起動防止つき。
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(_period, (_) => _tick());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// 1 サイクル分を手動で走らせる（テストや起動直後の即時実行用）。
  Future<ReconciliationOutcome> runOnce() => _tick();

  Future<ReconciliationOutcome> _tick() async {
    if (_running) {
      return const ReconciliationOutcome.skipped();
    }
    _running = true;
    try {
      final _Diff first = await _detectDiff();
      if (first.isEmpty) {
        return const ReconciliationOutcome.inSync();
      }
      AppLogger.event(
        'reconcile',
        'diff_detected',
        fields: <String, Object?>{
          'kitchen_missing': first.kitchenMissing.length,
          'kitchen_extra': first.kitchenExtra.length,
          'calling_missing_awaiting': first.callingMissingAwaiting.length,
          'calling_extra_awaiting': first.callingExtraAwaiting.length,
          'calling_extra_called': first.callingExtraCalled.length,
        },
      );
      // 5 秒待って race を吸収。
      await Future<void>.delayed(_retryDelay);
      final _Diff second = await _detectDiff();
      if (second.isEmpty) {
        Telemetry.instance.event(
          'reconcile.recovered_on_retry',
          attrs: <String, Object?>{},
        );
        return const ReconciliationOutcome.resolvedOnRetry();
      }
      // 修正
      await _apply(second);
      Telemetry.instance.warn(
        'reconcile.applied',
        attrs: <String, Object?>{
          'kitchen_missing': second.kitchenMissing.length,
          'kitchen_extra': second.kitchenExtra.length,
          'calling_missing_awaiting': second.callingMissingAwaiting.length,
          'calling_extra_awaiting': second.callingExtraAwaiting.length,
          'calling_extra_called': second.callingExtraCalled.length,
        },
      );
      return ReconciliationOutcome._appliedFromDiff(second);
    } catch (e, st) {
      AppLogger.w(
        'ReconciliationService: tick failed',
        error: e,
        stackTrace: st,
      );
      return const ReconciliationOutcome.skipped();
    } finally {
      _running = false;
    }
  }

  Future<_Diff> _detectDiff() async {
    final ServerOrderSnapshot? snap = await _probe.fetch();
    if (snap == null) {
      return _Diff.empty;
    }

    final Map<int, TicketNumber> kMissing = <int, TicketNumber>{};
    final Set<int> kExtra = <int>{};
    if (kitchenRepository != null) {
      final List<KitchenOrder> local = await kitchenRepository!.findAll();
      final Map<int, KitchenOrder> byId = <int, KitchenOrder>{
        for (final KitchenOrder o in local) o.orderId: o,
      };
      // missing: server に pending あり、local に無いか / cancelled。
      // ただし local が done のものは「キッチンの提供完了直後のレース対策」で
      // 再追加しない（プロンプト要件）。
      for (final MapEntry<int, TicketNumber> e in snap.kitchenPending.entries) {
        final KitchenOrder? l = byId[e.key];
        if (l == null) {
          kMissing[e.key] = e.value;
        } else if (l.status == KitchenStatus.cancelled) {
          // local が cancelled なら restore する。
          kMissing[e.key] = e.value;
        }
        // l.status == done / pending は再追加しない。
      }
      // extra: local に pending あり、server に無い。
      for (final KitchenOrder l in local) {
        if (l.status == KitchenStatus.pending &&
            !snap.kitchenPending.containsKey(l.orderId)) {
          kExtra.add(l.orderId);
        }
      }
    }

    final Map<int, TicketNumber> cMissingAwait = <int, TicketNumber>{};
    final Set<int> cExtraAwait = <int>{};
    final Set<int> cExtraCalled = <int>{};
    if (callingRepository != null) {
      final List<CallingOrder> local = await callingRepository!.findAll();
      final Map<int, CallingOrder> byId = <int, CallingOrder>{
        for (final CallingOrder o in local) o.orderId: o,
      };
      // awaiting (= server で called 前 = awaiting or pending) と
      // called の集合を server snapshot から組み立てる。
      for (final MapEntry<int, TicketNumber> e
          in snap.callingAwaiting.entries) {
        final CallingOrder? l = byId[e.key];
        if (l == null || l.status == CallingStatus.cancelled) {
          cMissingAwait[e.key] = e.value;
        }
      }
      for (final CallingOrder l in local) {
        final bool isAwait = l.status == CallingStatus.awaitingKitchen ||
            l.status == CallingStatus.pending;
        final bool isCalled = l.status == CallingStatus.called;
        if (isAwait && !snap.callingAwaiting.containsKey(l.orderId)) {
          cExtraAwait.add(l.orderId);
        }
        if (isCalled && !snap.callingCalled.containsKey(l.orderId)) {
          cExtraCalled.add(l.orderId);
        }
      }
    }

    return _Diff(
      kitchenMissing: kMissing,
      kitchenExtra: kExtra,
      callingMissingAwaiting: cMissingAwait,
      callingExtraAwaiting: cExtraAwait,
      callingExtraCalled: cExtraCalled,
    );
  }

  Future<void> _apply(_Diff diff) async {
    final DateTime now = _now();
    if (kitchenRepository != null) {
      for (final MapEntry<int, TicketNumber> e in diff.kitchenMissing.entries) {
        await kitchenRepository!.upsert(
          KitchenOrder(
            orderId: e.key,
            ticketNumber: e.value,
            itemsJson: '[]', // 詳細は別経路（OrderSubmittedEvent backfill）で更新される。
            status: KitchenStatus.pending,
            receivedAt: now,
          ),
        );
      }
      for (final int id in diff.kitchenExtra) {
        await kitchenRepository!.updateStatus(id, KitchenStatus.cancelled);
      }
    }
    if (callingRepository != null) {
      for (final MapEntry<int, TicketNumber> e
          in diff.callingMissingAwaiting.entries) {
        await callingRepository!.upsert(
          CallingOrder(
            orderId: e.key,
            ticketNumber: e.value,
            status: CallingStatus.awaitingKitchen,
            receivedAt: now,
          ),
        );
      }
      for (final int id in diff.callingExtraAwaiting) {
        await callingRepository!.updateStatus(id, CallingStatus.cancelled);
      }
      for (final int id in diff.callingExtraCalled) {
        await callingRepository!.updateStatus(id, CallingStatus.cancelled);
      }
    }
  }
}

class _Diff {
  const _Diff({
    required this.kitchenMissing,
    required this.kitchenExtra,
    required this.callingMissingAwaiting,
    required this.callingExtraAwaiting,
    required this.callingExtraCalled,
  });

  final Map<int, TicketNumber> kitchenMissing;
  final Set<int> kitchenExtra;
  final Map<int, TicketNumber> callingMissingAwaiting;
  final Set<int> callingExtraAwaiting;
  final Set<int> callingExtraCalled;

  static const _Diff empty = _Diff(
    kitchenMissing: <int, TicketNumber>{},
    kitchenExtra: <int>{},
    callingMissingAwaiting: <int, TicketNumber>{},
    callingExtraAwaiting: <int>{},
    callingExtraCalled: <int>{},
  );

  bool get isEmpty =>
      kitchenMissing.isEmpty &&
      kitchenExtra.isEmpty &&
      callingMissingAwaiting.isEmpty &&
      callingExtraAwaiting.isEmpty &&
      callingExtraCalled.isEmpty;
}

/// reconciliation 1 サイクルの結果（テスト/Telemetry 用）。
class ReconciliationOutcome {
  const ReconciliationOutcome.inSync()
      : kind = ReconciliationOutcomeKind.inSync,
        appliedDiff = null;
  const ReconciliationOutcome.resolvedOnRetry()
      : kind = ReconciliationOutcomeKind.resolvedOnRetry,
        appliedDiff = null;
  const ReconciliationOutcome.skipped()
      : kind = ReconciliationOutcomeKind.skipped,
        appliedDiff = null;
  factory ReconciliationOutcome._appliedFromDiff(_Diff diff) {
    return ReconciliationOutcome._applied(
      ReconciliationAppliedSummary(
        kitchenAdded: diff.kitchenMissing.length,
        kitchenCancelled: diff.kitchenExtra.length,
        callingAdded: diff.callingMissingAwaiting.length,
        callingCancelled:
            diff.callingExtraAwaiting.length + diff.callingExtraCalled.length,
      ),
    );
  }
  const ReconciliationOutcome._applied(ReconciliationAppliedSummary summary)
      : kind = ReconciliationOutcomeKind.applied,
        appliedDiff = summary;

  final ReconciliationOutcomeKind kind;
  final ReconciliationAppliedSummary? appliedDiff;
}

enum ReconciliationOutcomeKind {
  inSync,
  resolvedOnRetry,
  applied,
  skipped,
}

class ReconciliationAppliedSummary {
  const ReconciliationAppliedSummary({
    required this.kitchenAdded,
    required this.kitchenCancelled,
    required this.callingAdded,
    required this.callingCancelled,
  });
  final int kitchenAdded;
  final int kitchenCancelled;
  final int callingAdded;
  final int callingCancelled;
}
