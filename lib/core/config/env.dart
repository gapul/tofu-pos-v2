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
/// 値の供給は **`--dart-define`（or `--dart-define-from-file`）のみ**。
/// ローカル開発は `tools/run-dev.sh` 経由で `.env` を読み込んで
/// `--dart-define` に展開する（asset 同梱は廃止：シークレット流出経路を防ぐため）。
///
/// 例:
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
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

  /// 互換のために残してある no-op。
  /// 旧 API で `await Env.load()` を呼んでいた箇所は触らずに済む。
  /// 値は `--dart-define` 経由で既に解決済み（コンパイル時定数）。
  static Future<void> load() async {}

  static String get supabaseUrl => _supabaseUrlDefine;

  static String get supabaseAnonKey => _supabaseAnonKeyDefine;

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
    if (_hasAnyDartDefine) {
      // 部分指定（片方だけ渡された）。呼び元で必要なら別途扱う。
      return;
    }
    log(
      'Supabase credentials not provided (no --dart-define). '
      'Cloud features (sync / telemetry) will be disabled. '
      'Use tools/run-dev.sh or pass --dart-define manually.',
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
      reasons.add(
        'SUPABASE_ANON_KEY does not look like a JWT or publishable key',
      );
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
      reasons.add(
        'SUPABASE_ANON_KEY does not look like a JWT or publishable key',
      );
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
    // JWT: 3 セグメントの base64url ドット区切り。全セグメントを検証。
    final List<String> parts = value.split('.');
    if (parts.length == 3) {
      final RegExp base64Url = RegExp(r'^[A-Za-z0-9_-]+$');
      if (parts.every((s) => s.isNotEmpty && base64Url.hasMatch(s))) {
        return true;
      }
    }
    // 新形式の Publishable Key（参考: sb_publishable_xxx）。
    if (value.startsWith('sb_publishable_') &&
        value.length > 'sb_publishable_'.length) {
      return true;
    }
    return false;
  }
}
