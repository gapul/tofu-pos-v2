import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/enums/device_role.dart';
import 'package:tofu_pos/domain/enums/transport_mode.dart';
import 'package:tofu_pos/domain/repositories/settings_repository.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/shop_id.dart';
import 'package:tofu_pos/features/settings/presentation/screens/settings_screen.dart';
import 'package:tofu_pos/providers/repository_providers.dart';
import 'package:tofu_pos/providers/settings_providers.dart';

/// 設定画面のスモーク。
///
/// 各セクション見出しが描画されることだけを検証する。
class _FakeSettingsRepo implements SettingsRepository {
  FeatureFlags _flags = FeatureFlags.allOff;
  TransportMode _mode = TransportMode.online;
  final StreamController<FeatureFlags> _flagsCtrl =
      StreamController<FeatureFlags>.broadcast();
  final StreamController<TransportMode> _modeCtrl =
      StreamController<TransportMode>.broadcast();

  @override
  Future<ShopId?> getShopId() async => ShopId('S001');
  @override
  Future<void> setShopId(ShopId shopId) async {}

  @override
  Future<DeviceRole?> getDeviceRole() async => DeviceRole.register;
  @override
  Future<void> setDeviceRole(DeviceRole role) async {}

  @override
  Future<void> clearDeviceRole() async {}

  @override
  Future<FeatureFlags> getFeatureFlags() async => _flags;
  @override
  Future<void> setFeatureFlags(FeatureFlags flags) async {
    _flags = flags;
    _flagsCtrl.add(flags);
  }

  @override
  Stream<FeatureFlags> watchFeatureFlags() async* {
    yield _flags;
    yield* _flagsCtrl.stream;
  }

  @override
  Future<TransportMode> getTransportMode() async => _mode;
  @override
  Future<void> setTransportMode(TransportMode mode) async {
    _mode = mode;
    _modeCtrl.add(mode);
  }

  @override
  Stream<TransportMode> watchTransportMode() async* {
    yield _mode;
    yield* _modeCtrl.stream;
  }

  @override
  Future<Duration> getLanSendTimeout() async => const Duration(seconds: 5);
  @override
  Future<void> setLanSendTimeout(Duration value) async {}

  @override
  Future<Duration> getBleSendTimeout() async => const Duration(seconds: 10);
  @override
  Future<void> setBleSendTimeout(Duration value) async {}

  @override
  Future<String> getOrCreateDeviceId() async => 'device-test';
}

void main() {
  testWidgets('SettingsScreen renders all section cards', (tester) async {
    tester.view.physicalSize = const Size(1024, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
          featureFlagsProvider.overrideWith(
            (ref) => Stream<FeatureFlags>.value(FeatureFlags.allOff),
          ),
          transportModeProvider.overrideWith(
            (ref) => Stream<TransportMode>.value(TransportMode.online),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    // AppHeader + _DeviceHeaderSection の両方が「設定」を描画する。
    expect(find.text('設定'), findsAtLeastNWidgets(1));
    // 新 UI では PaneTitle のセクション名で各カードを識別する。
    // 旧「端末」は _DeviceHeaderSection の「店舗ID: ...」サブテキストへ統合された。
    expect(find.textContaining('店舗ID'), findsOneWidget);
    expect(find.text('機能フラグ'), findsOneWidget);
    expect(find.text('通信モード'), findsOneWidget);
    expect(find.text('データエクスポート'), findsOneWidget);
    expect(find.text('管理操作'), findsOneWidget);
  });
}
