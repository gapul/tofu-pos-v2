import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_icon.dart';

/// Figma `Molecules/Display/StatusIndicator` (id `36:22`) を Flutter で再現。
///
/// POS の通信ステータスを「色 + アイコン + 文字列」の 3 重表現で示す。
/// 仕様書 §12.1 の "色覚多様性配慮" を満たすために色だけに依存しない。
enum StatusIndicatorType {
  online,
  offline,
  bluetooth,
  syncing,
  synced,
  syncError,
}

@immutable
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    required this.type,
    super.key,
    this.labelOverride,
    this.dense = false,
  });

  final StatusIndicatorType type;

  /// 既定ラベルを上書き。
  final String? labelOverride;

  /// `caption` 程度の小型表示。
  final bool dense;

  ({Color bg, Color border, Color fg, TofuIconName icon, String label})
      _spec() {
    switch (type) {
      case StatusIndicatorType.online:
        return (
          bg: TofuTokens.successBg,
          border: TofuTokens.successBorder,
          fg: TofuTokens.successText,
          icon: TofuIconName.wifi,
          label: 'オンライン',
        );
      case StatusIndicatorType.offline:
        return (
          bg: TofuTokens.warningBg,
          border: TofuTokens.warningBorder,
          fg: TofuTokens.warningText,
          icon: TofuIconName.wifi,
          label: 'オフライン',
        );
      case StatusIndicatorType.bluetooth:
        return (
          bg: TofuTokens.infoBg,
          border: TofuTokens.infoBorder,
          fg: TofuTokens.infoText,
          icon: TofuIconName.bluetooth,
          label: 'Bluetooth',
        );
      case StatusIndicatorType.syncing:
        return (
          bg: TofuTokens.infoBg,
          border: TofuTokens.infoBorder,
          fg: TofuTokens.infoText,
          icon: TofuIconName.refresh,
          label: '同期中',
        );
      case StatusIndicatorType.synced:
        return (
          bg: TofuTokens.successBg,
          border: TofuTokens.successBorder,
          fg: TofuTokens.successText,
          icon: TofuIconName.check,
          label: '同期済',
        );
      case StatusIndicatorType.syncError:
        return (
          bg: TofuTokens.dangerBg,
          border: TofuTokens.dangerBorder,
          fg: TofuTokens.dangerText,
          icon: TofuIconName.warning,
          label: '同期エラー',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({
      Color bg,
      Color border,
      Color fg,
      TofuIconName icon,
      String label,
    }) s = _spec();
    final String labelText = labelOverride ?? s.label;
    final TextStyle textStyle =
        (dense ? TofuTextStyles.caption : TofuTextStyles.bodySmBold)
            .copyWith(color: s.fg);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? TofuTokens.space3 : TofuTokens.space4,
        vertical: dense ? TofuTokens.space2 : TofuTokens.space3,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        border: Border.all(color: s.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TofuIcon(s.icon, size: dense ? 14 : 16, color: s.fg),
          const SizedBox(width: TofuTokens.space2),
          Text(labelText, style: textStyle),
        ],
      ),
    );
  }
}
