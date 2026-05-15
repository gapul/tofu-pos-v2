import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Divider` (ComponentSet `27:9`) を Flutter で再現。
///
/// 1px の borderSubtle ライン。
/// - horizontal: 親の幅一杯 / 高さ 1px
/// - vertical  : 親の高さ一杯 / 幅 1px
enum TofuDividerOrientation { horizontal, vertical }

@immutable
class TofuDivider extends StatelessWidget {
  const TofuDivider({
    super.key,
    this.orientation = TofuDividerOrientation.horizontal,
  });

  final TofuDividerOrientation orientation;

  @override
  Widget build(BuildContext context) {
    return switch (orientation) {
      TofuDividerOrientation.horizontal => const SizedBox(
        height: TofuTokens.strokeHairline,
        child: ColoredBox(color: TofuTokens.borderSubtle),
      ),
      TofuDividerOrientation.vertical => const SizedBox(
        width: TofuTokens.strokeHairline,
        child: ColoredBox(color: TofuTokens.borderSubtle),
      ),
    };
  }
}
