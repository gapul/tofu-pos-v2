import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/device_role.dart';
import '../../domain/enums/transport_mode.dart';
import '../../domain/value_objects/ticket_number.dart' as vo;
import '../../features/calling/presentation/notifiers/calling_providers.dart';
import '../../features/kitchen/presentation/notifiers/kitchen_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/role_router_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sync_providers.dart';
import '../../providers/usecase_providers.dart';
import '../sync/peer_presence.dart';
import '../sync/refresh_from_server.dart';
import '../theme/tokens.dart';
import 'status_indicator.dart';
import 'ticket_number.dart' as widget;
import 'top_snack.dart';

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
///  - 戻る / ブランド名領域
///
/// PR-1 (Figma 構造変更) 以降、[title] の意味は「ブランド/役割名」固定:
///   レジ / キッチン / 呼び出し / 設定 / 初期設定
/// 画面固有のタイトル (会計 / 顧客属性 / 商品選択 等) は body 冒頭の
/// `PageTitle` (`lib/core/ui/page_title.dart`) で描画する。
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.ticket,
    this.upcomingTicket,
    this.actions = const <Widget>[],
    this.showStatus = true,
    this.leading,
    this.onTicketTap,
  });

  /// ブランド/役割名。固定値 (「レジ」「キッチン」「呼び出し」「設定」「初期設定」)。
  /// 画面固有名はここに入れず、body 上部の `PageTitle` へ移譲する。
  final String title;

  /// サブ情報 (店舗ID + 管理者等)。Figma `HeaderBrand` Molecule のサブ行に相当。
  /// 未指定なら `settingsProvider` から自動で生成する。
  final String? subtitle;

  /// 確定済み注文の整理券番号 (あれば)。
  final vo.TicketNumber? ticket;

  /// 次回番号として表示する整理券番号 ([ticket] と同時には使わない想定)。
  final vo.TicketNumber? upcomingTicket;
  final List<Widget> actions;
  final bool showStatus;
  final Widget? leading;

  /// `ticket` / `upcomingTicket` バッジをタップしたときの動作。
  /// レジ端末で「次回番号」をタップ → 呼び出し画面プレビューを開く等で利用。
  final VoidCallback? onTicketTap;

  Widget _ticketBadge({required Widget child}) {
    if (onTicketTap == null) {
      return child;
    }
    return InkWell(
      onTap: onTicketTap,
      borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
      child: child,
    );
  }

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
      if (showStatus) _PeerPresenceBadge(),
      _RefreshButton(),
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
                child: _BrandBlock(
                  title: title,
                  subtitle: subtitle,
                  textStyle: TofuTextStyles.h3,
                ),
              ),
              if (ticket != null)
                _ticketBadge(
                  child: widget.TicketNumber(
                    number: ticket!.toString(),
                    label: '整理券',
                    size: widget.TicketNumberSize.sm,
                  ),
                )
              else if (upcomingTicket != null)
                _ticketBadge(
                  child: widget.TicketNumber(
                    number: upcomingTicket!.toString(),
                    label: '次回',
                    size: widget.TicketNumberSize.sm,
                    emphasized: false,
                  ),
                ),
              if (rightSide.isNotEmpty) ...<Widget>[
                const SizedBox(width: TofuTokens.space5),
                ..._interleave(
                  rightSide,
                  const SizedBox(width: TofuTokens.space3),
                ),
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
      if (showStatus) _PeerPresenceBadge(),
      _RefreshButton(),
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
                child: _BrandBlock(
                  title: title,
                  subtitle: subtitle,
                  textStyle: TofuTextStyles.h4,
                ),
              ),
              if (ticket != null)
                _ticketBadge(
                  child: widget.TicketNumber(
                    number: ticket!.toString(),
                    label: '整理券',
                    size: widget.TicketNumberSize.xs,
                  ),
                )
              else if (upcomingTicket != null)
                _ticketBadge(
                  child: widget.TicketNumber(
                    number: upcomingTicket!.toString(),
                    label: '次回',
                    size: widget.TicketNumberSize.xs,
                    emphasized: false,
                  ),
                ),
              if (rightSide.isNotEmpty) ...<Widget>[
                const SizedBox(width: TofuTokens.space3),
                ..._interleave(
                  rightSide,
                  const SizedBox(width: TofuTokens.space2),
                ),
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
      chips.add(
        StatusIndicator(
          type: StatusIndicatorType.syncError,
          dense: dense,
        ),
      );
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

/// ヘッダーに常設する「再読み込み」アイコン。
///
/// 押下動作:
///  1. SyncService.runOnce で未送信データを先に push
///  2. Transport / Realtime / RoleStarter を作り直す（再 backfill 含む）
///  3. 役割に応じて関連 provider を invalidate（UI 即時反映）
class _RefreshButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'サーバから再読み込み',
      icon: const Icon(Icons.refresh),
      onPressed: () => _refresh(context, ref),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    TopSnack.show(context, '再読み込み中…');
    // 1. 未送信データを先に push
    try {
      await ref.read(syncServiceProvider).runOnce();
    } catch (_) {
      // 失敗は telemetry に既に流れている。継続。
    }
    // 2. Transport / RoleStarter 再起動 + 役割別 backfill
    ref.invalidate(transportProvider);
    ref.invalidate(supabaseRealtimeListenerProvider);
    await ref.read(roleStarterProvider).start();
    // 3. 役割別の表示 provider を invalidate
    final DeviceRole? role = await ref
        .read(settingsRepositoryProvider)
        .getDeviceRole();
    switch (role) {
      case DeviceRole.kitchen:
        await RefreshFromServer.kitchen(ref);
        ref.invalidate(kitchenOrdersProvider);
      case DeviceRole.calling:
        await RefreshFromServer.calling(ref);
        ref.invalidate(callingOrdersProvider);
      case DeviceRole.register:
      case null:
        break;
    }
  }
}

