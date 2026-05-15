import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'num_stepper.dart';

/// Figma `Molecules/Inputs/MoneyDenomRow` (id `33:8`) を Flutter で再現。
///
/// 金種名 (例: 「10000円」) + 枚数 stepper + 小計表示を 1 行に並べる。
/// 主に `cash_close_screen` の金種別カウント入力で利用。
@immutable
class MoneyDenomRow extends StatelessWidget {
  const MoneyDenomRow({
    required this.denomLabel,
    required this.count,
    required this.onCountChanged,
    super.key,
    this.unitValue,
    this.subtotalText,
    this.enabled = true,
    this.max = 9999,
  });

  /// 金種名。例: '10000円', '500円玉'。
  final String denomLabel;

  /// 1 枚あたりの金額 (subtotalText 自動算出用)。null なら表示しない。
  final int? unitValue;

  /// 現在の枚数。
  final int count;
  final ValueChanged<int> onCountChanged;

  /// 小計表示のオーバーライド。指定無しなら `count * unitValue` を整形。
  final String? subtotalText;

  final bool enabled;
  final int max;

  String _formatYen(int v) {
    final String s = v.toString();
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        b.write(',');
      }
      b.write(s[i]);
    }
    return '$b円';
  }

  @override
  Widget build(BuildContext context) {
    final String? subtotal =
        subtotalText ??
        (unitValue == null ? null : _formatYen(unitValue! * count));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space4,
        vertical: TofuTokens.space3,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              denomLabel,
              style: TofuTextStyles.bodyMdBold.copyWith(
                color: enabled
                    ? TofuTokens.textPrimary
                    : TofuTokens.textDisabled,
              ),
            ),
          ),
          TofuNumStepper(
            value: count,
            onChanged: onCountChanged,
            max: max,
            enabled: enabled,
          ),
          if (subtotal != null) ...<Widget>[
            const SizedBox(width: TofuTokens.space4),
            Expanded(
              flex: 2,
              child: Text(
                subtotal,
                textAlign: TextAlign.right,
                style: TofuTextStyles.numberMd.copyWith(
                  color: enabled
                      ? TofuTokens.textPrimary
                      : TofuTokens.textDisabled,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
