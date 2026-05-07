import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// アプリ全体で共有するロガー。
///
/// 本番ビルド（kReleaseMode）では warning 以上のみ出力。
/// 開発時はすべてのレベルを出す。
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
