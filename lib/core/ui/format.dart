import '../../domain/value_objects/money.dart';

/// 共通フォーマッタ。
class TofuFormat {
  const TofuFormat._();

  /// 円を「1,234円」形式で表示（仕様書/Figma準拠：単位は数値の右）。
  static String yen(Money money) => '${_thousands(money.yen)}円';

  /// 円を「1,234円」形式で表示（int）。
  static String yenInt(int value) => '${_thousands(value)}円';

  /// 数値に3桁区切りカンマを入れる。
  static String _thousands(int value) {
    final bool isNegative = value < 0;
    final String digits = value.abs().toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i != 0 && (digits.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(digits[i]);
    }
    return isNegative ? '-$buf' : buf.toString();
  }

  /// 「23:59」形式の時刻。
  static String hhmm(DateTime t) {
    final String h = t.hour.toString().padLeft(2, '0');
    final String m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 「03/05 14:23」形式の日時。
  static String mmddhhmm(DateTime t) {
    final String mo = t.month.toString().padLeft(2, '0');
    final String d = t.day.toString().padLeft(2, '0');
    return '$mo/$d ${hhmm(t)}';
  }

  /// 経過時間を「3分前」「1時間前」のような相対表記に。
  static String relativeFromNow(DateTime t, {DateTime? now}) {
    final DateTime n = now ?? DateTime.now();
    final Duration d = n.difference(t);
    if (d.inSeconds < 60) {
      return 'たった今';
    }
    if (d.inMinutes < 60) {
      return '${d.inMinutes}分前';
    }
    if (d.inHours < 24) {
      return '${d.inHours}時間前';
    }
    return mmddhhmm(t);
  }
}
