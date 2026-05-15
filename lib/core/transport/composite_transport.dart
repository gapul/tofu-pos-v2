import 'dart:async';
import 'dart:collection';

import '../error/app_exceptions.dart' show TransportDeliveryException;
import '../logging/app_logger.dart';
import '../telemetry/telemetry.dart';
import 'transport.dart';
import 'transport_event.dart';

/// オンライン主経路と BLE 副経路を並走させる Transport。
///
/// 仕様:
///  - events() は両 transport の受信を merge し、eventId で重複を抑止。
///  - send() は primary(online) を先に試みる。送信失敗時のみ BLE に fallback。
///    ただし bleEligible が false のイベント（商品マスタなど大データ）は
///    BLE には絶対に流さない（ユーザー要件）。
///  - connect() は両方を順に起動する。片方の失敗で全体は失敗させない
///    （業務継続を優先）。
///
/// 主経路の生死は send() の例外で判定する（外部からの connectivity 監視
/// は呼び出し側で別途行う）。主経路復帰時に BLE を停止する責務は持たない
/// （restart させる場合は provider 側で transport を rebuild する）。
///
/// 将来課題: connectivityProvider と連動した自動 connect/disconnect、
/// オンライン復帰時の resubscribe トリガ、role==register での Peripheral
/// 並走（複数役兼任のシナリオ）。今は最低限 register/kitchen/calling 各々に
/// 同一 shop_id の peer が居ることを期待する設計。
class CompositeOnlineBleTransport implements Transport {
  CompositeOnlineBleTransport({
    required Transport primary,
    required Transport secondary,
    bool Function(TransportEvent)? bleEligible,
  })  : _primary = primary,
        _secondary = secondary,
        _bleEligible = bleEligible ?? _defaultBleEligible;

  final Transport _primary;
  final Transport _secondary;
  final bool Function(TransportEvent) _bleEligible;

  /// 直近受信した eventId のリングバッファ (200 件)。merge 時の重複抑止用。
  final _DedupRing _seen = _DedupRing();

  StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();
  StreamSubscription<TransportEvent>? _primarySub;
  StreamSubscription<TransportEvent>? _secondarySub;

  /// 直近の primary 送信成否を表す簡易フラグ。Telemetry 用。
  bool get primaryHealthy => _primaryHealthy;
  bool _primaryHealthy = true;

  /// テスト用: BLE fallback に切り替わったかどうかを確認するためのフラグ。
  bool get didFallback => _didFallback;
  bool _didFallback = false;

  static bool _defaultBleEligible(TransportEvent e) {
    // 商品マスタは絶対に BLE で送らない（サイズ大 / 初回のみ online で取得すべき）。
    if (e is ProductMasterUpdateEvent) return false;
    return true;
  }

  @override
  Stream<TransportEvent> events() => _events.stream;

  @override
  Future<void> connect() async {
    if (_events.isClosed) {
      _events = StreamController<TransportEvent>.broadcast();
    }
    try {
      await _primary.connect();
    } catch (e, st) {
      AppLogger.w(
        'CompositeTransport: primary connect failed',
        error: e,
        stackTrace: st,
      );
      _primaryHealthy = false;
    }
    try {
      await _secondary.connect();
    } catch (e, st) {
      // BLE は実機限定。テスト/シミュレータでは起動失敗が普通なので warn 止まり。
      AppLogger.w(
        'CompositeTransport: secondary(BLE) connect failed',
        error: e,
        stackTrace: st,
      );
    }
    _primarySub = _primary.events().listen(_onPrimary);
    _secondarySub = _secondary.events().listen(_onSecondary);
  }

  void _onPrimary(TransportEvent e) {
    if (_seen.addIfAbsent(e.eventId)) {
      if (!_events.isClosed) _events.add(e);
    }
  }

  void _onSecondary(TransportEvent e) {
    if (_seen.addIfAbsent(e.eventId)) {
      if (!_events.isClosed) _events.add(e);
    }
  }

  @override
  Future<void> disconnect() async {
    await _primarySub?.cancel();
    _primarySub = null;
    await _secondarySub?.cancel();
    _secondarySub = null;
    try {
      await _primary.disconnect();
    } catch (_) {/* swallow */}
    try {
      await _secondary.disconnect();
    } catch (_) {/* swallow */}
    if (!_events.isClosed) await _events.close();
  }

  @override
  Future<void> send(TransportEvent event) async {
    // 自送信もループバック抑止のため事前登録（自分が両経路から受け取らないように）。
    _seen.addIfAbsent(event.eventId);

    // 送信側の primary が成功しても、**受信側端末の primary (Realtime) が
    // 死んでいるケース**（DNS 不安定 / WebSocket 切断後の reconnect ループ等）
    // で push が届かない事故が観測された。これを救うため、BLE eligible な
    // イベントは常に BLE にも並行送信する（fire-and-forget、失敗は warn 止まり）。
    if (_bleEligible(event)) {
      unawaited(
        _secondary.send(event).catchError((Object e, StackTrace st) {
          AppLogger.w(
            'CompositeTransport: parallel BLE send failed (ignored)',
            error: e,
            stackTrace: st,
          );
        }),
      );
    }

    try {
      await _primary.send(event);
      _primaryHealthy = true;
      return;
    } catch (e, st) {
      _primaryHealthy = false;
      AppLogger.w(
        'CompositeTransport: primary send failed, awaiting BLE fallback',
        error: e,
        stackTrace: st,
      );
      Telemetry.instance.warn(
        'transport.composite.primary_failed',
        attrs: <String, Object?>{
          'event_type': event.runtimeType.toString(),
          'error': e.toString(),
        },
      );
      if (!_bleEligible(event)) {
        throw TransportDeliveryException(
          'primary send failed and event not eligible for BLE fallback '
          '(${event.runtimeType}): $e',
        );
      }
      // BLE は既に fire-and-forget で発射済。primary が失敗しても、BLE が
      // 並行で送ってくれているはず。とはいえユーザー視点で「送信失敗」を
      // 通知しない方が業務上は望ましい（receiver 側に届いていれば OK）。
      // ただし完全に確信が無いので一応 didFallback フラグだけ立てて
      // 例外は投げず success とする。受信側の reconciliation 経路で整合性を担保。
      _didFallback = true;
      Telemetry.instance.warn(
        'transport.composite.ble_fallback_only',
        attrs: <String, Object?>{
          'event_type': event.runtimeType.toString(),
        },
      );
    }
  }
}

/// `eventId` の最近 200 件を覚えるだけのリングバッファ。
class _DedupRing {
  _DedupRing();
  static const int max = 200;
  final LinkedHashSet<String> _ids = LinkedHashSet<String>();

  /// 新規なら true を返し、登録する。既にあれば false。
  bool addIfAbsent(String id) {
    if (_ids.contains(id)) return false;
    _ids.add(id);
    while (_ids.length > max) {
      _ids.remove(_ids.first);
    }
    return true;
  }
}
