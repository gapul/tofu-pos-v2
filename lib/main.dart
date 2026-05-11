import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/logging/app_logger.dart';
import 'core/telemetry/telemetry.dart';
import 'providers/database_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  Env.warnIfMissing(AppLogger.i);

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // Flutter の同期エラーを Telemetry にも流す。
  // configure 前は Noop なので、起動直後の例外も安全に飲み込まれる。
  final FlutterExceptionHandler? prevOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    Telemetry.instance.error(
      'flutter.error',
      message: details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    prevOnError?.call(details);
  };
  // 非同期領域の未捕捉例外。
  PlatformDispatcher.instance.onError = (error, stack) {
    Telemetry.instance.error('platform.error', error: error, stackTrace: stack);
    return false;
  };

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TofuPosApp(),
    ),
  );
}
