import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/confirm_dialog.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/numeric_stepper.dart';
import '../../../../core/ui/status_chip.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/settings_providers.dart';
import '../notifiers/regi_providers.dart';

/// 商品マスタ管理画面（仕様書 §6.5）。
///
/// 編集後は ProductMasterAutoBroadcaster がキッチン端末へ自動送信する。
class ProductMasterScreen extends ConsumerWidget {
  const ProductMasterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Product>> products = ref.watch(
      activeProductsProvider,
    );

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppBar(
        title: const Text('商品マスタ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '商品を追加',
            icon: const Icon(Icons.add),
            onPressed: () => _showEditor(context, ref, null),
          ),
        ],
      ),
      body: SafeArea(
        child: products.when(
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(TofuTokens.space7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: TofuTokens.textDisabled,
                      ),
                      const SizedBox(height: TofuTokens.space5),
                      Text(
                        '商品が登録されていません',
                        style: TofuTextStyles.h3.copyWith(
                          color: TofuTokens.textTertiary,
                        ),
                      ),
                      const SizedBox(height: TofuTokens.space5),
                      TofuButton(
                        label: '商品を追加',
                        icon: Icons.add,
                        onPressed: () => _showEditor(context, ref, null),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(TofuTokens.space5),
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: TofuTokens.space3),
              itemBuilder: (c, i) => _ProductRow(
                product: list[i],
                onEdit: () => _showEditor(context, ref, list[i]),
                onDelete: () => _delete(context, ref, list[i]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: StatusChip(
              label: '$e',
              icon: Icons.error_outline,
              tone: TofuStatusTone.danger,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref,
    Product? existing,
  ) async {
    final FeatureFlags flags =
        ref.read(featureFlagsProvider).value ?? FeatureFlags.allOff;
    final Product? saved = await showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (c) => _ProductEditor(
        existing: existing,
        stockEnabled: flags.stockManagement,
      ),
    );
    if (saved != null) {
      await ref.read(productRepositoryProvider).upsert(saved);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final bool ok = await TofuConfirmDialog.show(
      context,
      title: '${product.name} を削除しますか?',
      message: '論理削除のため、過去の注文には影響しません。再度同じ商品を登録すると復活できます。',
      confirmLabel: '削除する',
      destructive: true,
    );
    if (ok) {
      await ref.read(productRepositoryProvider).markDeleted(product.id);
    }
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space4),
      decoration: BoxDecoration(
        color: TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: product.displayColor != null
                  ? Color(product.displayColor!)
                  : TofuTokens.brandPrimarySubtle,
              borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
            ),
          ),
          const SizedBox(width: TofuTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(product.name, style: TofuTextStyles.bodyLgBold),
                const SizedBox(height: 2),
                Text(
                  '${TofuFormat.yen(product.price)} / 在庫 ${product.stock}',
                  style: TofuTextStyles.bodySm.copyWith(
                    color: TofuTokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '編集',
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: '削除',
            icon: const Icon(Icons.delete_outline),
            color: TofuTokens.dangerIcon,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.existing, required this.stockEnabled});
  final Product? existing;
  final bool stockEnabled;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  static const Uuid _uuid = Uuid();
  static const List<Color> _palette = <Color>[
    TofuTokens.brandPrimarySubtle,
    Color(0xFFF8D9D0),
    Color(0xFFDCE7B0),
    Color(0xFFFEF3C7),
    Color(0xFFE9D5FF),
    Color(0xFFCEEAF1),
    Color(0xFFE5E5E5),
  ];

  late TextEditingController _name;
  late int _price;
  late int _stock;
  int? _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Product? p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _price = p?.price.yen ?? 100;
    _stock = p?.stock ?? 50;
    _color = p?.displayColor;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '商品名を入力してください');
      return;
    }
    final Product saved = Product(
      id: widget.existing?.id ?? _uuid.v4(),
      name: name,
      price: Money(_price),
      stock: _stock,
      displayColor: _color,
    );
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TofuTokens.bgCanvas,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(TofuTokens.space7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.existing == null ? '商品を追加' : '商品を編集',
                style: TofuTextStyles.h3,
              ),
              const SizedBox(height: TofuTokens.space5),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: '商品名',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: TofuTokens.space5),
              Row(
                children: <Widget>[
                  Expanded(
                    child: NumericStepper(
                      label: '価格',
                      value: _price,
                      onChanged: (v) => setState(() => _price = v),
                      step: 10,
                      max: 1000000,
                      suffix: '円',
                      formatter: (v) =>
                          TofuFormat.yenInt(v).replaceAll('¥', ''),
                    ),
                  ),
                  const SizedBox(width: TofuTokens.space5),
                  if (widget.stockEnabled)
                    Expanded(
                      child: NumericStepper(
                        label: '在庫',
                        value: _stock,
                        onChanged: (v) => setState(() => _stock = v),
                        max: 99999,
                        suffix: '個',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: TofuTokens.space5),
              const Text('表示色', style: TofuTextStyles.bodySmBold),
              const SizedBox(height: TofuTokens.space3),
              Wrap(
                spacing: TofuTokens.space3,
                runSpacing: TofuTokens.space3,
                children: <Widget>[
                  _ColorSwatch(
                    color: null,
                    selected: _color == null,
                    onTap: () => setState(() => _color = null),
                  ),
                  for (final Color c in _palette)
                    _ColorSwatch(
                      color: c,
                      selected: _color == c.toARGB32(),
                      onTap: () => setState(() => _color = c.toARGB32()),
                    ),
                ],
              ),
              const SizedBox(height: TofuTokens.space7),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TofuButton(
                    label: 'キャンセル',
                    variant: TofuButtonVariant.outlined,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: TofuTokens.adjacentSpacing),
                  TofuButton(label: '保存', onPressed: _save),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
          border: Border.all(
            color: selected ? TofuTokens.brandPrimary : TofuTokens.borderSubtle,
            width: selected ? 2.5 : TofuTokens.strokeHairline,
          ),
        ),
        child: color == null
            ? const Icon(
                Icons.format_color_reset,
                color: TofuTokens.textTertiary,
              )
            : null,
      ),
    );
  }
}
