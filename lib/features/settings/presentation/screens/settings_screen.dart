import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/export/csv_export_file_service.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/confirm_dialog.dart';
import '../../../../core/ui/status_chip.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/device_role.dart';
import '../../../../domain/enums/transport_mode.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/settings_providers.dart';
import '../../../regi/presentation/notifiers/regi_providers.dart';

/// 設定画面（仕様書 §4 / §6.4 / §7.1 / §8.3）。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppBar(
        title: const Text('設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(TofuTokens.space5),
              children: const <Widget>[
                _DeviceSection(),
                SizedBox(height: TofuTokens.space7),
                _FeatureFlagsSection(),
                SizedBox(height: TofuTokens.space7),
                _TransportSection(),
                SizedBox(height: TofuTokens.space7),
                _ExportSection(),
                SizedBox(height: TofuTokens.space7),
                _DangerSection(),
                SizedBox(height: TofuTokens.space7),
                _DevToolsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        color: TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: TofuTokens.space4),
            child: Text(title, style: TofuTextStyles.h4),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _DeviceSection extends ConsumerWidget {
  const _DeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<({String? shopId, DeviceRole? role})>(
      future: _load(ref),
      builder:
          (
            c,
            s,
          ) {
            final ({String? shopId, DeviceRole? role}) data =
                s.data ?? (shopId: null, role: null);
            return _Card(
              title: '端末',
              children: <Widget>[
                _Row(
                  icon: Icons.storefront,
                  label: '店舗ID',
                  value: data.shopId ?? '未設定',
                ),
                _Row(
                  icon: Icons.devices,
                  label: '役割',
                  value: data.role?.label ?? '未設定',
                ),
                const SizedBox(height: TofuTokens.space3),
                TofuButton(
                  label: '初期設定をやり直す',
                  icon: Icons.refresh,
                  variant: TofuButtonVariant.outlined,
                  onPressed: () => context.push('/setup/shop'),
                ),
              ],
            );
          },
    );
  }

  Future<({String? shopId, DeviceRole? role})> _load(WidgetRef ref) async {
    final shopId = await ref.read(settingsRepositoryProvider).getShopId();
    final role = await ref.read(settingsRepositoryProvider).getDeviceRole();
    return (shopId: shopId?.value, role: role);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TofuTokens.space3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: TofuTokens.textTertiary),
          const SizedBox(width: TofuTokens.space3),
          Text(label, style: TofuTextStyles.bodyMd),
          const Spacer(),
          Text(value, style: TofuTextStyles.bodyMdBold),
        ],
      ),
    );
  }
}

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

    return _Card(
      title: '機能フラグ',
      children: <Widget>[
        SwitchListTile(
          title: const Text('在庫管理', style: TofuTextStyles.bodyMd),
          subtitle: const Text(
            '商品ごとの在庫数を管理し、在庫切れ商品を選択不可にします。',
            style: TofuTextStyles.bodySm,
          ),
          value: flags.stockManagement,
          onChanged: (v) =>
              _toggle(ref, (f) => f.copyWith(stockManagement: v)),
        ),
        SwitchListTile(
          title: const Text('金種管理', style: TofuTextStyles.bodyMd),
          subtitle: const Text(
            'レジ内の金種別枚数を管理し、レジ締めで実測値と照合できます。',
            style: TofuTextStyles.bodySm,
          ),
          value: flags.cashManagement,
          onChanged: (v) =>
              _toggle(ref, (f) => f.copyWith(cashManagement: v)),
        ),
        SwitchListTile(
          title: const Text('顧客属性入力', style: TofuTextStyles.bodyMd),
          subtitle: const Text(
            '会計前に年代・性別・客層を選択して売上分析に利用します。',
            style: TofuTextStyles.bodySm,
          ),
          value: flags.customerAttributes,
          onChanged: (v) => _toggle(
            ref,
            (f) => f.copyWith(customerAttributes: v),
          ),
        ),
        SwitchListTile(
          title: const Text('キッチン連携', style: TofuTextStyles.bodyMd),
          subtitle: const Text(
            '注文をキッチン端末へ送信し、提供完了通知を受信します。',
            style: TofuTextStyles.bodySm,
          ),
          value: flags.kitchenLink,
          onChanged: (v) =>
              _toggle(ref, (f) => f.copyWith(kitchenLink: v)),
        ),
        SwitchListTile(
          title: const Text('呼び出し連携', style: TofuTextStyles.bodyMd),
          subtitle: const Text(
            '呼び出し端末を表示用ディスプレイとして連携させます。',
            style: TofuTextStyles.bodySm,
          ),
          value: flags.callingLink,
          onChanged: (v) =>
              _toggle(ref, (f) => f.copyWith(callingLink: v)),
        ),
      ],
    );
  }
}

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
      title: '通信モード',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: TofuTokens.space3),
          child: Text(
            '通常はオンライン経由。回線障害が顕在化した場合のみ手動でフォールバックします。',
            style: TofuTextStyles.bodySm.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
        ),
        RadioGroup<TransportMode>(
          groupValue: mode,
          onChanged: (v) {
            if (v != null) {
              _switch(context, ref, v);
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
      ],
    );
  }
}

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV を共有しました ($path)')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エクスポートに失敗: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'データエクスポート',
      children: <Widget>[
        Text(
          'クラウド同期のバックアップ／端末故障時の救出手段として、ローカルデータをCSVで書き出します。',
          style: TofuTextStyles.bodySm.copyWith(color: TofuTokens.textTertiary),
        ),
        const SizedBox(height: TofuTokens.space4),
        TofuButton(
          label: 'CSVを書き出す',
          icon: Icons.file_download,
          variant: TofuButtonVariant.outlined,
          loading: _busy,
          onPressed: _busy ? null : _export,
        ),
      ],
    );
  }
}

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('整理券プールを初期化しました')));
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: '管理操作',
      children: <Widget>[
        const StatusChip(
          label: '不可逆操作です。実行前に内容をよく確認してください。',
          icon: Icons.warning_amber,
          tone: TofuStatusTone.warning,
        ),
        const SizedBox(height: TofuTokens.space4),
        TofuButton(
          label: '整理券プールを初期化',
          icon: Icons.restart_alt,
          variant: TofuButtonVariant.danger,
          onPressed: _resetTicketPool,
        ),
      ],
    );
  }
}

class _DevToolsSection extends StatelessWidget {
  const _DevToolsSection();

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: '開発者ツール',
      children: <Widget>[
        Text(
          '実機検証用。自動シナリオテスト・通信モード詳細・テレメトリ確認・'
          '直接DB書き換え等が含まれます。本番運用では使用しません。',
          style: TofuTextStyles.bodySm.copyWith(
            color: TofuTokens.textTertiary,
          ),
        ),
        const SizedBox(height: TofuTokens.space4),
        TofuButton(
          label: 'DevConsole を開く',
          icon: Icons.code,
          variant: TofuButtonVariant.outlined,
          onPressed: () => context.push('/dev'),
        ),
      ],
    );
  }
}
