import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/telemetry/pii_redactor.dart';
import '../core/telemetry/supabase_telemetry_sink.dart';
import '../core/telemetry/telemetry.dart';
import '../core/telemetry/telemetry_sink.dart';
import '../domain/enums/device_role.dart';
import '../domain/value_objects/shop_id.dart';
import 'repository_providers.dart';

/// Supabase 接続が利用可能なときだけ Sink を返し、それ以外は Noop。
///
/// 送信前に [PiiRedactor] で attrs を redact する（多層防御）。
final Provider<TelemetrySink> telemetrySinkProvider = Provider<TelemetrySink>((
  ref,
) {
  if (!Env.hasSupabaseCredentials) {
    return const NoopTelemetrySink();
  }
  final SupabaseTelemetrySink inner = SupabaseTelemetrySink(
    Supabase.instance.client,
  );
  ref.onDispose(inner.close);
  return RedactingTelemetrySink(inner);
});

/// アプリ起動時に1回だけ実行する初期化。Telemetry のグローバル状態に
/// shop / device / role / appVersion を流し込む。
final FutureProvider<void> telemetryInitProvider = FutureProvider<void>((
  ref,
) async {
  final TelemetrySink sink = ref.watch(telemetrySinkProvider);
  if (sink is NoopTelemetrySink) {
    Telemetry.instance.reset();
    return;
  }
  final settings = ref.watch(settingsRepositoryProvider);
  final ShopId? shopId = await settings.getShopId();
  final DeviceRole? role = await settings.getDeviceRole();
  if (shopId == null || role == null) {
    // shop / role 未設定の段階ではテレメトリは無効。
    Telemetry.instance.reset();
    return;
  }
  final String deviceId = await settings.getOrCreateDeviceId();
  Telemetry.instance.configure(
    sink: sink,
    shopId: shopId.value,
    deviceId: deviceId,
    deviceRole: role.name,
  );
  Telemetry.instance.event('app.start');
});
