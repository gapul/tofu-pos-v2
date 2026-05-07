import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 環境変数アクセサ。
///
/// 解決優先順位:
///   1. ビルド時 --dart-define（本番ビルド向け）
///   2. .env ファイル（開発時、`Env.load()` で事前読み込み必須）
///   3. デフォルト値（テスト時の空文字など）
///
/// 例:
/// ```dart
/// await Env.load();
/// print(Env.supabaseUrl);
/// ```
class Env {
  Env._();

  static const String _supabaseUrlDefine = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const String _supabaseAnonKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// `.env` を読み込む。アプリ起動時 `runApp` の前に1回だけ呼ぶ。
  ///
  /// `.env` が見つからない場合（CI 等）も例外にせず、
  /// その場合は --dart-define の値だけが効く。
  static Future<void> load() async {
    try {
      await dotenv.load();
    } catch (_) {
      // .env が無くても致命ではない（dart-define で渡せばよい）
    }
  }

  static String _read(String defineValue, String key) {
    if (defineValue.isNotEmpty) {
      return defineValue;
    }
    if (dotenv.isInitialized) {
      return dotenv.maybeGet(key) ?? '';
    }
    return '';
  }

  static String get supabaseUrl => _read(_supabaseUrlDefine, 'SUPABASE_URL');

  static String get supabaseAnonKey =>
      _read(_supabaseAnonKeyDefine, 'SUPABASE_ANON_KEY');

  /// Supabase 接続情報が揃っているか。
  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
