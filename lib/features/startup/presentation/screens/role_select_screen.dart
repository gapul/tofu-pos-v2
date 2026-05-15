import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/enums/device_role.dart';
import '../notifiers/setup_notifier.dart';

/// 役割選択画面（仕様書 §3.2）。
class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  DeviceRole? _selected;
  bool _saving = false;

  static const List<({DeviceRole role, IconData icon, String description})>
  _options = <({DeviceRole role, IconData icon, String description})>[
    (
      role: DeviceRole.register,
      icon: Icons.point_of_sale,
      description: '顧客対応・会計・整理券発行を担当する。1店舗1台の運用前提。',
    ),
    (
      role: DeviceRole.kitchen,
      icon: Icons.restaurant,
      description: '調理対象の注文表示と「提供完了」操作を担当。',
    ),
    (
      role: DeviceRole.calling,
      icon: Icons.campaign,
      description: '受け渡し窓口で整理券番号を表示する独立した呼び出し器。',
    ),
  ];

  Future<void> _submit() async {
    if (_selected == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(setupNotifierProvider.notifier).saveRole(_selected!);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存に失敗しました。もう一度お試しください。'),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final SetupState? s = ref.watch(setupNotifierProvider).value;
    _selected ??= s?.role;

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/setup/shop'),
          tooltip: '戻る',
        ),
        title: const Text('役割を選択'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(TofuTokens.space7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text('この端末の役割', style: TofuTextStyles.h2),
                  const SizedBox(height: TofuTokens.space3),
                  Text(
                    '選んだ役割は端末内に保存され、再起動時に復元されます。'
                    '後から設定画面で変更できます。',
                    style: TofuTextStyles.bodyMd.copyWith(
                      color: TofuTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _options.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: TofuTokens.space4),
                      itemBuilder: (c, i) {
                        final ({
                          DeviceRole role,
                          IconData icon,
                          String description,
                        })
                        opt = _options[i];
                        return _RoleCard(
                          role: opt.role,
                          icon: opt.icon,
                          description: opt.description,
                          selected: _selected == opt.role,
                          onTap: () => setState(() => _selected = opt.role),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space5),
                  TofuButton(
                    label: 'はじめる',
                    icon: Icons.check_circle,
                    size: TofuButtonSize.lg,
                    fullWidth: true,
                    loading: _saving,
                    onPressed: (_selected == null || _saving) ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final DeviceRole role;
  final IconData icon;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TofuTokens.brandPrimarySubtle : TofuTokens.bgCanvas,
      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(TofuTokens.space6),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? TofuTokens.brandPrimary
                  : TofuTokens.borderSubtle,
              width: selected ? 2 : TofuTokens.strokeHairline,
            ),
            borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: selected
                      ? TofuTokens.brandPrimary
                      : TofuTokens.bgSurface,
                  borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: selected
                      ? TofuTokens.brandOnPrimary
                      : TofuTokens.brandPrimary,
                ),
              ),
              const SizedBox(width: TofuTokens.space5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(role.label, style: TofuTextStyles.h3),
                    const SizedBox(height: TofuTokens.space2),
                    Text(
                      description,
                      style: TofuTextStyles.bodyMd.copyWith(
                        color: TofuTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TofuTokens.space5),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? TofuTokens.brandPrimary
                    : TofuTokens.textTertiary,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
