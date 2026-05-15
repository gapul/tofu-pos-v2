import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Molecules/Inputs/QuickAmountBtn` (id `36:26`) を Flutter で再現。
///
/// 1000 / 5000 / 10000 円等の「お預かり金額クイック投入」ボタン。
/// 高さは [TofuTokens.touchPrimary] = 72dp で誤タップを抑制。
@immutable
class QuickAmountBtn extends StatelessWidget {
  const QuickAmountBtn({
    required this.amount,
    required this.onPressed,
    super.key,
    this.label,
  });

  final int amount;
  final VoidCallback? onPressed;

  /// 表示テキストのオーバーライド。未指定なら `1,000円` 形式で整形。
  final String? label;

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
    final bool enabled = onPressed != null;
    final String text = label ?? _formatYen(amount);

    return Material(
      color: enabled ? TofuTokens.bgSurface : TofuTokens.bgMuted,
      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: TofuTokens.touchPrimary,
            minWidth: 96,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
            border: Border.all(
              color: enabled
                  ? TofuTokens.brandPrimaryBorder
                  : TofuTokens.borderSubtle,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TofuTextStyles.numberMd.copyWith(
              color: enabled
                  ? TofuTokens.brandPrimary
                  : TofuTokens.textDisabled,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}
