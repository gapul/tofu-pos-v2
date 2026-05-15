import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_status.dart';

/// 端末のネット接続状態を [ConnectivityStatus] の Stream として公開する。
///
/// 仕様書 §7.1: 通信モード切替は **手動**だが、
/// 「オンラインモード時にエラーが出やすいか」の参考情報として UI に表示する用途を想定。
abstract interface class ConnectivityMonitor {
  ConnectivityStatus get current;
  Stream<ConnectivityStatus> watch();
}

/// connectivity_plus を使った本番実装。
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _sub = _connectivity.onConnectivityChanged.listen(_onChanged);
    // 初期値を取得
    unawaited(_connectivity.checkConnectivity().then(_onChanged));
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _current = ConnectivityStatus.offline;

  static ConnectivityStatus _classify(List<ConnectivityResult> results) {
    final bool hasNetwork = results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
    return hasNetwork ? ConnectivityStatus.online : ConnectivityStatus.offline;
  }

  void _onChanged(List<ConnectivityResult> results) {
    final ConnectivityStatus next = _classify(results);
    if (next != _current) {
      _current = next;
      _controller.add(next);
    }
  }

  @override
  ConnectivityStatus get current => _current;

  @override
  Stream<ConnectivityStatus> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _controller.close();
  }
}
