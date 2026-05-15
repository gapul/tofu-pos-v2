import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'num_stepper.dart';
import 'tofu_icon.dart';

/// Figma `Molecules/Cards/CartRow` (id `33:4`) を Flutter で再現。
///
/// 商品名 + 単価 + 数量 stepper + 小計 + 削除アイコンの 1 行構成。
@immutable
class CartRow extends StatelessWidget {
  const CartRow({
    required this.productName,
    required this.unitPriceText,
    required this.quantity,
    required this.onQuantityChanged,
    required this.subtotalText,
    super.key,
    this.note,
    this.onRemove,
    this.enabled = true,
  });

  final String productName;

  /// 単価表示 (整形済み)。例: '500円'.
  final String unitPriceText;

  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  /// 小計表示 (整形済み)。
  final String subtotalText;

  /// 備考 (オプション等)。
  final String? note;

  final VoidCallback? onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        enabled ? TofuTokens.textPrimary : TofuTokens.textDisabled;
    final Color sub =
        enabled ? TofuTokens.textTertiary : TofuTokens.textDisabled;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space4,
        vertical: TofuTokens.space3,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  productName,
                  style: TofuTextStyles.bodyMdBold.copyWith(color: fg),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  unitPriceText,
                  style: TofuTextStyles.bodySm.copyWith(color: sub),
                ),
                if (note != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    style: TofuTextStyles.caption.copyWith(color: sub),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: TofuTokens.space4),
          TofuNumStepper(
            value: quantity,
            onChanged: onQuantityChanged,
            enabled: enabled,
            size: TofuNumStepperSize.sm,
          ),
          const SizedBox(width: TofuTokens.space4),
          SizedBox(
            width: 80,
            child: Text(
              subtotalText,
              textAlign: TextAlign.right,
              style: TofuTextStyles.bodyMdBold.copyWith(color: fg),
            ),
          ),
          if (onRemove != null) ...<Widget>[
            const SizedBox(width: TofuTokens.space2),
            IconButton(
              tooltip: '削除',
              icon: const TofuIcon(
                TofuIconName.trash,
                size: 20,
                color: TofuTokens.dangerIcon,
              ),
              onPressed: enabled ? onRemove : null,
              constraints: const BoxConstraints(
                minWidth: TofuTokens.touchMin,
                minHeight: TofuTokens.touchMin,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
