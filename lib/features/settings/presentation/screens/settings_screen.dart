import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/export/csv_export_file_service.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/alert_banner.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/confirm_dialog.dart';
import '../../../../core/ui/pane_title.dart';
import '../../../../core/ui/settings_row.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../core/ui/tofu_icon.dart';
import '../../../../core/ui/tofu_toggle.dart';
import '../../../../core/ui/top_snack.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/device_role.dart';
import '../../../../domain/enums/transport_mode.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/role_router_providers.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../providers/sync_providers.dart';
import '../../../../providers/usecase_providers.dart';
import '../../../regi/presentation/notifiers/regi_providers.dart';
import '../../../startup/presentation/notifiers/setup_notifier.dart';

/// 設定画面（Figma `10-Register-Settings` / 仕様書 §4 / §6.4 / §7.1 / §8.3）。
///
/// landscape (1024×768) ベース。Figma 通りに 4 ブロックを縦に積む:
///   1. 設定ヘッダー (店舗ID / バージョン)
///   2. 通信モード + 端末役割切替 (PaneTitle + RadioGroup + RoleCard)
///   3. 機能フラグ (SettingsRow × 5)
///   4. データエクスポート / 管理操作 / 開発者ツール
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppHeader(
        title: '設定',
        showStatus: false,
        leading: IconButton(
          icon: const TofuIcon(TofuIconName.chevronLeft),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (c, constraints) {
            final bool wide = constraints.maxWidth >= 720;
            final Widget content = ListView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? TofuTokens.space8 : TofuTokens.space5,
                vertical: TofuTokens.space7,
              ),
              children: const <Widget>[
                _DeviceHeaderSection(),
                SizedBox(height: TofuTokens.space7),
                _UserNameSection(),
                SizedBox(height: TofuTokens.space7),
                _TransportSection(),
                SizedBox(height: TofuTokens.space7),
                _RoleSection(),
                SizedBox(height: TofuTokens.space7),
                _FeatureFlagsSection(),
                SizedBox(height: TofuTokens.space7),
                _ExportSection(),
                SizedBox(height: TofuTokens.space7),
                _LogoutSection(),
                // 開発者設定は debug ビルドでのみ表示。
                if (!kReleaseMode) ...<Widget>[
                  SizedBox(height: TofuTokens.space7),
                  _DeveloperSection(),
                ],
                SizedBox(height: TofuTokens.space11),
              ],
            );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 端末ヘッダー (Figma 80:86): 「設定」見出し + 店舗ID / バージョン サブテキスト。
// ---------------------------------------------------------------------------
class _DeviceHeaderSection extends ConsumerWidget {
  const _DeviceHeaderSection();

  Future<({String? shopId, DeviceRole? role})> _load(WidgetRef ref) async {
    final shopId = await ref.read(settingsRepositoryProvider).getShopId();
    final role = await ref.read(settingsRepositoryProvider).getDeviceRole();
    return (shopId: shopId?.value, role: role);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<({String? shopId, DeviceRole? role})>(
      future: _load(ref),
      builder: (c, s) {
        final ({String? shopId, DeviceRole? role}) data =
            s.data ?? (shopId: null, role: null);
        // Figma 80:86 — 「設定」h2 と 店舗ID / version を baseline で左右配置。
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            const Text('設定', style: TofuTextStyles.h2),
            const SizedBox(width: TofuTokens.space4),
            Expanded(
              child: Text(
                '店舗ID: ${data.shopId ?? '未設定'} / バージョン v1.0.0',
                style: TofuTextStyles.caption.copyWith(
                  color: TofuTokens.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ユーザー名: presence 経由で他端末から見える担当者名 (任意)。
// ---------------------------------------------------------------------------
class _UserNameSection extends ConsumerStatefulWidget {
  const _UserNameSection();

  @override
  ConsumerState<_UserNameSection> createState() => _UserNameSectionState();
}

class _UserNameSectionState extends ConsumerState<_UserNameSection> {
  final TextEditingController _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final String? name = await ref
        .read(settingsRepositoryProvider)
        .getUserName();
    if (!mounted) return;
    setState(() {
      _controller.text = name ?? '';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final String value = _controller.text.trim();
    await ref
        .read(settingsRepositoryProvider)
        .setUserName(
          value.isEmpty ? null : value,
        );
    // 反映のため presence を再接続。
    ref.invalidate(peerPresenceServiceProvider);
    if (!mounted) return;
    TopSnack.show(
      context,
      'ユーザー名を保存しました',
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(
            title: 'ユーザー名',
            subtitle: '任意。接続中の他端末から見える担当者名',
          ),
          const SizedBox(height: TofuTokens.space4),
          TextField(
            controller: _controller,
            enabled: _loaded,
            decoration: const InputDecoration(
              hintText: '例: 山田 (空欄可)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => unawaited(_save()),
          ),
          const SizedBox(height: TofuTokens.space3),
          Align(
            alignment: Alignment.centerRight,
            child: TofuButton(
              label: '保存',
              icon: Icons.save,
              onPressed: _loaded ? () => unawaited(_save()) : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 通信モード (Figma 223:76 + 223:79): PaneTitle + RadioGroup + 説明文。
// ---------------------------------------------------------------------------
class _TransportSection extends ConsumerWidget {
  const _TransportSection();

  Future<void> _switch(
    BuildContext context,
    WidgetRef ref,
    TransportMode target,
  ) async {
    final TransportMode current =
        ref.read(transportModeProvider).value ?? TransportMode.online;
    if (current == target) {
      return;
    }
    final bool ok = await TofuConfirmDialog.show(
      context,
      title: '通信モードを切り替えますか?',
      message:
          '${_label(current)} → ${_label(target)} に変更します。'
          '誤判定の自動切替は行わないため、必要に応じて手動で戻してください。',
      destructive: target != TransportMode.online,
      icon: Icons.swap_horiz,
    );
    if (!ok) {
      return;
    }
    await ref.read(settingsRepositoryProvider).setTransportMode(target);
  }

  static String _label(TransportMode m) => switch (m) {
    TransportMode.online => 'オンライン',
    TransportMode.localLan => 'ローカルLAN',
    TransportMode.bluetooth => 'Bluetooth',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransportMode mode =
        ref.watch(transportModeProvider).value ?? TransportMode.online;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(
            title: '通信モード',
            subtitle: 'オンライン障害時は手動で Bluetooth経路に切替',
          ),
          const SizedBox(height: TofuTokens.space4),
          RadioGroup<TransportMode>(
            groupValue: mode,
            onChanged: (v) {
              if (v != null) {
                unawaited(_switch(context, ref, v));
              }
            },
            child: Column(
              children: <Widget>[
                for (final TransportMode m in TransportMode.values)
                  RadioListTile<TransportMode>(
                    value: m,
                    title: Text(_label(m), style: TofuTextStyles.bodyMd),
                    secondary: Icon(switch (m) {
                      TransportMode.online => Icons.cloud,
                      TransportMode.localLan => Icons.lan,
                      TransportMode.bluetooth => Icons.bluetooth,
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: TofuTokens.space3),
          Align(
            alignment: Alignment.centerRight,
            child: TofuButton(
              label: 'サーバーに再接続',
              icon: Icons.refresh,
              variant: TofuButtonVariant.secondary,
              onPressed: () async {
                TopSnack.show(
                  context,
                  '未送信データをアップロード中…',
                  duration: const Duration(seconds: 4),
                );
                // 1. 先に未同期データをサーバへ push（再接続より優先）
                try {
                  await ref.read(syncServiceProvider).runOnce();
                } catch (_) {
                  // 失敗は telemetry に既に出ている。再接続は続行する。
                }
                // 2. Transport / Realtime / RoleStarter を作り直す
                ref.invalidate(transportProvider);
                ref.invalidate(supabaseRealtimeListenerProvider);
                await ref.read(roleStarterProvider).start();
                if (!context.mounted) return;
                TopSnack.show(
                  context,
                  'サーバーに再接続しました',
                  duration: const Duration(milliseconds: 1200),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 端末の役割 (Figma 359:223): 現在役割の表示 + 「役割を変更」ボタン。
// ---------------------------------------------------------------------------
class _RoleSection extends ConsumerWidget {
  const _RoleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DeviceRole?>(
      future: ref.read(settingsRepositoryProvider).getDeviceRole(),
      builder: (c, snap) {
        final DeviceRole? role = snap.data;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const PaneTitle(title: '端末の役割'),
              const SizedBox(height: TofuTokens.space4),
              Container(
                padding: const EdgeInsets.all(TofuTokens.space5),
                decoration: BoxDecoration(
                  color: TofuTokens.bgSurface,
                  borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
                  border: Border.all(color: TofuTokens.borderSubtle),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '現在の役割: ${role?.label ?? '未設定'}',
                            style: TofuTextStyles.bodyLgBold,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '別の役割（キッチン・呼び出し）に切り替えます',
                            style: TofuTextStyles.bodySm.copyWith(
                              color: TofuTokens.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TofuTokens.space4),
                    TofuButton(
                      label: '役割を変更',
                      icon: Icons.swap_horiz,
                      variant: TofuButtonVariant.secondary,
                      onPressed: () async {
                        await ref
                            .read(setupNotifierProvider.notifier)
                            .clearRole();
                        if (!context.mounted) return;
                        context.go('/setup/role');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 機能フラグ (Figma 80:89 + 80:92): PaneTitle + 説明文 + SettingsRow × 5。
// ---------------------------------------------------------------------------
class _FeatureFlagsSection extends ConsumerWidget {
  const _FeatureFlagsSection();

  Future<void> _toggle(
    WidgetRef ref,
    FeatureFlags Function(FeatureFlags) update,
  ) async {
    final FeatureFlags current =
        ref.read(featureFlagsProvider).value ?? FeatureFlags.allOff;
    await ref.read(settingsRepositoryProvider).setFeatureFlags(update(current));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FeatureFlags flags =
        ref.watch(featureFlagsProvider).value ?? FeatureFlags.allOff;

    final List<
      ({String title, String subtitle, bool value, void Function(bool) on})
    >
    rows =
        <({String title, String subtitle, bool value, void Function(bool) on})>[
          (
            title: '在庫管理',
            subtitle: '商品ごとの在庫数を管理。在庫切れ商品は注文画面で選択不可になります。',
            value: flags.stockManagement,
            on: (v) =>
                unawaited(_toggle(ref, (f) => f.copyWith(stockManagement: v))),
          ),
          (
            title: '金種管理',
            subtitle: 'レジ内の金種別枚数（理論値）を管理し、レジ締め時に実測値と照合できます。',
            value: flags.cashManagement,
            on: (v) =>
                unawaited(_toggle(ref, (f) => f.copyWith(cashManagement: v))),
          ),
          (
            title: '顧客属性入力',
            subtitle: '会計前に顧客の年代・性別・客層を記録します。売上分析に利用されます。',
            value: flags.customerAttributes,
            on: (v) => unawaited(
              _toggle(ref, (f) => f.copyWith(customerAttributes: v)),
            ),
          ),
          (
            title: 'キッチン連携',
            subtitle: '確定した注文をキッチン端末へ自動送信し、提供完了通知を受け取ります。',
            value: flags.kitchenLink,
            on: (v) =>
                unawaited(_toggle(ref, (f) => f.copyWith(kitchenLink: v))),
          ),
          (
            title: '呼び出し連携',
            subtitle: '呼び出し端末を表示用ディスプレイとして連携し、整理券番号を表示します。',
            value: flags.callingLink,
            on: (v) =>
                unawaited(_toggle(ref, (f) => f.copyWith(callingLink: v))),
          ),
        ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(
            title: '機能フラグ',
            subtitle: '店舗の運用形態に合わせて機能をオン/オフできます',
          ),
          const SizedBox(height: TofuTokens.space4),
          for (final r in rows)
            SettingsRow(
              title: r.title,
              subtitle: r.subtitle,
              showChevron: false,
              trailing: TofuToggle(value: r.value, onChanged: r.on),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// データエクスポート: PaneTitle + 説明文 + CSV ボタン。
// ---------------------------------------------------------------------------
class _ExportSection extends ConsumerStatefulWidget {
  const _ExportSection();

  @override
  ConsumerState<_ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends ConsumerState<_ExportSection> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final List<Order> orders = await ref
          .read(orderRepositoryProvider)
          .findAll();
      final shopId =
          (await ref.read(settingsRepositoryProvider).getShopId())?.value ??
          'unknown_shop';
      final String path = await CsvExportFileService().writeAndShare(
        orders: orders,
        shopId: shopId,
      );
      if (!mounted) {
        return;
      }
      TopSnack.show(context, 'CSV を共有しました ($path)');
    } catch (e) {
      if (!mounted) {
        return;
      }
      TopSnack.show(context, 'エクスポートに失敗: $e', color: TofuTokens.dangerBgStrong);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(
            title: 'データエクスポート',
            subtitle: 'クラウド同期のバックアップ・端末故障時の救出手段',
          ),
          const SizedBox(height: TofuTokens.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: TofuButton(
              label: 'CSVを書き出す',
              icon: Icons.file_download,
              variant: TofuButtonVariant.secondary,
              loading: _busy,
              onPressed: _busy ? null : _export,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ログアウト: 店舗ID をクリアして /setup/shop へ戻る。
// ローカル DB (注文履歴 / 金種 / 整理券プール / 設定) は保持。
// ---------------------------------------------------------------------------
class _LogoutSection extends ConsumerWidget {
  const _LogoutSection();

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final bool ok = await TofuConfirmDialog.show(
      context,
      title: 'ログアウトしますか?',
      message:
          'ログアウトすると初期設定画面に戻ります。'
          'ローカルのデータ（注文履歴・金種・設定）は保持されます。',
      confirmLabel: 'ログアウト',
      icon: Icons.logout,
    );
    if (!ok) {
      return;
    }
    // 未送信注文が残っているとログアウト後の同期トリガが無くなるので
    // ログアウト前に push を試みる。失敗は telemetry に既に出ているので無視。
    if (context.mounted) {
      TopSnack.show(
        context,
        '未送信データをアップロード中…',
        duration: const Duration(seconds: 2),
      );
    }
    try {
      await ref.read(syncServiceProvider).runOnce();
    } catch (_) {
      /* 失敗してもログアウトは続行 */
    }
    await ref.read(setupNotifierProvider.notifier).clearShop();
    if (!context.mounted) return;
    context.go('/setup/shop');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(
            title: 'ログアウト',
            subtitle: '店舗ID をリセットし初期設定画面に戻ります',
          ),
          const SizedBox(height: TofuTokens.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: TofuButton(
              label: 'ログアウト（店舗 ID をリセット）',
              icon: Icons.logout,
              variant: TofuButtonVariant.secondary,
              onPressed: () => _logout(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 開発者設定 (debug only): 整理券プール初期化 + DevConsole を ExpansionTile に
// まとめ、リリースビルドでは丸ごと非表示（呼び出し側で kReleaseMode で抑制）。
// ---------------------------------------------------------------------------
class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile のデフォルト分割線を消す。
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: const ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: TofuTokens.space6,
            vertical: TofuTokens.space2,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            TofuTokens.space5,
            0,
            TofuTokens.space5,
            TofuTokens.space5,
          ),
          title: PaneTitle(
            title: '開発者設定',
            subtitle: '実機検証・不可逆な管理操作 / 本番運用では使用しません',
          ),
          children: <Widget>[
            _DangerSection(),
            SizedBox(height: TofuTokens.space5),
            _DevToolsSection(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 管理操作: 不可逆操作 warning + 整理券プール初期化。
// ---------------------------------------------------------------------------
class _DangerSection extends ConsumerStatefulWidget {
  const _DangerSection();

  @override
  ConsumerState<_DangerSection> createState() => _DangerSectionState();
}

class _DangerSectionState extends ConsumerState<_DangerSection> {
  Future<void> _resetTicketPool() async {
    final bool ok = await TofuConfirmDialog.show(
      context,
      title: '整理券プールを初期化しますか?',
      message:
          'すべての使用中・バッファ中の番号を破棄し、1から振り直します。'
          '営業中はお客様に渡した番号と重複しないようご注意ください。',
      confirmLabel: '初期化する',
      destructive: true,
      icon: Icons.restart_alt,
    );
    if (!ok) {
      return;
    }
    final repo = ref.read(ticketNumberPoolRepositoryProvider);
    final pool = await repo.load();
    await repo.save(pool.reset());
    ref.invalidate(ticketPoolProvider);
    if (!mounted) {
      return;
    }
    TopSnack.show(
      context,
      '整理券プールを初期化しました',
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      accent: TofuTokens.dangerText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(title: '管理操作', accent: TofuTokens.dangerText),
          const SizedBox(height: TofuTokens.space4),
          const AlertBanner(
            variant: AlertBannerVariant.warning,
            title: '不可逆操作です',
            message: '実行前に内容をよく確認してください。',
          ),
          const SizedBox(height: TofuTokens.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: TofuButton(
              label: '整理券プールを初期化',
              icon: Icons.restart_alt,
              variant: TofuButtonVariant.danger,
              onPressed: _resetTicketPool,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 開発者ツール: DevConsole 起動。
// ---------------------------------------------------------------------------
class _DevToolsSection extends StatelessWidget {
  const _DevToolsSection();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(
            title: '開発者ツール',
            subtitle: '実機検証用 / 本番運用では使用しません',
          ),
          const SizedBox(height: TofuTokens.space4),
          const StatusIndicator.custom(
            label: '自動シナリオテスト・通信モード詳細・直接DB書き換え等',
            icon: Icons.info_outline,
            tone: StatusIndicatorTone.info,
          ),
          const SizedBox(height: TofuTokens.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: TofuButton(
              label: 'DevConsole を開く',
              icon: Icons.code,
              variant: TofuButtonVariant.secondary,
              onPressed: () => context.push('/dev'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 共通カード。bgCanvas + borderSubtle で subtle に区切る。
// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  const _Card({required this.child, this.accent});
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space6),
      decoration: BoxDecoration(
        color: TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(
          color: accent ?? TofuTokens.borderSubtle,
          width: accent != null
              ? TofuTokens.strokeThick
              : TofuTokens.strokeHairline,
        ),
      ),
      child: child,
    );
  }
}
