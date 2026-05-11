import 'package:flutter/material.dart';

import '../../domain/value_objects/ticket_number.dart';
import '../theme/tokens.dart';

/// 整理券番号のバッジ表示（仕様書 §9.1）。
///
/// レジ機能の各画面の上部固定領域に常時表示することで、対応中の注文番号を
/// 画面遷移をまたいでも見失わないようにする。「次回番号」は薄く表示して
/// 確定済み番号と差別化する。
class TicketBadge extends StatelessWidget {
  const TicketBadge({
    required this.ticket,
    super.key,
    this.label = '整理券',
    this.upcoming = false,
    this.size = TicketBadgeSize.regular,
  });

  /// 「次回番号」表示用ヘルパー。
  const TicketBadge.upcoming({
    required this.ticket,
    super.key,
    this.size = TicketBadgeSize.regular,
  }) : label = '次回番号',
       upcoming = true;

  final TicketNumber? ticket;
  final String label;
  final bool upcoming;
  final TicketBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final TextStyle numberStyle = switch (size) {
      TicketBadgeSize.compact => TofuTextStyles.h2,
      TicketBadgeSize.regular => TofuTextStyles.h1,
      TicketBadgeSize.large => TofuTextStyles.numberLg.copyWith(fontSize: 56),
      TicketBadgeSize.display => TofuTextStyles.numberDisplay,
    };

    final EdgeInsets padding = switch (size) {
      TicketBadgeSize.compact => const EdgeInsets.symmetric(
        horizontal: TofuTokens.space4,
        vertical: TofuTokens.space3,
      ),
      TicketBadgeSize.regular => const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space4,
      ),
      TicketBadgeSize.large => const EdgeInsets.symmetric(
        horizontal: TofuTokens.space7,
        vertical: TofuTokens.space5,
      ),
      TicketBadgeSize.display => const EdgeInsets.all(TofuTokens.space11),
    };

    final Color bgColor = upcoming
        ? TofuTokens.brandPrimarySubtle
        : TofuTokens.brandPrimary;
    final Color fgColor = upcoming
        ? TofuTokens.brandPrimary
        : TofuTokens.brandOnPrimary;
    final Color labelColor = upcoming
        ? TofuTokens.textTertiary
        : TofuTokens.brandOnPrimary;

    final String numberText = ticket?.toString() ?? '--';

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: upcoming
            ? Border.all(color: TofuTokens.brandPrimaryBorder)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (upcoming) ...<Widget>[
            Icon(Icons.schedule, size: 18, color: labelColor),
            const SizedBox(width: TofuTokens.space2),
          ] else ...<Widget>[
            Icon(Icons.confirmation_number, size: 18, color: labelColor),
            const SizedBox(width: TofuTokens.space2),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TofuTextStyles.captionBold.copyWith(color: labelColor),
              ),
              const SizedBox(height: 2),
              Text(numberText, style: numberStyle.copyWith(color: fgColor)),
            ],
          ),
        ],
      ),
    );
  }
}

enum TicketBadgeSize { compact, regular, large, display }
