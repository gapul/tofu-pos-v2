import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/confirm_dialog.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/num_stepper.dart';
import '../../../../core/ui/page_title.dart';
import '../../../../core/ui/pane_title.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../core/ui/tofu_icon.dart';
import '../../../../core/ui/tofu_input.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/settings_providers.dart';
import '../notifiers/regi_providers.dart';

/// 商品マスタ管理画面（Figma `13-Register-Products-Master` / 仕様書 §6.5）。
///
/// landscape:
///   - 左ペイン: PaneTitle + テーブル風リスト（色 / 商品名 / 価格 / 在庫 / 操作）
///   - 右ペイン (inline editor): 編集中の商品の編集フォーム + 色パレット
///
/// 編集後は ProductMasterAutoBroadcaster がキッチン端末へ自動送信する。
class ProductMasterScreen extends ConsumerStatefulWidget {
  const ProductMasterScreen({super.key});

  @override
  ConsumerState<ProductMasterScreen> createState() =>
      _ProductMasterScreenState();
}

class _ProductMasterScreenState extends ConsumerState<ProductMasterScreen> {
  Product? _editing;
  bool _newDraft = false;

  void _startEdit(Product p) => setState(() {
        _editing = p;
        _newDraft = false;
      });

  void _startNew() => setState(() {
        _editing = null;
        _newDraft = true;
      });

  void _cancelEdit() => setState(() {
        _editing = null;
        _newDraft = false;
      });

  Future<void> _save(Product saved) async {
    await ref.read(productRepositoryProvider).upsert(saved);
    if (!mounted) {
      return;
    }
    _cancelEdit();
  }

  Future<void> _delete(Product product) async {
    final bool ok = await TofuConfirmDialog.show(
      context,
      title: '${product.name} を廃止しますか?',
      message: '論理削除のため、過去の注文には影響しません。再度同じ商品を登録すると復活できます。',
      confirmLabel: '廃止する',
      destructive: true,
    );
    if (ok) {
      await ref.read(productRepositoryProvider).markDeleted(product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FeatureFlags flags =
        ref.watch(featureFlagsProvider).value ?? FeatureFlags.allOff;
    final AsyncValue<List<Product>> products = ref.watch(
      activeProductsProvider,
    );

    final bool editorOpen = _editing != null || _newDraft;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PageTitle(title: '商品マスタ'),
            Expanded(
              child: products.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: StatusIndicator.custom(
              label: '$e',
              icon: Icons.error_outline,
              tone: StatusIndicatorTone.danger,
            ),
          ),
          data: (list) {
            return LayoutBuilder(
              builder: (c, constraints) {
                final bool wide = constraints.maxWidth >= 720;
                final Widget listPane = _ListPane(
                  products: list,
                  selectedId: _editing?.id,
                  stockEnabled: flags.stockManagement,
                  onEdit: _startEdit,
                  onDelete: _delete,
                  onNew: _startNew,
                );

                if (!wide || !editorOpen) {
                  // narrow: full-width list. 編集はモーダルで対応。
                  return _SingleColumn(
                    list: listPane,
                    editor: editorOpen
                        ? _EditorPane(
                            key: ValueKey(_editing?.id ?? '__new__'),
                            existing: _editing,
                            stockEnabled: flags.stockManagement,
                            onSave: _save,
                            onCancel: _cancelEdit,
                          )
                        : null,
                  );
                }

                // landscape + editor 開: 左右 2 ペイン。
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 6, child: listPane),
                    Expanded(
                      flex: 5,
                      child: _EditorPane(
                        key: ValueKey(_editing?.id ?? '__new__'),
                        existing: _editing,
                        stockEnabled: flags.stockManagement,
                        onSave: _save,
                        onCancel: _cancelEdit,
                      ),
                    ),
                  ],
                );
              },
            );
          },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// narrow 用: 列を縦に重ねる。editor 開時はリストの下に表示。
// ---------------------------------------------------------------------------
class _SingleColumn extends StatelessWidget {
  const _SingleColumn({required this.list, required this.editor});
  final Widget list;
  final Widget? editor;

