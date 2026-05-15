import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/transport_mode.dart';
import '../../domain/value_objects/ticket_number.dart' as vo;
import '../../providers/settings_providers.dart';
import '../../providers/sync_providers.dart';
import '../theme/tokens.dart';
import 'status_indicator.dart';
import 'ticket_number.dart' as widget;

/// Figma `Organisms/AppHeader` (id `433:29`) を Flutter で再現。
///
/// variant:
///  - `size=landscape` (id 405:6, 1024×89)
///  - `size=portrait`  (id 433:17, 375×81)
///
/// `MediaQuery.of(context).orientation` で自動的に切替える。
///
/// レジ向け共通ヘッダー (仕様書 §9.1):
///  - 整理券番号の常時表示
///  - 同期状態 / 通信モードの StatusIndicator バッジ
///  - 戻る / タイトル領域
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

  /// 確定済み注文の整理券番号 (あれば)。
  final vo.TicketNumber? ticket;

  /// 次回番号として表示する整理券番号 ([ticket] と同時には使わない想定)。
  final vo.TicketNumber? upcomingTicket;
  final List<Widget> actions;
  final bool showStatus;
  final Widget? leading;

  /// Figma: landscape 89dp / portrait 81dp。
  /// `preferredSize` は build フェーズ前に Scaffold から呼ばれるため
  /// `MediaQuery` を参照できず、両 orientation で同一値を返さざるを得ない。
  /// 大きい方の 89 を採用し、portrait 時の 8dp 余剰は許容する。
  @override
  Size get preferredSize => const Size.fromHeight(89);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Orientation orientation = MediaQuery.of(context).orientation;
    return orientation == Orientation.landscape
        ? _buildLandscape(context, ref)
        : _buildPortrait(context, ref);
  }

  // ---------------------------------------------------------------------------
  // size=landscape (Figma 405:6, 1024×89)
  // ---------------------------------------------------------------------------
  Widget _buildLandscape(BuildContext context, WidgetRef ref) {
    final AsyncValue<TransportMode> mode = ref.watch(transportModeProvider);
    final AsyncValue<SyncWarningLevel> warn = ref.watch(syncWarningProvider);

    final List<Widget> rightSide = <Widget>[
      if (showStatus) ..._statusIndicators(mode, warn),
      ...actions,
    ];

    return Material(
      color: TofuTokens.bgCanvas,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 89,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: TofuTokens.borderSubtle)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space6,
            vertical: TofuTokens.space4,
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
                      style: TofuTextStyles.h3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (ticket != null)
                widget.TicketNumber(
                  number: ticket!.toString(),
                  label: '整理券',
                  size: widget.TicketNumberSize.sm,
                )
              else if (upcomingTicket != null)
                widget.TicketNumber(
                  number: upcomingTicket!.toString(),
                  label: '次回',
                  size: widget.TicketNumberSize.sm,
                  emphasized: false,
                ),
              if (rightSide.isNotEmpty) ...<Widget>[
                const SizedBox(width: TofuTokens.space5),
                ..._interleave(rightSide, const SizedBox(width: TofuTokens.space3)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // size=portrait (Figma 433:17, 375×81)
  // ---------------------------------------------------------------------------
  Widget _buildPortrait(BuildContext context, WidgetRef ref) {
    final AsyncValue<TransportMode> mode = ref.watch(transportModeProvider);
    final AsyncValue<SyncWarningLevel> warn = ref.watch(syncWarningProvider);

    final List<Widget> rightSide = <Widget>[
      if (showStatus) ..._statusIndicators(mode, warn),
      ...actions,
    ];

    return Material(
      color: TofuTokens.bgCanvas,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 81,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: TofuTokens.borderSubtle)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space4,
            vertical: TofuTokens.space3,
          ),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: TofuTokens.space3),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TofuTextStyles.h4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (ticket != null)
                widget.TicketNumber(
                  number: ticket!.toString(),
                  label: '整理券',
                  size: widget.TicketNumberSize.xs,
                )
              else if (upcomingTicket != null)
                widget.TicketNumber(
                  number: upcomingTicket!.toString(),
                  label: '次回',
                  size: widget.TicketNumberSize.xs,
                  emphasized: false,
                ),
              if (rightSide.isNotEmpty) ...<Widget>[
                const SizedBox(width: TofuTokens.space3),
                ..._interleave(rightSide, const SizedBox(width: TofuTokens.space2)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // StatusIndicator (Figma `Molecules/Display/StatusIndicator`) で
  // 通信モード / 同期エラーを表示する。
  // ---------------------------------------------------------------------------
  List<Widget> _statusIndicators(
    AsyncValue<TransportMode> mode,
    AsyncValue<SyncWarningLevel> warn, {
    bool dense = true,
  }) {
    final TransportMode? m = mode.value;
    final List<Widget> chips = <Widget>[];

    if (m != null) {
      chips.add(_modeIndicator(m, dense: dense));
    }
    if (warn.value == SyncWarningLevel.prolongedFailure) {
      chips.add(StatusIndicator(
        type: StatusIndicatorType.syncError,
        dense: dense,
      ));
    }
    return chips;
  }

  StatusIndicator _modeIndicator(TransportMode m, {required bool dense}) {
    return switch (m) {
      TransportMode.online => StatusIndicator(
          type: StatusIndicatorType.online,
          dense: dense,
        ),
      TransportMode.localLan => StatusIndicator.custom(
          label: 'LAN',
          tone: StatusIndicatorTone.info,
          icon: Icons.lan,
          dense: dense,
        ),
      TransportMode.bluetooth => StatusIndicator(
          type: StatusIndicatorType.bluetooth,
          dense: dense,
        ),
    };
  }

  /// 子要素間に区切りの widget を挿入。
  List<Widget> _interleave(List<Widget> items, Widget separator) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) out.add(separator);
      out.add(items[i]);
    }
    return out;
  }
}
