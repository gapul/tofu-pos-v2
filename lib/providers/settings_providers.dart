import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums/transport_mode.dart';
import '../domain/value_objects/feature_flags.dart';
import 'repository_providers.dart';

/// 機能フラグの現在値を Stream で公開（仕様書 §4）。
final StreamProvider<FeatureFlags> featureFlagsProvider =
    StreamProvider<FeatureFlags>(
      (ref) => ref.watch(settingsRepositoryProvider).watchFeatureFlags(),
    );

/// 通信モードの現在値を Stream で公開（仕様書 §7.1）。
final StreamProvider<TransportMode> transportModeProvider =
    StreamProvider<TransportMode>(
      (ref) => ref.watch(settingsRepositoryProvider).watchTransportMode(),
    );
