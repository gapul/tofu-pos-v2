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

/// 任意ラベル用のトーン。Figma `StatusIndicator` の color tokens に対応。
/// 旧 `TofuStatusTone` (status_chip) の置換先。
enum StatusIndicatorTone { info, success, warning, danger, neutral }

@immutable
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    required this.type,
    super.key,
    this.labelOverride,
    this.dense = false,
  }) : _customLabel = null,
       _customIcon = null,
       _customTone = null;

  /// 任意ラベル/アイコン/トーンで描画する派生。旧 `StatusChip` の代替。
  /// `type` フィールドは未使用だが、`enum` の非 nullable 制約上ダミー値を入れる。
  const StatusIndicator.custom({
    required String label,
    required StatusIndicatorTone tone,
    super.key,
    IconData? icon,
    this.dense = false,
  }) : type = StatusIndicatorType.online,
       labelOverride = null,
       _customLabel = label,
       _customIcon = icon,
       _customTone = tone;

  final StatusIndicatorType type;

  /// 既定ラベルを上書き。
  final String? labelOverride;

  /// `caption` 程度の小型表示。
  final bool dense;

  final String? _customLabel;
  final IconData? _customIcon;
  final StatusIndicatorTone? _customTone;

  ({Color bg, Color border, Color fg, IconData? icon, String label})
  _customSpec() {
    final StatusIndicatorTone t = _customTone!;
    switch (t) {
      case StatusIndicatorTone.info:
        return (
          bg: TofuTokens.infoBg,
          border: TofuTokens.infoBorder,
          fg: TofuTokens.infoText,
          icon: _customIcon,
          label: _customLabel!,
        );
      case StatusIndicatorTone.success:
        return (
          bg: TofuTokens.successBg,
          border: TofuTokens.successBorder,
          fg: TofuTokens.successText,
          icon: _customIcon,
          label: _customLabel!,
        );
      case StatusIndicatorTone.warning:
        return (
          bg: TofuTokens.warningBg,
          border: TofuTokens.warningBorder,
          fg: TofuTokens.warningText,
          icon: _customIcon,
          label: _customLabel!,
        );
      case StatusIndicatorTone.danger:
        return (
          bg: TofuTokens.dangerBg,
          border: TofuTokens.dangerBorder,
          fg: TofuTokens.dangerText,
          icon: _customIcon,
          label: _customLabel!,
        );
      case StatusIndicatorTone.neutral:
        return (
          bg: TofuTokens.bgSurface,
          border: TofuTokens.borderSubtle,
          fg: TofuTokens.textSecondary,
          icon: _customIcon,
          label: _customLabel!,
        );
    }
  }

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
    final bool isCustom = _customTone != null;

    final Color bg;
    final Color border;
    final Color fg;
    final String labelText;
    final Widget? iconWidget;

    if (isCustom) {
      final ({
        Color bg,
        Color border,
        Color fg,
        IconData? icon,
        String label,
      })
      c = _customSpec();
      bg = c.bg;
      border = c.border;
      fg = c.fg;
      labelText = c.label;
      iconWidget = c.icon == null
          ? null
          : Icon(c.icon, size: dense ? 14 : 16, color: fg);
    } else {
      final ({
        Color bg,
        Color border,
        Color fg,
        TofuIconName icon,
        String label,
      })
      s = _spec();
      bg = s.bg;
      border = s.border;
      fg = s.fg;
      labelText = labelOverride ?? s.label;
      iconWidget = TofuIcon(s.icon, size: dense ? 14 : 16, color: fg);
    }

    final TextStyle textStyle =
        (dense ? TofuTextStyles.caption : TofuTextStyles.bodySmBold).copyWith(
          color: fg,
        );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? TofuTokens.space3 : TofuTokens.space4,
        vertical: dense ? TofuTokens.space2 : TofuTokens.space3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (iconWidget != null) ...<Widget>[
            iconWidget,
            const SizedBox(width: TofuTokens.space2),
          ],
          Text(labelText, style: textStyle),
        ],
      ),
    );
  }
}
