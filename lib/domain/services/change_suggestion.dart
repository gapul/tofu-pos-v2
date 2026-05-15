import 'package:meta/meta.dart';

import '../value_objects/denomination.dart';

/// お釣りの最適な金種組合せを提案する（仕様書 §6.3 / §9.3）。
///
/// 金種管理が ON のとき、お釣り金額と引き出しの在庫枚数から
/// 「最少枚数」のお釣り組合せを greedy に算出する。
///
/// `compute` の引数:
/// - changeYen: お釣り金額（円）。負値・0 のときは空 Map を返す。
/// - stock: 各金種の利用可能枚数 (`{1000: 5, 100: 12, ...}`)。
///   未指定金種は 0 枚扱い。null を渡すと「無制限」（理論計算）。
///
/// 戻り値は `{金種: 渡す枚数}` の Map。在庫不足で全額を作れない場合は
/// 「作れる範囲で最大限」返す（呼び出し側が `coverable` を確認すること）。
@immutable
class ChangeSuggestion {
  const ChangeSuggestion({
    required this.bills,
    required this.coverable,
    required this.shortageYen,
  });

  /// 金種ごとの渡す枚数（0 のものは含まない）。降順整列。
  final Map<int, int> bills;

  /// お釣り全額を作れたかどうか。`false` の場合 [shortageYen] が残額。
  final bool coverable;

  /// 不足額（円）。`coverable=true` のとき 0。
  final int shortageYen;

  /// 合計枚数。
  int get totalCount {
    int sum = 0;
    for (final int c in bills.values) {
      sum += c;
    }
    return sum;
  }

  static ChangeSuggestion compute({
    required int changeYen,
    Map<int, int>? stock,
  }) {
    if (changeYen <= 0) {
      return const ChangeSuggestion(
        bills: <int, int>{},
        coverable: true,
        shortageYen: 0,
      );
    }
    int remaining = changeYen;
    final Map<int, int> out = <int, int>{};
    // 大きい金種から greedy に消費
    final List<int> denoms = Denomination.all.map((d) => d.yen).toList()
      ..sort((a, b) => b.compareTo(a)); // 降順
    for (final int yen in denoms) {
      if (remaining < yen) continue;
      final int? avail = stock?[yen];
      final int wantCount = remaining ~/ yen;
      final int useCount = avail == null
          ? wantCount
          : (avail < wantCount ? avail : wantCount);
      if (useCount > 0) {
        out[yen] = useCount;
        remaining -= useCount * yen;
      }
    }
    return ChangeSuggestion(
      bills: out,
      coverable: remaining == 0,
      shortageYen: remaining,
    );
  }
}
