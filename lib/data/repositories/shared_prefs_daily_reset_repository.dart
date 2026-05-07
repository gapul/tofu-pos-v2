import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/daily_reset_repository.dart';

class SharedPrefsDailyResetRepository implements DailyResetRepository {
  SharedPrefsDailyResetRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String _kLastResetDate = 'lastResetDate';

  @override
  Future<DateTime?> getLastResetDate() async {
    final String? raw = _prefs.getString(_kLastResetDate);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> setLastResetDate(DateTime date) async {
    final DateTime dayOnly = DateTime(date.year, date.month, date.day);
    await _prefs.setString(_kLastResetDate, dayOnly.toIso8601String());
  }
}
