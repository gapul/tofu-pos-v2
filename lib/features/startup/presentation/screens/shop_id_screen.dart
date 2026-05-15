import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../core/ui/tofu_input.dart';
import '../../../../domain/value_objects/shop_id.dart';
import '../notifiers/setup_notifier.dart';

/// 店舗ID入力画面（Figma `01-Setup-StoreId` / 仕様書 §3.1）。
///
/// レイアウト軸 (portrait, 375×812):
/// - 縦中央・水平中央。padding 80/24/48/24、itemSpacing 24。
/// - タイトル「店舗IDを入力」(H2 / w600 / center)
/// - サブタイトル「同店舗の端末群を識別する文字列を\n入力してください」
/// - フォーム (vertical, spacing 12): caption ラベル + 入力 + helper + 主要ボタン
/// - 末尾に DevConsole 入口（実機検証用、Figma 範囲外）
///
/// landscape (1024×768) では padding が 96/80 に拡大するため、画面幅で
/// レスポンシブに余白を切り替える。
class ShopIdScreen extends ConsumerStatefulWidget {
  const ShopIdScreen({super.key});

  @override
  ConsumerState<ShopIdScreen> createState() => _ShopIdScreenState();
}

class _ShopIdScreenState extends ConsumerState<ShopIdScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final SetupState? s = ref.read(setupNotifierProvider).value;
    if (s?.shopId != null) {
      _controller.text = s!.shopId!.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '店舗IDを入力してください');
      return;
    }
    if (text.length > 64) {
      setState(() => _error = '64文字以内で入力してください');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(setupNotifierProvider.notifier).saveShopId(ShopId(text));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存に失敗しました。もう一度お試しください。';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    context.go('/setup/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Figma: portrait → H 80/24/48/24, landscape → 96/80/96/80
            final bool isWide = constraints.maxWidth >= 720;
            final EdgeInsets pad = isWide
                ? const EdgeInsets.fromLTRB(
                    TofuTokens.space12, // 80
                    TofuTokens.space13, // 96
                    TofuTokens.space12,
                    TofuTokens.space13,
                  )
                : const EdgeInsets.fromLTRB(
                    TofuTokens.space7, // 24
                    TofuTokens.space12, // 80
                    TofuTokens.space7,
                    TofuTokens.space10, // 48
                  );

            // Figma: portrait itemSpacing=24, landscape itemSpacing=32
            final double sectionGap = isWide
                ? TofuTokens.space8 // 32
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
                        // タイトル
                        const Text(
                          '店舗IDを入力',
                          style: TofuTextStyles.h2,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: sectionGap),
                        // サブタイトル
                        Text(
                          '同店舗の端末群を識別する文字列を\n入力してください',
                          style: TofuTextStyles.bodySm.copyWith(
                            color: TofuTokens.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: sectionGap),
                        // フォーム frame: ラベル + 入力 + helper + ボタン
                        _StoreIdForm(
                          controller: _controller,
                          errorText: _error,
                          saving: _saving,
                          onSubmit: _submit,
                        ),
                        const SizedBox(height: TofuTokens.space5),
                        // DevConsole 入口（Figma 外、実機検証用）
                        Center(
                          child: TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => context.push('/dev'),
                            icon: const Icon(Icons.code, size: 18),
                            label: const Text('DevConsole を開く（テスト）'),
                          ),
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

/// 店舗ID 入力フォーム本体（Figma `84:10`）。
class _StoreIdForm extends StatelessWidget {
  const _StoreIdForm({
    required this.controller,
    required this.errorText,
    required this.saving,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ラベル「店舗ID」(caption)
        const Text('店舗ID', style: TofuTextStyles.caption),
        const SizedBox(height: TofuTokens.space4),
        // 入力
        TofuInput(
          controller: controller,
          size: TofuInputSize.lg,
          hintText: 'yakisoba_A',
          autofocus: true,
          enabled: !saving,
          errorText: errorText,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: TofuTokens.space4),
        // helper
        const Text(
          '同じ店舗のすべての端末で同じ文字列を入力',
          style: TofuTextStyles.caption,
        ),
        const SizedBox(height: TofuTokens.space7),
        // 主要ボタン「次へ →」
        TofuButton(
          label: '次へ',
          icon: Icons.arrow_forward,
          size: TofuButtonSize.lg,
          fullWidth: true,
          loading: saving,
          onPressed: saving ? null : onSubmit,
        ),
      ],
    );
  }
}
