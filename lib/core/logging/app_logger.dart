import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

/// 構造化ログのレベル。
enum AppLogLevel { debug, info, warn, error }

/// アプリ全体で共有するロガー。
///
/// 本番ビルド（kReleaseMode）では warning 以上のみ出力。
/// 開発時はすべてのレベルを出す。
///
/// 構造化ログには [event] を使う:
/// ```dart
/// AppLogger.event('sync', 'push_orders', fields: {'count': 3, 'shop': 'a'});
/// // => [sync.push_orders] count=3 shop=a
/// ```
///
/// 規約:
///  - component: サブシステム名（'sync' / 'regi' / 'kitchen' / 'ble' / 'lan'）
///  - action: verb_noun（'push_orders' / 'accept_payment' / 'scan_devices'）
///  - fields: プリミティブ（String / num / bool）。複雑なオブジェクトは id か hash で。
class AppLogger {
  AppLogger._();

  static final Logger _instance = Logger(
    filter: _AppFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 100,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static Logger get instance => _instance;

  static void t(Object message) => _instance.t(message);
  static void d(Object message) => _instance.d(message);
  static void i(Object message) => _instance.i(message);
  static void w(Object message, {Object? error, StackTrace? stackTrace}) =>
      _instance.w(message, error: error, stackTrace: stackTrace);
  static void e(Object message, {Object? error, StackTrace? stackTrace}) =>
      _instance.e(message, error: error, stackTrace: stackTrace);

  /// 構造化ログを 1 行で出す。
  ///
  /// 戻り値は実際に出力した文字列（テストやテレメトリ転送向け）。
  static String event(
    String component,
    String action, {
    Map<String, Object?> fields = const <String, Object?>{},
    AppLogLevel level = AppLogLevel.info,
  }) {
    final String line = formatEvent(component, action, fields);
    switch (level) {
      case AppLogLevel.debug:
        _instance.d(line);
      case AppLogLevel.info:
        _instance.i(line);
      case AppLogLevel.warn:
        _instance.w(line);
      case AppLogLevel.error:
        _instance.e(line);
    }
    return line;
  }

  /// `event` の文字列化。テストおよび他のロガーレベルで再利用する純関数。
  ///
  /// 出力形式: `[component.action] k1=v1 k2=v2 ...`
  /// 値は: `null` → 省略、空白を含む文字列はクォート、それ以外は `toString`。
  /// キーは insertion order を維持する。
  static String formatEvent(
    String component,
    String action,
    Map<String, Object?> fields,
  ) {
    final StringBuffer buf = StringBuffer('[$component.$action]');
    for (final MapEntry<String, Object?> e in fields.entries) {
      if (e.value == null) continue;
      buf.write(' ');
      buf.write(e.key);
      buf.write('=');
      buf.write(_formatValue(e.value));
    }
    return buf.toString();
  }

  static String _formatValue(Object? v) {
    if (v == null) return '';
    if (v is num || v is bool) return v.toString();
    final String s = v.toString();
    if (s.contains(' ') || s.contains('=') || s.isEmpty) {
      return '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    }
    return s;
  }
}

class _AppFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    return event.level.index >= Level.debug.index;
  }
}
