import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/enums/device_role.dart';
import '../notifiers/setup_notifier.dart';

/// 役割選択画面（Figma `02-Setup-Role` / 仕様書 §3.2）。
///
/// レイアウト軸 (portrait, 375×812):
/// - 縦方向 VERTICAL, padding 64/24/32/24, itemSpacing 24, counterAxis CENTER。
/// - タイトル「役割を選択」(H2 / center) + サブタイトル「この端末の役割を選んでください」(bodySm / center)
/// - 役割カード 3 枚（HORIZONTAL, padding 20, radius 16, spacing 16）
///   - 選択中: bg = brandPrimarySubtle (#EDF2F6), border = brandPrimary
///   - 非選択: bg = bgSurface, border = brandPrimary (Figma の Theme 藍)
/// - 末尾に主要ボタン「決定」。
///
/// landscape (1024×768) は padding 80 で余白だけ拡大する。
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
      description: '注文受付・会計・整理券発行',
    ),
    (
      role: DeviceRole.kitchen,
      icon: Icons.restaurant,
      description: '調理対象表示・提供完了報告',
    ),
    (
      role: DeviceRole.calling,
      icon: Icons.campaign,
      description: '整理券番号の表示',
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 720;
            final EdgeInsets pad = isWide
                ? const EdgeInsets.all(TofuTokens.space12) // 80
                : const EdgeInsets.fromLTRB(
                    TofuTokens.space7, // 24
                    TofuTokens.space11, // 64
                    TofuTokens.space7,
                    TofuTokens.space8, // 32
                  );

            // Figma: portrait itemSpacing=24, landscape itemSpacing=48
            final double sectionGap = isWide
                ? TofuTokens.space10 // 48
                : TofuTokens.space7; // 24

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: pad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          '役割を選択',
                          style: TofuTextStyles.h2,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: sectionGap),
                        Text(
                          'この端末の役割を選んでください',
                          style: TofuTextStyles.bodySm.copyWith(
                            color: TofuTokens.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: sectionGap),
                        // 役割カード群 (vertical, spacing 12)
                        for (int i = 0; i < _options.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(height: TofuTokens.space4),
                          _RoleCard(
                            role: _options[i].role,
                            icon: _options[i].icon,
                            description: _options[i].description,
                            selected: _selected == _options[i].role,
                            onTap: _saving
                                ? null
                                : () => setState(
                                    () => _selected = _options[i].role,
                                  ),
                          ),
                        ],
                        SizedBox(height: sectionGap),
                        TofuButton(
                          label: '決定',
                          icon: Icons.check,
                          size: TofuButtonSize.lg,
                          fullWidth: true,
                          loading: _saving,
                          onPressed: (_selected == null || _saving)
                              ? null
                              : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 役割カード（Figma `85:9` / `85:16` / `85:21`）。
///
/// HORIZONTAL, padding 20, spacing 16, radius 16。
/// 選択時は bgSurface を primarySubtle、border を brandPrimary に切り替え。
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected
        ? TofuTokens.brandPrimarySubtle
        : TofuTokens.bgSurface;
    const Color border = TofuTokens.brandPrimary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(TofuTokens.radiusXl), // 16
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusXl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(TofuTokens.space6), // 20
          decoration: BoxDecoration(
            border: Border.all(
              color: border,
              width: selected
                  ? TofuTokens.strokeThick
                  : TofuTokens.strokeHairline,
            ),
            borderRadius: BorderRadius.circular(TofuTokens.radiusXl),
          ),
          child: Row(
            children: <Widget>[
              // Icon 48×48
              SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  icon,
                  size: 40,
                  color: TofuTokens.brandPrimary,
                ),
              ),
              const SizedBox(width: TofuTokens.space5), // 16
              // ラベル + 説明 (vertical, spacing 2)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(role.label, style: TofuTextStyles.h4),
                    const SizedBox(height: TofuTokens.space1), // 2
                    Text(
                      description,
                      style: TofuTextStyles.caption.copyWith(
                        color: TofuTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TofuTokens.space5),
              // ラジオインジケータ 32×32
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? TofuTokens.brandPrimary
                    : TofuTokens.textTertiary,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
