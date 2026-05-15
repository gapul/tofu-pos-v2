import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/daily_reset_repository.dart';

class SharedPrefsDailyResetRepository implements DailyResetRepository {
  SharedPrefsDailyResetRepository(
    this._prefs, {
    String? Function()? currentShopId,
  }) : _currentShopId = currentShopId;

  final SharedPreferences _prefs;
  final String? Function()? _currentShopId;

  // 旧キー（プレフィクスなし）。後方互換のためのフォールバック先。
  static const String _kLegacyLastResetDate = 'lastResetDate';

  String _key() {
    final String? sid = _currentShopId?.call();
    if (sid == null || sid.isEmpty) return _kLegacyLastResetDate;
    return 'lastResetDate:$sid';
  }

  @override
  Future<DateTime?> getLastResetDate() async {
    final String? raw = _prefs.getString(_key());
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> setLastResetDate(DateTime date) async {
    final DateTime dayOnly = DateTime(date.year, date.month, date.day);
    await _prefs.setString(_key(), dayOnly.toIso8601String());
  }
}
