import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_ticket_pool_repository.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number_pool.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPrefsTicketPoolRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    repo = SharedPrefsTicketPoolRepository(prefs);
  });

  test('load returns empty pool when no state stored', () async {
    final TicketNumberPool pool = await repo.load();
    expect(pool.maxNumber, 99);
    expect(pool.bufferSize, 10);
    expect(pool.inUseNumbers, isEmpty);
  });

  test('save and load round-trip', () async {
    TicketNumberPool pool = TicketNumberPool.empty();
    pool = pool.issue().pool; // 1 in use
    pool = pool.issue().pool; // 1, 2 in use
    pool = pool.release(const TicketNumber(1)); // 2 in use, 1 in buffer

    await repo.save(pool);

    final TicketNumberPool loaded = await repo.load();
    expect(loaded.inUseNumbers, <int>{2});
    expect(loaded.recentlyReleasedNumbers, <int>[1]);
    expect(loaded.maxNumber, pool.maxNumber);
    expect(loaded.bufferSize, pool.bufferSize);
  });

  test('default constructor parameters override empty pool defaults', () async {
    repo = SharedPrefsTicketPoolRepository(
      prefs,
      defaultMaxNumber: 50,
      defaultBufferSize: 5,
    );
    final TicketNumberPool pool = await repo.load();
    expect(pool.maxNumber, 50);
    expect(pool.bufferSize, 5);
  });
}
