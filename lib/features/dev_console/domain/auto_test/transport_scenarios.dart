import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../../core/transport/transport_event.dart';
import '../../../../domain/enums/transport_mode.dart';
import '../../../../domain/value_objects/ticket_number.dart';
import 'scenario.dart';
import 'scenario_context.dart';

/// 通信経路（online / LAN / BT）系のシナリオ群。
///
/// 設計方針:
///  - 前提が満たされない（Transport 未取得 / TransportMode 不一致 / Supabase
///    creds 無し）場合は `ScenarioResult.skip` で中立に返す。
///  - 送信失敗・受信ストリーム異常は `ScenarioResult.fail` で返す（握り潰さない）。
///  - 5番（peer_kitchen.echo_30s）は 30 秒で自然終了。明示的なキャンセル機構が
///    無いため、タイマー経過で `await for` を抜ける。
List<TestScenario> transportScenarios() => <TestScenario>[
  _onlineSendPersistsScenario,
  _localLanBroadcastScenario,
  _bluetoothBroadcastScenario,
  _eventsStreamAliveScenario,
  _peerKitchenEcho30sScenario,
  _peerRegisterRoundtripScenario,
];

const Uuid _uuid = Uuid();

// === 1. online.send_persists ==============================================

const TestScenario _onlineSendPersistsScenario = TestScenario(
  id: 'transport.online.send_persists',
  name: '通信: online 送信が device_events に保存される',
  description:
      'TransportMode=online かつ Supabase creds がある前提で、'
      'Transport.send が device_events 行を作るか（10s 以内）',
  run: _runOnlineSendPersists,
);

Future<ScenarioResult> _runOnlineSendPersists(ScenarioContext ctx) async {
  if (ctx.transport == null) {
    return ScenarioResult.skip('transport not available');
  }
  if (ctx.transportMode != TransportMode.online) {
    return ScenarioResult.skip(
      'TransportMode is ${ctx.transportMode}, not online',
    );
  }
  if (!ctx.hasSupabaseCredentials) {
    return ScenarioResult.skip('Supabase credentials are not configured');
  }
  if (ctx.supabaseClient == null) {
    return ScenarioResult.skip('Supabase client unavailable');
  }
  if (ctx.shopId == null) {
    return ScenarioResult.skip('shopId not configured');
  }

  final String eventId = _uuid.v4();
  final OrderSubmittedEvent ev = OrderSubmittedEvent(
    shopId: ctx.shopId!,
    eventId: eventId,
    occurredAt: DateTime.now().toUtc(),
    orderId: -1,
    ticketNumber: const TicketNumber(999),
    itemsJson: '[]',
  );

  try {
    await ctx.transport!.send(ev);
  } catch (e) {
    return ScenarioResult.fail('send failed: $e');
  }

  // 10 秒以内に行が見えるかをポーリング。
  final Stopwatch sw = Stopwatch()..start();
  const Duration timeout = Duration(seconds: 10);
  const Duration interval = Duration(milliseconds: 500);

  while (sw.elapsed < timeout) {
    try {
      final List<dynamic> rows = await ctx.supabaseClient!
          .from('device_events')
          .select()
          .eq('shop_id', ctx.shopId!)
          .eq('event_id', eventId);
      if (rows.isNotEmpty) {
        return ScenarioResult.pass(
          'row found in ${sw.elapsed.inMilliseconds}ms (event_id=$eventId)',
        );
      }
    } catch (e) {
      return ScenarioResult.fail('query failed: $e');
    }
    await Future<void>.delayed(interval);
  }
  return ScenarioResult.fail(
    'row not visible in ${timeout.inSeconds}s (event_id=$eventId)',
  );
}

// === 2. local_lan.broadcast_no_error ======================================

const TestScenario _localLanBroadcastScenario = TestScenario(
  id: 'transport.local_lan.broadcast_no_error',
  name: '通信: LAN 送信が例外を投げない',
  description:
      'TransportMode=localLan 前提で、Transport.send が例外なく完了するか'
      '（受信側があるかは検証しない）',
  run: _runLocalLanBroadcast,
);