  @override
  Widget build(BuildContext context) {
    if (editor == null) {
      return list;
    }
    return Column(
      children: <Widget>[
        Expanded(child: list),
        Container(
          height: TofuTokens.strokeHairline,
          color: TofuTokens.borderSubtle,
        ),
        Flexible(child: editor!),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 左ペイン (Figma 233:118): 一覧テーブル。
// ---------------------------------------------------------------------------
class _ListPane extends StatelessWidget {
  const _ListPane({
    required this.products,
    required this.selectedId,
    required this.stockEnabled,
    required this.onEdit,
    required this.onDelete,
    required this.onNew,
  });

  final List<Product> products;
  final String? selectedId;
  final bool stockEnabled;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        color: TofuTokens.bgCanvas,
        padding: const EdgeInsets.all(TofuTokens.space7),
        child: _Empty(onNew: onNew),
      );
    }

    return Container(
      color: TofuTokens.bgCanvas,
      padding: const EdgeInsets.all(TofuTokens.space7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PaneTitle(
            title: '商品マスタ',
            count: products.length,
            subtitle: '営業中も編集可能',
            trailing: TofuButton(
              label: '新規追加',
              icon: Icons.add,
              onPressed: onNew,
            ),
          ),
          const SizedBox(height: TofuTokens.space5),
          _ColumnHeader(stockEnabled: stockEnabled),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: products.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: TofuTokens.borderSubtle,
              ),
              itemBuilder: (c, i) => _ProductRow(
                product: products[i],
                selected: products[i].id == selectedId,
                stockEnabled: stockEnabled,
                onEdit: () => onEdit(products[i]),
                onDelete: () => onDelete(products[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            style: TofuTextStyles.h3.copyWith(color: TofuTokens.textTertiary),
          ),
          const SizedBox(height: TofuTokens.space5),
          TofuButton(label: '商品を追加', icon: Icons.add, onPressed: onNew),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.stockEnabled});
  final bool stockEnabled;

  @override
  Widget build(BuildContext context) {
    final TextStyle s = TofuTextStyles.captionBold.copyWith(
      color: TofuTokens.textTertiary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space4,
        vertical: TofuTokens.space3,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: 40, child: Text('色', style: s)),
          const SizedBox(width: TofuTokens.space3),
          Expanded(child: Text('商品名', style: s)),
          SizedBox(width: 80, child: Text('価格', style: s, textAlign: TextAlign.right)),
          if (stockEnabled)
            SizedBox(width: 64, child: Text('在庫', style: s, textAlign: TextAlign.right)),
          const SizedBox(width: TofuTokens.space5),
          SizedBox(width: 144, child: Text('操作', style: s, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.selected,
    required this.stockEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final bool selected;
  final bool stockEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color swatch = product.displayColor != null
        ? Color(product.displayColor!)
        : TofuTokens.brandPrimarySubtle;
    return Material(
      color: selected ? TofuTokens.brandPrimarySubtle : Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space4,
            vertical: TofuTokens.space4,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: swatch,
                  borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
                  border: Border.all(color: TofuTokens.borderSubtle),
                ),
              ),
              const SizedBox(width: TofuTokens.space3),
              Expanded(
                child: Text(product.name, style: TofuTextStyles.bodyMdBold),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  TofuFormat.yen(product.price),
                  style: TofuTextStyles.bodyMd,
                  textAlign: TextAlign.right,
                ),
              ),
              if (stockEnabled)
                SizedBox(
                  width: 64,
                  child: Text(
                    '${product.stock}',
                    style: TofuTextStyles.bodyMdBold.copyWith(
                      color: product.stock == 0
                          ? TofuTokens.dangerText
                          : TofuTokens.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              const SizedBox(width: TofuTokens.space5),
              SizedBox(
                width: 144,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TofuButton(
                      label: '編集',
                      variant: TofuButtonVariant.secondary,
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: TofuTokens.space2),
                    IconButton(
                      tooltip: '廃止',
                      icon: const Icon(Icons.delete_outline),
                      color: TofuTokens.dangerIcon,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 右ペイン (Figma 233:234): 編集フォーム。
// ---------------------------------------------------------------------------
class _EditorPane extends StatefulWidget {
  const _EditorPane({
    required this.existing,
    required this.stockEnabled,
    required this.onSave,
    required this.onCancel,
    super.key,
  });
  final Product? existing;
  final bool stockEnabled;
  final Future<void> Function(Product) onSave;
  final VoidCallback onCancel;

  @override
  State<_EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends State<_EditorPane> {
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

  Future<void> _save() async {
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
    await widget.onSave(saved);
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.existing == null
        ? '新規追加'
        : '編集中: ${widget.existing!.name}';

    return Container(
      color: TofuTokens.bgSurface,
      padding: const EdgeInsets.all(TofuTokens.space7),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          PaneTitle(title: title),
          const SizedBox(height: TofuTokens.space5),
          Text(
            '商品名',
            style: TofuTextStyles.bodySmBold.copyWith(
              color: TofuTokens.textSecondary,
            ),
          ),
          const SizedBox(height: TofuTokens.space2),
          TofuInput(
            controller: _name,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: TofuTokens.space5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TofuNumStepper(
                  label: '価格 (円)',
                  value: _price,
                  onChanged: (v) => setState(() => _price = v),
                  step: 10,
                  max: 1000000,
                  suffix: '円',
                  formatter: (v) =>
                      TofuFormat.yenInt(v).replaceAll('円', ''),
                ),
              ),
              if (widget.stockEnabled) ...<Widget>[
                const SizedBox(width: TofuTokens.space5),
                Expanded(
                  child: TofuNumStepper(
                    label: '在庫数',
                    value: _stock,
                    onChanged: (v) => setState(() => _stock = v),
                    max: 99999,
                    suffix: '個',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: TofuTokens.space5),
          Text(
            'ボタン色',
            style: TofuTextStyles.bodySmBold.copyWith(
              color: TofuTokens.textSecondary,
            ),
          ),
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
                variant: TofuButtonVariant.secondary,
                onPressed: widget.onCancel,
              ),
              const SizedBox(width: TofuTokens.adjacentSpacing),
              TofuButton(label: '保存', onPressed: _save),
            ],
          ),
        ],
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
        unawaited(HapticFeedback.selectionClick());
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
