import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Molecules/Display/AttributeChip` (id `370:116`) を Flutter で再現。
///
/// 顧客属性 (年代 / 性別 / 客層) をタップで複数選択するためのチップ。
/// `TofuChip` (atom) の薄ラッパだが、選択タイプによる色味を分離。
enum AttributeChipKind {
  /// 10代/20代/30代... 等の年代。
  age,

  /// 男性/女性/その他。
  gender,

  /// グループ/カップル/単独 等の客層分類。
  segment,
}

@immutable
class AttributeChip extends StatelessWidget {
  const AttributeChip({
    required this.label,
    required this.selected,
    super.key,
    this.kind = AttributeChipKind.age,
    this.onTap,
  });

  final String label;
  final bool selected;
  final AttributeChipKind kind;
  final VoidCallback? onTap;

  ({Color bg, Color border, Color fg}) _palette() {
    if (selected) {
      switch (kind) {
        case AttributeChipKind.age:
          return (
            bg: TofuTokens.brandPrimarySubtleStrong,
            border: TofuTokens.brandPrimary,
            fg: TofuTokens.brandPrimary,
          );
        case AttributeChipKind.gender:
          return (
            bg: TofuTokens.infoBg,
            border: TofuTokens.infoBorder,
            fg: TofuTokens.infoText,
          );
        case AttributeChipKind.segment:
          return (
            bg: TofuTokens.successBg,
            border: TofuTokens.successBorder,
            fg: TofuTokens.successText,
          );
      }
    }
    return (
      bg: TofuTokens.bgSurface,
      border: TofuTokens.borderDefault,
      fg: TofuTokens.textPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color border, Color fg}) p = _palette();
    final double borderW = selected
        ? TofuTokens.strokeThick
        : TofuTokens.strokeHairline;

    return Material(
      color: p.bg,
      borderRadius: BorderRadius.circular(TofuTokens.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusFull),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: TofuTokens.touchMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TofuTokens.radiusFull),
            border: Border.all(color: p.border, width: borderW),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TofuTextStyles.bodyMdBold.copyWith(color: p.fg),
            ),
          ),
        ),
      ),
    );
  }
}