Future<ScenarioResult> _runLocalLanBroadcast(ScenarioContext ctx) async {
  if (ctx.transport == null) {
    return ScenarioResult.skip('transport not available');
  }
  if (ctx.transportMode != TransportMode.localLan) {
    return ScenarioResult.skip(
      'TransportMode is ${ctx.transportMode}, not localLan',
    );
  }
  if (ctx.shopId == null) {
    return ScenarioResult.skip('shopId not configured');
  }

  final OrderSubmittedEvent ev = OrderSubmittedEvent(
    shopId: ctx.shopId!,
    eventId: _uuid.v4(),
    occurredAt: DateTime.now().toUtc(),
    orderId: -1,
    ticketNumber: const TicketNumber(999),
    itemsJson: '[]',
  );

  try {
    await ctx.transport!.send(ev);
    return ScenarioResult.pass('LAN send completed without exception');
  } catch (e) {
    return ScenarioResult.fail('send threw: $e');
  }
}

// === 3. bluetooth.broadcast_no_error ======================================

const TestScenario _bluetoothBroadcastScenario = TestScenario(
  id: 'transport.bluetooth.broadcast_no_error',
  name: '通信: BT 送信が例外を投げない',
  description:
      'TransportMode=bluetooth 前提で、Transport.send が例外なく完了するか'
      '（ペアリング検証はしない）',
  run: _runBluetoothBroadcast,
);

Future<ScenarioResult> _runBluetoothBroadcast(ScenarioContext ctx) async {
  if (ctx.transport == null) {
    return ScenarioResult.skip('transport not available');
  }
  if (ctx.transportMode != TransportMode.bluetooth) {
    return ScenarioResult.skip(
      'TransportMode is ${ctx.transportMode}, not bluetooth',
    );
  }
  if (ctx.shopId == null) {
    return ScenarioResult.skip('shopId not configured');
  }

  final OrderSubmittedEvent ev = OrderSubmittedEvent(
    shopId: ctx.shopId!,
    eventId: _uuid.v4(),
    occurredAt: DateTime.now().toUtc(),
    orderId: -1,
    ticketNumber: const TicketNumber(999),
    itemsJson: '[]',
  );

  try {
    await ctx.transport!.send(ev);
    return ScenarioResult.pass('BT send completed without exception');
  } catch (e) {
    return ScenarioResult.fail('send threw: $e');
  }
}

// === 4. events.stream_alive ==============================================

const TestScenario _eventsStreamAliveScenario = TestScenario(
  id: 'transport.events.stream_alive',
  name: '通信: events ストリーム健全性',
  description:
      'Transport.events() を 5s 購読、close されず例外も出ないこと、'
      '自送信イベントは loopback dedup で来ないこと',
  run: _runEventsStreamAlive,
);

Future<ScenarioResult> _runEventsStreamAlive(ScenarioContext ctx) async {
  if (ctx.transport == null) {
    return ScenarioResult.skip('transport not available');
  }
  if (ctx.shopId == null) {
    return ScenarioResult.skip('shopId not configured');
  }

  final List<TransportEvent> received = <TransportEvent>[];
  Object? streamError;
  final String selfEventId = _uuid.v4();

  late final StreamSubscription<TransportEvent> sub;
  final Completer<void> doneCompleter = Completer<void>();
  sub = ctx.transport!.events().listen(
    received.add,
    onError: (Object e, StackTrace _) {
      streamError = e;
    },
    onDone: () {
      if (!doneCompleter.isCompleted) {
        doneCompleter.complete();
      }
    },
  );

  // 1 件だけ自送信して、loopback で戻ってこないことを観察する。
  try {
    await ctx.transport!.send(
      OrderSubmittedEvent(
        shopId: ctx.shopId!,
        eventId: selfEventId,
        occurredAt: DateTime.now().toUtc(),
        orderId: -1,
        ticketNumber: const TicketNumber(998),
        itemsJson: '[]',
      ),
    );
  } catch (e) {
    await sub.cancel();
    return ScenarioResult.fail('send during stream check threw: $e');
  }

  await Future<void>.delayed(const Duration(seconds: 5));
  await sub.cancel();

  if (streamError != null) {
    return ScenarioResult.fail('stream emitted error: $streamError');
  }
  if (doneCompleter.isCompleted) {
    return ScenarioResult.fail('stream closed unexpectedly during 5s window');
  }
  final bool sawEcho = received.any((e) => e.eventId == selfEventId);
  if (sawEcho) {
    return ScenarioResult.fail(
      'loopback dedup failed: self event echoed back (event_id=$selfEventId)',
    );
  }
  return ScenarioResult.pass(
    'stream alive 5s, received ${received.length} foreign event(s), '
    'self-loopback suppressed',
  );
}

// === 5. peer_kitchen.echo_30s ============================================

