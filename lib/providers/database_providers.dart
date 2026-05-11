import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/datasources/local/database.dart';

/// アプリ全体で共有する単一の AppDatabase。
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  ref,
) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// SharedPreferences の非同期初期化。
///
/// `main()` で `await SharedPreferences.getInstance()` を済ませて
/// overrideWith する想定。直接 `await` させない。
final Provider<SharedPreferences>
sharedPreferencesProvider = Provider<SharedPreferences>((
  ref,
) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() with the resolved instance.',
  );
});
