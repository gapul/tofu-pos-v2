import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Supabase 接続情報があれば初期化する。なければ何もしない。
///
/// ネットワーク待ちで iOS の起動 watchdog (~20s) を超えないよう、
/// 第1フレーム描画後に呼び出す前提。
Future<void> initializeSupabaseIfConfigured() async {
  if (!Env.hasSupabaseCredentials) {
    return;
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
}