const TestScenario _peerKitchenEcho30sScenario = TestScenario(
  id: 'transport.peer_kitchen.echo_30s',
  name: '通信: ピア(キッチン役) 30s エコー',
  description:
      '30秒間キッチン役として動作。OrderSubmittedEvent を受信したら '
      'OrderServedEvent を即時返す。レジ役端末の roundtrip テストの相方。',
  run: _runPeerKitchenEcho30s,
);

Future<ScenarioResult> _runPeerKitchenEcho30s(ScenarioContext ctx) async {
  if (ctx.transport == null) {
    return ScenarioResult.skip('transport not available');
  }
  if (ctx.shopId == null) {
    return ScenarioResult.skip('shopId not configured');
  }

  const Duration window = Duration(seconds: 30);
  int echoed = 0;
  Object? sendError;

  final StreamSubscription<TransportEvent> sub = ctx.transport!.events().listen(
    (ev) async {
      if (ev is! OrderSubmittedEvent) return;
      if (ev.shopId != ctx.shopId) return;
      try {
        await ctx.transport!.send(
          OrderServedEvent(
            shopId: ev.shopId,
            eventId: _uuid.v4(),
            occurredAt: DateTime.now().toUtc(),
            orderId: ev.orderId,
            ticketNumber: ev.ticketNumber,
          ),
        );
        echoed++;
      } catch (e) {
        sendError = e;
      }
    },
  );

  await Future<void>.delayed(window);
  await sub.cancel();

  if (sendError != null && echoed == 0) {
    return ScenarioResult.fail(
      'never managed to echo (last error: $sendError)',
    );
  }
  return ScenarioResult.pass(
    'echoed $echoed event(s) in ${window.inSeconds}s'
    '${sendError != null ? " (some echoes failed: $sendError)" : ""}',
  );
}

// === 6. peer_register.roundtrip_3 ========================================

const TestScenario _peerRegisterRoundtripScenario = TestScenario(
  id: 'transport.peer_register.roundtrip_3',
  name: '通信: ピア(レジ役) 3件 roundtrip',
  description:
      '3 件 OrderSubmittedEvent を 1s 間隔で送信、各 event に対応する '
      'OrderServedEvent が 5s 以内に届くこと。相方は peer_kitchen.echo_30s。',
  run: _runPeerRegisterRoundtrip,
);

Future<ScenarioResult> _runPeerRegisterRoundtrip(ScenarioContext ctx) async {
  if (ctx.transport == null) {
    return ScenarioResult.skip('transport not available');
  }
  if (ctx.shopId == null) {
    return ScenarioResult.skip('shopId not configured');
  }

  // 受信側を先に張る。
  final Map<int, Completer<void>> waiters = <int, Completer<void>>{};
  Object? streamError;
  final StreamSubscription<TransportEvent> sub = ctx.transport!.events().listen(
    (ev) {
      if (ev is OrderServedEvent && ev.shopId == ctx.shopId) {
        final Completer<void>? c = waiters[ev.orderId];
        if (c != null && !c.isCompleted) {
          c.complete();
        }
      }
    },
    onError: (Object e, StackTrace _) {
      streamError = e;
    },
  );

  const int count = 3;
  final List<int> orderIds = <int>[];
  try {
    for (int i = 0; i < count; i++) {
      // orderId は端末固有・かつ pos/neg 識別できればよいので大きめの負値を採用。
      final int orderId =
          -1000 - DateTime.now().microsecondsSinceEpoch % 100000 - i;
      orderIds.add(orderId);
      waiters[orderId] = Completer<void>();
      try {
        await ctx.transport!.send(
          OrderSubmittedEvent(
            shopId: ctx.shopId!,
            eventId: _uuid.v4(),
            occurredAt: DateTime.now().toUtc(),
            orderId: orderId,
            ticketNumber: TicketNumber(900 + i),
            itemsJson: '[]',
          ),
        );
      } catch (e) {
        await sub.cancel();
        return ScenarioResult.fail('send #${i + 1} failed: $e');
      }
      if (i < count - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    // 全 waiter を 5s 以内に解決させる。
    final List<int> missing = <int>[];
    for (final int id in orderIds) {
      try {
        await waiters[id]!.future.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        missing.add(id);
      }
    }

    if (streamError != null) {
      return ScenarioResult.fail('stream error: $streamError');
    }
    if (missing.isNotEmpty) {
      return ScenarioResult.fail(
        'missing ${missing.length}/$count echo(es) for orderIds=$missing — '
        'もう1台で transport.peer_kitchen.echo_30s が実行されているか確認してください',
      );
    }
    return ScenarioResult.pass('all $count roundtrips returned within 5s');
  } finally {
    await sub.cancel();
  }
}