/// 同一店舗内の接続中端末（役割別）をコンパクトに表示するバッジ。
///
/// レジ / キッチン / 呼び出し のアイコンを横並びで表示し、
/// presence で見えている役割は brandPrimary、未接続は textDisabled で表示する。
class _PeerPresenceBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PeerInfo>> peers = ref.watch(peersProvider);
    final List<PeerInfo> list = peers.value ?? const <PeerInfo>[];
    final Set<DeviceRole> active = list.map((p) => p.role).toSet();

    int countOf(DeviceRole r) => list.where((p) => p.role == r).length;

    final List<({DeviceRole role, IconData icon})> roles =
        <({DeviceRole role, IconData icon})>[
          (role: DeviceRole.register, icon: Icons.point_of_sale),
          (role: DeviceRole.kitchen, icon: Icons.restaurant),
          (role: DeviceRole.calling, icon: Icons.campaign),
        ];

    return Tooltip(
      message: list.isEmpty
          ? '接続中の端末はありません'
          : list
                .map(
                  (p) =>
                      '${p.role.label}: ${p.userName ?? p.deviceId.substring(0, p.deviceId.length.clamp(0, 6))}',
                )
                .join('\n'),
      child: InkWell(
        onTap: () => _showPeerSheet(context, list),
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space3,
            vertical: TofuTokens.space2,
          ),
          decoration: BoxDecoration(
            color: TofuTokens.bgSurface,
            borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
            border: Border.all(color: TofuTokens.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < roles.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: TofuTokens.space2),
                _RoleDot(
                  icon: roles[i].icon,
                  count: countOf(roles[i].role),
                  online: active.contains(roles[i].role),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPeerSheet(BuildContext context, List<PeerInfo> peers) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TofuTokens.space6,
              vertical: TofuTokens.space5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text('接続中の端末', style: TofuTextStyles.h4),
                const SizedBox(height: TofuTokens.space3),
                if (peers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: TofuTokens.space6,
                    ),
                    child: Text(
                      '接続中の端末はありません',
                      style: TofuTextStyles.bodyMd.copyWith(
                        color: TofuTokens.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...peers.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: TofuTokens.space2,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            switch (p.role) {
                              DeviceRole.register => Icons.point_of_sale,
                              DeviceRole.kitchen => Icons.restaurant,
                              DeviceRole.calling => Icons.campaign,
                            },
                            size: 18,
                            color: TofuTokens.brandPrimary,
                          ),
                          const SizedBox(width: TofuTokens.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  p.role.label,
                                  style: TofuTextStyles.bodyMdBold,
                                ),
                                Text(
                                  p.userName?.isNotEmpty == true
                                      ? p.userName!
                                      : 'ユーザー名未設定 (${p.deviceId.substring(0, p.deviceId.length.clamp(0, 6))})',
                                  style: TofuTextStyles.caption.copyWith(
                                    color: TofuTokens.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: TofuTokens.space3),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleDot extends StatelessWidget {
  const _RoleDot({
    required this.icon,
    required this.count,
    required this.online,
  });

  final IconData icon;
  final int count;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final Color color = online
        ? TofuTokens.brandPrimary
        : TofuTokens.textDisabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        if (count > 0) ...<Widget>[
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TofuTextStyles.captionBold.copyWith(color: color),
          ),
        ],
      ],
    );
  }
}

/// Figma `Molecules/HeaderBrand` 相当：役割名 + サブ情報（店舗ID等）を縦並びで表示。
class _BrandBlock extends StatelessWidget {
  const _BrandBlock({
    required this.title,
    required this.subtitle,
    required this.textStyle,
  });

  final String title;
  final String? subtitle;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TofuTextStyles.caption.copyWith(
              color: TofuTokens.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      ],
    );
  }
}
