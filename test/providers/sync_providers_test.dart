import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/sync/sync_service.dart';
import 'package:tofu_pos/core/time/clock.dart';
import 'package:tofu_pos/providers/sync_providers.dart';

/// `realtimeOrderLineEventsProvider` と `rawRealtimeOrderLineEventsProvider`
/// の分離（B 監査対応）の最低限のスモーク。
///
/// 実 Supabase 接続を立ち上げないので、ここでは Provider 同士の同義性と
/// 警告判定ロジック（純関数）に絞って検証する。
class _FrozenClock extends Clock {
  _FrozenClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
  @override
  DateTime todayJst() => DateTime(_now.year, _now.month, _now.day);
  @override
  DateTime nowUtc() => _now.toUtc();
}

void main() {
  group('sync_providers separation', () {
    test(
      'realtimeOrderLineEventsProvider == rawRealtimeOrderLineEventsProvider',
      () {
        // 旧 API は新 raw Provider と同一インスタンスのエイリアス。
        // 既存の参照を壊さない（B 監査の互換性確認）。
        expect(
          identical(
            realtimeOrderLineEventsProvider,
            rawRealtimeOrderLineEventsProvider,
          ),
          isTrue,
        );
      },
    );
  });

  group('evaluateSyncWarningNow', () {
    test('lastFailureSince == null なら ok', () {
      final SyncService service = _FakeSyncService(null);
      final Clock clock = _FrozenClock(DateTime(2026, 5, 11, 12));
      expect(
        evaluateSyncWarningNow(service, clock: clock),
        SyncWarningLevel.ok,
      );
    });

    test('失敗継続 1 時間未満なら ok', () {
      final DateTime now = DateTime(2026, 5, 11, 12);
      final SyncService service = _FakeSyncService(
        now.subtract(const Duration(minutes: 59)),
      );
      final Clock clock = _FrozenClock(now);
      expect(
        evaluateSyncWarningNow(service, clock: clock),
        SyncWarningLevel.ok,
      );
    });

    test('失敗継続 1 時間以上なら prolongedFailure', () {
      final DateTime now = DateTime(2026, 5, 11, 12);
      final SyncService service = _FakeSyncService(
        now.subtract(const Duration(hours: 1, minutes: 1)),
      );
      final Clock clock = _FrozenClock(now);
      expect(
        evaluateSyncWarningNow(service, clock: clock),
        SyncWarningLevel.prolongedFailure,
      );
    });
  });
}

/// `lastFailureSince` だけを返せれば良いので最低限の偽実装。
class _FakeSyncService implements SyncService {
  _FakeSyncService(this._since);
  final DateTime? _since;

  @override
  DateTime? get lastFailureSince => _since;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
