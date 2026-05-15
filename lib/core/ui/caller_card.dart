import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_badge.dart';
import 'tofu_button.dart';

/// Figma `Molecules/Cards/CallerCard` (id `37:50`) を Flutter で再現。
///
/// 整理券呼び出し用カード。
/// - `state=waiting`: 控えめな表示 (bgSurface + 中間枠)。
/// - `state=called`: 強調表示 (brandPrimarySubtleStrong + 太枠)。
enum CallerCardState { waiting, called }

@immutable
class CallerCard extends StatelessWidget {
  const CallerCard({
    required this.ticketLabel,
    required this.state,
    super.key,
    this.headline,
    this.elapsedText,
    this.onCall,
    this.onComplete,
    this.onCancel,
  });

  /// 整理券番号 (例: '042')。
  final String ticketLabel;
  final CallerCardState state;

  /// 補助見出し (例: '中盛 × 1 ほか'). 省略可。
  final String? headline;

  /// 経過時間表示。例: '3分待ち'.
  final String? elapsedText;

  final VoidCallback? onCall;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final bool called = state == CallerCardState.called;
    final Color bg =
        called ? TofuTokens.brandPrimarySubtleStrong : TofuTokens.bgSurface;
    final Color border =
        called ? TofuTokens.brandPrimary : TofuTokens.borderSubtle;
    final double borderWidth =
        called ? TofuTokens.strokeThick : TofuTokens.strokeHairline;

    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: called ? TofuTokens.elevationSm : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                ticketLabel,
                style: TofuTextStyles.numberLg.copyWith(
                  color: TofuTokens.brandPrimary,
                ),
              ),
              const SizedBox(width: TofuTokens.space4),
              if (called)
                const TofuBadge(
                  label: '呼出中',
                  variant: TofuBadgeVariant.brand,
                )
              else
                const TofuBadge(label: '待機中'),
              const Spacer(),
              if (elapsedText != null)
                Text(
                  elapsedText!,
                  style: TofuTextStyles.bodySm.copyWith(
                    color: TofuTokens.textTertiary,
                  ),
                ),
            ],
          ),
          if (headline != null) ...<Widget>[
            const SizedBox(height: TofuTokens.space3),
            Text(
              headline!,
              style: TofuTextStyles.bodyMd,
            ),
          ],
          if (onCall != null || onComplete != null || onCancel != null) ...<
              Widget>[
            const SizedBox(height: TofuTokens.space4),
            Row(
              children: <Widget>[
                if (onCancel != null) ...<Widget>[
                  TofuButton(
                    label: 'キャンセル',
                    variant: TofuButtonVariant.ghost,
                    onPressed: onCancel,
                  ),
                  const SizedBox(width: TofuTokens.adjacentSpacing),
                ],
                const Spacer(),
                if (called && onComplete != null)
                  TofuButton(
                    label: '受渡完了',
                    size: TofuButtonSize.lg,
                    onPressed: onComplete,
                  )
                else if (!called && onCall != null)
                  TofuButton(
                    label: '呼び出し',
                    size: TofuButtonSize.lg,
                    onPressed: onCall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
