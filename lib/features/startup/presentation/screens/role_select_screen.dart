import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../core/ui/top_snack.dart';
import '../../../../domain/enums/device_role.dart';
import '../notifiers/setup_notifier.dart';

/// 役割選択画面（Figma `02-Setup-Role` / 仕様書 §3.2）。
///
/// landscape (1024×768):
/// - タイトル「役割を選択」(H2 / center) + サブタイトル「この端末の役割を
///   選んでください。後から変更できます。」(bodySm / center)
/// - 役割カード 3 枚を横並び (HORIZONTAL, spacing 24, padding 20, radius 16)。
///   - 各カード内は縦並び: Icon (40px) → 上部小余白 → ラベル (H3) →
///     description (caption) → 選択時のみチェックアイコン。
///   - 選択中: bg = brandPrimarySubtle (#EDF2F6), border = brandPrimary (2px)
///   - 非選択: bg = bgSurface, border = borderDefault (1px)
/// - 末尾に「← 戻る」(secondary) と「決定」(primary) の 2 ボタン行。
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
      description: '注文の調理状況を管理・報告',
    ),
    (
      role: DeviceRole.calling,
      icon: Icons.campaign,
      description: '整理券番号を顧客向けに表示',
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
      TopSnack.show(context, '保存に失敗しました。もう一度お試しください。',
          color: TofuTokens.dangerBgStrong);
      return;
    }
    if (!mounted) {
      return;
    }
    context.go('/');
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/setup/shop-id');
    }
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
                ? const EdgeInsets.fromLTRB(
                    TofuTokens.space12, // 80
                    TofuTokens.space11, // 64
                    TofuTokens.space12,
                    TofuTokens.space10, // 48
                  )
                : const EdgeInsets.fromLTRB(
                    TofuTokens.space7, // 24
                    TofuTokens.space11, // 64
                    TofuTokens.space7,
                    TofuTokens.space8, // 32
                  );

            return SingleChildScrollView(
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
                    const SizedBox(height: TofuTokens.space4), // 12
                    Text(
                      'この端末の役割を選んでください。後から変更できます。',
                      style: TofuTextStyles.bodySm.copyWith(
                        color: TofuTokens.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: TofuTokens.space8), // 32
                    // 役割カード群: landscape は横並び、portrait は縦並び
                    if (isWide)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                          for (int i = 0; i < _options.length; i++) ...<Widget>[
                            if (i > 0)
                              const SizedBox(width: TofuTokens.space7), // 24
                            Expanded(
                              child: _RoleCard(
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
                            ),
                          ],
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (int i = 0; i < _options.length; i++) ...<Widget>[
                            if (i > 0)
                              const SizedBox(height: TofuTokens.space4),
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
                        ],
                      ),
                    const SizedBox(height: TofuTokens.space8), // 32
                    // 「← 戻る」/「決定」の 2 ボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        TofuButton(
                          label: '戻る',
                          icon: Icons.arrow_back,
                          variant: TofuButtonVariant.secondary,
                          size: TofuButtonSize.lg,
                          onPressed: _saving ? null : _back,
                        ),
                        const SizedBox(width: TofuTokens.space5), // 16
                        SizedBox(
                          width: 280,
                          child: TofuButton(
                            label: '決定',
                            icon: Icons.check,
                            size: TofuButtonSize.lg,
                            fullWidth: true,
                            loading: _saving,
                            onPressed: (_selected == null || _saving)
                                ? null
                                : _submit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 役割カード（Figma `02-Setup-Role` の 3 枚）。
///
/// VERTICAL, padding 20, radius 16, gap 12。
/// - 選択中: bg=brandPrimarySubtle, border=brandPrimary (2px), 末尾にチェック
/// - 非選択: bg=bgSurface, border=borderDefault (1px)
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
    final Color border = selected
        ? TofuTokens.brandPrimary
        : TofuTokens.borderDefault;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(TofuTokens.radiusXl), // 16
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusXl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space6, // 20
            vertical: TofuTokens.space8, // 32
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: border,
              width: selected
                  ? TofuTokens.strokeThick
                  : TofuTokens.strokeHairline,
            ),
            borderRadius: BorderRadius.circular(TofuTokens.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48, color: TofuTokens.brandPrimary),
              const SizedBox(height: TofuTokens.space5), // 16
              Text(role.label, style: TofuTextStyles.h3),
              const SizedBox(height: TofuTokens.space3), // 8
              Text(
                description,
                style: TofuTextStyles.caption.copyWith(
                  color: TofuTokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TofuTokens.space5),
              // 選択時のみチェックアイコンを下端に表示
              SizedBox(
                height: 32,
                child: selected
                    ? Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: TofuTokens.brandPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: TofuTokens.textInverse,
                          size: 20,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
