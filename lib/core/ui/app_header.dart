import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/transport_mode.dart';
import '../../domain/value_objects/ticket_number.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sync_providers.dart';
import '../theme/tokens.dart';
import 'status_chip.dart';
import 'ticket_badge.dart';

/// レジ向け共通ヘッダー（仕様書 §9.1）。
///
/// - 整理券番号の常時表示
/// - 同期状態 / 通信モードのバッジ表示
/// - 戻る・タイトル領域
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({
    required this.title,
    super.key,
    this.ticket,
    this.upcomingTicket,
    this.actions = const <Widget>[],
    this.showStatus = true,
    this.leading,
  });

  final String title;

  /// 確定済み注文の整理券番号（あれば）。
  final TicketNumber? ticket;

  /// 次回番号として表示する整理券番号（[ticket] と同時には使わない想定）。
  final TicketNumber? upcomingTicket;
  final List<Widget> actions;
  final bool showStatus;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TransportMode> mode = ref.watch(transportModeProvider);
    final AsyncValue<SyncWarningLevel> warn = ref.watch(syncWarningProvider);

    final List<Widget> rightSide = <Widget>[
      if (showStatus) ...<Widget>[
        ..._buildStatusChips(mode, warn),
        const SizedBox(width: TofuTokens.space5),
      ],
      ...actions,
    ];

    return Material(
      color: TofuTokens.bgCanvas,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 76,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: TofuTokens.borderSubtle)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space3,
          ),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: TofuTokens.space4),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TofuTextStyles.h4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (ticket != null)
                TicketBadge(ticket: ticket, size: TicketBadgeSize.compact)
              else if (upcomingTicket != null)
                TicketBadge.upcoming(
                  ticket: upcomingTicket,
                  size: TicketBadgeSize.compact,
                ),
              if (rightSide.isNotEmpty) ...<Widget>[
                const SizedBox(width: TofuTokens.space5),
                ...rightSide,
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStatusChips(
    AsyncValue<TransportMode> mode,
    AsyncValue<SyncWarningLevel> warn,
  ) {
    final TransportMode? m = mode.value;
    final List<Widget> chips = <Widget>[];

    if (m != null) {
      chips.add(_modeChip(m));
    }
    if (warn.value == SyncWarningLevel.prolongedFailure) {
      chips.add(const SizedBox(width: TofuTokens.space2));
      chips.add(
        const StatusChip(
          label: '同期エラー',
          icon: Icons.cloud_off,
          tone: TofuStatusTone.danger,
          dense: true,
        ),
      );
    }
    return chips;
  }

  StatusChip _modeChip(TransportMode m) {
    return switch (m) {
      TransportMode.online => const StatusChip(
        label: 'オンライン',
        icon: Icons.cloud_done,
        tone: TofuStatusTone.success,
        dense: true,
      ),
      TransportMode.localLan => const StatusChip(
        label: 'LAN',
        icon: Icons.lan,
        tone: TofuStatusTone.info,
        dense: true,
      ),
      TransportMode.bluetooth => const StatusChip(
        label: 'Bluetooth',
        icon: Icons.bluetooth_connected,
        tone: TofuStatusTone.warning,
        dense: true,
      ),
    };
  }
}
