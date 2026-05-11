import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/connectivity_monitor.dart';
import '../core/connectivity/connectivity_status.dart';

final Provider<ConnectivityMonitor> connectivityMonitorProvider =
    Provider<ConnectivityMonitor>((ref) {
      final ConnectivityPlusMonitor monitor = ConnectivityPlusMonitor();
      ref.onDispose(monitor.dispose);
      return monitor;
    });

/// 現在のネット接続状態を Stream で公開。
final StreamProvider<ConnectivityStatus> connectivityStatusProvider =
    StreamProvider<ConnectivityStatus>(
      (ref) =>
          ref.watch(connectivityMonitorProvider).watch(),
    );
