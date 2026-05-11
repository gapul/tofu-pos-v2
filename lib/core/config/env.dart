import 'package:flutter_dotenv/flutter_dotenv.dart';

/// `Env.validate()` の結果。
sealed class EnvValidation {
  const EnvValidation();
}

/// 検証 OK（Supabase 認証情報が無い場合はそもそも検証対象外で Valid 扱い）。
class EnvValid extends EnvValidation {
  const EnvValid();
}

/// 検証 NG。reasons には人間可読な理由が積まれる。
class EnvInvalid extends EnvValidation {
  const EnvInvalid(this.reasons);
  final List<String> reasons;
}

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

  /// dart-define が一切渡されていないか（[warnIfMissing] の判定用）。
  static bool get _hasAnyDartDefine =>
      _supabaseUrlDefine.isNotEmpty || _supabaseAnonKeyDefine.isNotEmpty;

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

  /// `.env` も `--dart-define` も供給されていない場合に
  /// 「Supabase が無効化される」旨を1回だけ通知する。
  ///
  /// 致命ではないので例外は投げない。可視化のためだけのログ。
  /// `runApp` の前に呼ぶ。
  static void warnIfMissing(void Function(String message) log) {
    if (hasSupabaseCredentials) {
      return;
    }
    if (_hasAnyDartDefine || dotenv.isInitialized) {
      // 何かしら設定は試みられている（部分指定など）。それ用のログは
      // ここでは出さず、呼び元で必要なら別途扱う。
      return;
    }
    log(
      'Supabase credentials not provided (no .env, no --dart-define). '
      'Cloud features (sync / telemetry) will be disabled.',
    );
  }

  /// Supabase 認証情報の形式検証。
  ///
  /// `hasSupabaseCredentials == false` の場合は意図的な無効化と見なし [EnvValid]。
  /// 認証情報が「あるが形式が壊れている」場合のみ [EnvInvalid] を返す。
  ///
  /// チェック内容:
  ///  - URL が `https://*.supabase.co` 形式
  ///  - anonKey が JWT または `sb_publishable_` で始まる Publishable Key
  ///    （署名検証はしない。プロジェクト ID や有効期限は見ない）
  static EnvValidation validate() {
    if (!hasSupabaseCredentials) {
      return const EnvValid();
    }
    final List<String> reasons = <String>[];
    if (!_isValidSupabaseUrl(supabaseUrl)) {
      reasons.add('SUPABASE_URL is not a valid https://*.supabase.co URL');
    }
    if (!_looksLikeAnonKey(supabaseAnonKey)) {
      reasons.add('SUPABASE_ANON_KEY does not look like a JWT or publishable key');
    }
    return reasons.isEmpty ? const EnvValid() : EnvInvalid(reasons);
  }

  /// 検証ロジックを外部公開した版（テスト用）。
  /// 通常コードパスでは [validate] を使うこと。
  static EnvValidation validateValues({
    required String url,
    required String anonKey,
  }) {
    if (url.isEmpty && anonKey.isEmpty) {
      return const EnvValid();
    }
    final List<String> reasons = <String>[];
    if (!_isValidSupabaseUrl(url)) {
      reasons.add('SUPABASE_URL is not a valid https://*.supabase.co URL');
    }
    if (!_looksLikeAnonKey(anonKey)) {
      reasons.add('SUPABASE_ANON_KEY does not look like a JWT or publishable key');
    }
    return reasons.isEmpty ? const EnvValid() : EnvInvalid(reasons);
  }

  static bool _isValidSupabaseUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    // *.supabase.co または *.supabase.in を許可。
    return uri.host.endsWith('.supabase.co') ||
        uri.host.endsWith('.supabase.in');
  }

  static bool _looksLikeAnonKey(String value) {
    if (value.isEmpty) return false;
    // JWT: 3 セグメントの base64url ドット区切り。
    final List<String> parts = value.split('.');
    if (parts.length == 3 &&
        parts.every((s) => s.isNotEmpty) &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(parts.first)) {
      return true;
    }
    // 新形式の Publishable Key（参考: sb_publishable_xxx）。
    if (value.startsWith('sb_publishable_') && value.length > 'sb_publishable_'.length) {
      return true;
    }
    return false;
  }
}
