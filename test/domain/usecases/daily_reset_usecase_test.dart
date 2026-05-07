import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/repositories/daily_reset_repository.dart';
import 'package:tofu_pos/domain/usecases/daily_reset_usecase.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number_pool.dart';

import '../../fakes/fake_repositories.dart';

class _FakeDailyResetRepo implements DailyResetRepository {
  DateTime? lastResetDate;

  @override
  Future<DateTime?> getLastResetDate() async => lastResetDate;

  @override
  Future<void> setLastResetDate(DateTime date) async {
    lastResetDate = DateTime(date.year, date.month, date.day);
  }
}

void main() {
  late _FakeDailyResetRepo dailyResetRepo;
  late InMemoryTicketPoolRepository poolRepo;

  setUp(() {
    dailyResetRepo = _FakeDailyResetRepo();
    // プールに番号1を払い出した状態を初期値にする
    final TicketNumberPool dirty = TicketNumberPool.empty().issue().pool;
    poolRepo = InMemoryTicketPoolRepository(dirty);
  });

  test('first run: resets pool and stamps today', () async {
    final DailyResetUseCase u = DailyResetUseCase(
      dailyResetRepository: dailyResetRepo,
      ticketPoolRepository: poolRepo,
      now: () => DateTime(2026, 5, 7, 9),
    );
    final bool didReset = await u.runIfNeeded();
    expect(didReset, isTrue);

    final TicketNumberPool pool = await poolRepo.load();
    expect(pool.inUseNumbers, isEmpty);
    expect(pool.recentlyReleasedNumbers, isEmpty);
    expect(dailyResetRepo.lastResetDate, DateTime(2026, 5, 7));
  });

  test('same day: no reset', () async {
    dailyResetRepo.lastResetDate = DateTime(2026, 5, 7);
    final DailyResetUseCase u = DailyResetUseCase(
      dailyResetRepository: dailyResetRepo,
      ticketPoolRepository: poolRepo,
      now: () => DateTime(2026, 5, 7, 23, 59, 59),
    );
    final bool didReset = await u.runIfNeeded();
    expect(didReset, isFalse);
    final TicketNumberPool pool = await poolRepo.load();
    expect(pool.inUseNumbers, contains(1));
  });

  test('next day: resets and stamps new date', () async {
    dailyResetRepo.lastResetDate = DateTime(2026, 5, 7);
    final DailyResetUseCase u = DailyResetUseCase(
      dailyResetRepository: dailyResetRepo,
      ticketPoolRepository: poolRepo,
      now: () => DateTime(2026, 5, 8, 0, 0, 1),
    );
    final bool didReset = await u.runIfNeeded();
    expect(didReset, isTrue);
    expect(dailyResetRepo.lastResetDate, DateTime(2026, 5, 8));
    final TicketNumberPool pool = await poolRepo.load();
    expect(pool.inUseNumbers, isEmpty);
  });

  test('reset preserves pool config (maxNumber / bufferSize)', () async {
    poolRepo = InMemoryTicketPoolRepository(
      TicketNumberPool.empty(maxNumber: 50, bufferSize: 5),
    );
    final DailyResetUseCase u = DailyResetUseCase(
      dailyResetRepository: dailyResetRepo,
      ticketPoolRepository: poolRepo,
      now: () => DateTime(2026, 5, 7),
    );
    await u.runIfNeeded();
    final TicketNumberPool pool = await poolRepo.load();
    expect(pool.maxNumber, 50);
    expect(pool.bufferSize, 5);
  });

  test('use returned ticket number after reset', () async {
    final DailyResetUseCase u = DailyResetUseCase(
      dailyResetRepository: dailyResetRepo,
      ticketPoolRepository: poolRepo,
      now: () => DateTime(2026, 5, 7),
    );
    await u.runIfNeeded();
    final TicketNumberPool pool = await poolRepo.load();
    expect(pool.peekNext(), const TicketNumber(1));
  });
}
