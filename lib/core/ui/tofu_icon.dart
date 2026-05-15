import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Icon` (ComponentSet `30:56`) に対応するアイコン。
///
/// Figma 上の 26 種を [TofuIconName] で型安全に表現し、各々 Material Icons
/// から最近似のグリフへマップする。Figma の標準サイズは 24×24。
enum TofuIconName {
  plus,
  minus,
  check,
  x,
  chevronLeft,
  chevronRight,
  chevronDown,
  chevronUp,
  warning,
  info,
  refresh,
  trash,
  settings,
  user,
  shoppingBag,
  bell,
  wifi,
  bluetooth,
  clock,
  phone,
  home,
  list,
  search,
  cashRegister,
  pot,
  megaphone,
}

const Map<TofuIconName, IconData> _iconMap = <TofuIconName, IconData>{
  TofuIconName.plus: Icons.add_rounded,
  TofuIconName.minus: Icons.remove_rounded,
  TofuIconName.check: Icons.check_rounded,
  TofuIconName.x: Icons.close_rounded,
  TofuIconName.chevronLeft: Icons.chevron_left_rounded,
  TofuIconName.chevronRight: Icons.chevron_right_rounded,
  TofuIconName.chevronDown: Icons.keyboard_arrow_down_rounded,
  TofuIconName.chevronUp: Icons.keyboard_arrow_up_rounded,
  TofuIconName.warning: Icons.warning_amber_rounded,
  TofuIconName.info: Icons.info_outline_rounded,
  TofuIconName.refresh: Icons.refresh_rounded,
  TofuIconName.trash: Icons.delete_outline_rounded,
  TofuIconName.settings: Icons.settings_outlined,
  TofuIconName.user: Icons.person_outline_rounded,
  TofuIconName.shoppingBag: Icons.shopping_bag_outlined,
  TofuIconName.bell: Icons.notifications_outlined,
  TofuIconName.wifi: Icons.wifi_rounded,
  TofuIconName.bluetooth: Icons.bluetooth_rounded,
  TofuIconName.clock: Icons.schedule_rounded,
  TofuIconName.phone: Icons.phone_outlined,
  TofuIconName.home: Icons.home_outlined,
  TofuIconName.list: Icons.list_rounded,
  TofuIconName.search: Icons.search_rounded,
  TofuIconName.cashRegister: Icons.point_of_sale_outlined,
  TofuIconName.pot: Icons.soup_kitchen_outlined,
  TofuIconName.megaphone: Icons.campaign_outlined,
};

@immutable
class TofuIcon extends StatelessWidget {
  const TofuIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
  });

  final TofuIconName name;
  final double size;
  final Color? color;

  /// 名前 → Material Icons の素の [IconData] が必要なケース用。
  static IconData dataOf(TofuIconName name) => _iconMap[name]!;

  @override
  Widget build(BuildContext context) {
    return Icon(
      _iconMap[name],
      size: size,
      color: color ?? TofuTokens.textPrimary,
    );
  }
}
