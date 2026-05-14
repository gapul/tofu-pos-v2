import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/value_objects/shop_id.dart';
import '../notifiers/setup_notifier.dart';

/// 店舗ID入力画面（仕様書 §3.1）。
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(TofuTokens.space7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SetupStepIndicator(current: 1, total: 2),
                  const SizedBox(height: TofuTokens.space7),
                  const Text('店舗IDを入力', style: TofuTextStyles.h2),
                  const SizedBox(height: TofuTokens.space4),
                  Text(
                    '同じ店舗の端末をひとつのグループとして識別するための任意の文字列です。\n'
                    '例: yakisoba_A',
                    style: TofuTextStyles.bodyMd.copyWith(
                      color: TofuTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TofuTextStyles.h3,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: '店舗ID',
                      hintText: 'yakisoba_A',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.storefront),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  TofuButton(
                    label: '次へ',
                    icon: Icons.arrow_forward,
                    size: TofuButtonSize.primary,
                    fullWidth: true,
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                  const SizedBox(height: TofuTokens.space4),
                  // セットアップを完了せずに DevConsole（自動テスト含む）を
                  // 開けるテスト用入口。実機検証で店舗IDの永続化前に
                  // 各機能を素早く触りたいときに使う。
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : () => context.push('/dev'),
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('DevConsole を開く（テスト）'),
                    ),
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

class _SetupStepIndicator extends StatelessWidget {
  const _SetupStepIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 1; i <= total; i++) ...<Widget>[
          if (i > 1) const SizedBox(width: TofuTokens.space3),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= current
                    ? TofuTokens.brandPrimary
                    : TofuTokens.borderSubtle,
                borderRadius: BorderRadius.circular(TofuTokens.radiusXs),
              ),
            ),
          ),
        ],
        const SizedBox(width: TofuTokens.space5),
        Text('STEP $current / $total', style: TofuTextStyles.captionBold),
      ],
    );
  }
}
