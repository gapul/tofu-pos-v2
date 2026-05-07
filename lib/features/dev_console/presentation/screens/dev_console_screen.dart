import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/app_exceptions.dart';
import '../../../../core/export/csv_export_file_service.dart';
import '../../../../core/export/csv_export_service.dart';
import '../../../../core/sync/supabase_realtime_listener.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../domain/entities/operation_log.dart';
import '../../../../domain/enums/transport_mode.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/value_objects/checkout_draft.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/shop_id.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../providers/sync_providers.dart';
import '../../../../providers/usecase_providers.dart';

/// 開発者用コンソール画面（Figma デザイン待ちの間の検証用）。
///
/// 警告: 本画面は本番リリースには含めない。
class DevConsoleScreen extends ConsumerStatefulWidget {
  const DevConsoleScreen({super.key});

  @override
  ConsumerState<DevConsoleScreen> createState() => _DevConsoleScreenState();
}

class _DevConsoleScreenState extends ConsumerState<DevConsoleScreen> {
  static const Uuid _uuid = Uuid();

  String? _lastResult;

  void _show(String message) {
    setState(() => _lastResult = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Console'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const _SectionHeader('注意: これは開発者用画面です'),
            if (_lastResult != null)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_lastResult!,
                      style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
            const SizedBox(height: 8),
            _SetupSection(onResult: _show),
            const SizedBox(height: 8),
            _FeatureFlagsSection(onResult: _show),
            const SizedBox(height: 8),
            _ProductsSection(onResult: _show, uuid: _uuid),
            const SizedBox(height: 8),
            _CheckoutSection(onResult: _show),
            const SizedBox(height: 8),
            _OrdersSection(onResult: _show),
            const SizedBox(height: 8),
            _ExportSection(onResult: _show),
            const SizedBox(height: 8),
            _SyncSection(onResult: _show),
            const SizedBox(height: 8),
            _TransportModeSection(onResult: _show),
            const SizedBox(height: 8),
            const _RealtimeSection(),
            const SizedBox(height: 8),
            const _OperationLogSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

// ============== Setup Section ==============

class _SetupSection extends ConsumerStatefulWidget {
  const _SetupSection({required this.onResult});
  final void Function(String) onResult;
  @override
  ConsumerState<_SetupSection> createState() => _SetupSectionState();
}

String _maskUrl(String url) {
  if (url.length <= 30) return url;
  return '${url.substring(0, 30)}…';
}

class _SetupSectionState extends ConsumerState<_SetupSection> {
  final TextEditingController _shopIdCtrl = TextEditingController();
  String? _currentShopId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final ShopId? id = await ref.read(settingsRepositoryProvider).getShopId();
    setState(() {
      _currentShopId = id?.value;
      _shopIdCtrl.text = id?.value ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '1. Setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('現在の店舗ID: ${_currentShopId ?? '(未設定)'}'),
          Text(
            'Supabase: ${Env.hasSupabaseCredentials ? "接続情報あり (${_maskUrl(Env.supabaseUrl)})" : "未設定"}',
            style: TextStyle(
              color: Env.hasSupabaseCredentials
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _shopIdCtrl,
            decoration: const InputDecoration(
              labelText: '店舗ID（例: yakisoba_A）',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: () async {
                  final String v = _shopIdCtrl.text.trim();
                  if (v.isEmpty) {
                    widget.onResult('店舗IDを入力してください');
                    return;
                  }
                  await ref
                      .read(settingsRepositoryProvider)
                      .setShopId(ShopId(v));
                  await _refresh();
                  widget.onResult('店舗ID を $v に設定しました');
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============== Feature Flags ==============

class _FeatureFlagsSection extends ConsumerWidget {
  const _FeatureFlagsSection({required this.onResult});
  final void Function(String) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FeatureFlags> async = ref.watch(featureFlagsProvider);
    return _Section(
      title: '2. 機能フラグ',
      child: async.when(
        loading: () => const CircularProgressIndicator.adaptive(),
        error: (Object e, _) => Text('error: $e'),
        data: (FeatureFlags flags) => Column(
          children: <Widget>[
            _flagTile(ref, '在庫管理', flags.stockManagement,
                (bool v) => flags.copyWith(stockManagement: v)),
            _flagTile(ref, '金種管理', flags.cashManagement,
                (bool v) => flags.copyWith(cashManagement: v)),
            _flagTile(ref, '顧客属性入力', flags.customerAttributes,
                (bool v) => flags.copyWith(customerAttributes: v)),
            _flagTile(ref, 'キッチン連携', flags.kitchenLink,
                (bool v) => flags.copyWith(kitchenLink: v)),
            _flagTile(ref, '呼び出し連携', flags.callingLink,
                (bool v) => flags.copyWith(callingLink: v)),
          ],
        ),
      ),
    );
  }

  Widget _flagTile(
    WidgetRef ref,
    String label,
    bool current,
    FeatureFlags Function(bool) toggle,
  ) {
    return SwitchListTile(
      title: Text(label),
      value: current,
      dense: true,
      onChanged: (bool v) async {
        await ref
            .read(settingsRepositoryProvider)
            .setFeatureFlags(toggle(v));
        onResult('$label: $v');
      },
    );
  }
}

// ============== Products ==============

class _ProductsSection extends ConsumerWidget {
  const _ProductsSection({required this.onResult, required this.uuid});
  final void Function(String) onResult;
  final Uuid uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: '3. 商品マスタ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StreamBuilder<List<Product>>(
            stream: ref.watch(productRepositoryProvider).watchAll(),
            builder: (BuildContext c, AsyncSnapshot<List<Product>> snap) {
              final List<Product> list = snap.data ?? <Product>[];
              if (list.isEmpty) return const Text('商品なし');
              return Column(
                children: list
                    .map((Product p) => Text(
                        '・${p.name}  ${p.price}  在庫=${p.stock}'))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: () async {
                  final repo = ref.read(productRepositoryProvider);
                  final List<({String n, int p, int s})> samples =
                      <({String n, int p, int s})>[
                    (n: '焼きそば', p: 400, s: 50),
                    (n: 'ジュース', p: 150, s: 100),
                    (n: 'たい焼き', p: 200, s: 30),
                  ];
                  for (final s in samples) {
                    await repo.upsert(
                      Product(
                        id: uuid.v4(),
                        name: s.n,
                        price: Money(s.p),
                        stock: s.s,
                      ),
                    );
                  }
                  onResult('サンプル商品 ${samples.length} 件を追加');
                },
                child: const Text('サンプル商品3件追加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============== Checkout ==============

class _CheckoutSection extends ConsumerWidget {
  const _CheckoutSection({required this.onResult});
  final void Function(String) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: '4. 会計（先頭の商品を1個カートに入れて確定）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton(
            onPressed: () async {
              final List<Product> products =
                  await ref.read(productRepositoryProvider).findAll();
              if (products.isEmpty) {
                onResult('商品がないので先に「サンプル商品3件追加」を押してください');
                return;
              }
              final Product p = products.first;
              final flags = await ref
                  .read(settingsRepositoryProvider)
                  .getFeatureFlags();
              final draft = CheckoutDraft(
                items: <OrderItem>[
                  OrderItem(
                    productId: p.id,
                    productName: p.name,
                    priceAtTime: p.price,
                    quantity: 1,
                  ),
                ],
                receivedCash: p.price,
              );
              try {
                final Order order = await ref
                    .read(checkoutUseCaseProvider)
                    .execute(draft: draft, flags: flags);
                onResult(
                    '会計確定 #${order.id} 整理券=${order.ticketNumber} ${p.name} ${p.price}');
              } on TicketPoolExhaustedException catch (e) {
                onResult('エラー: ${e.message}');
              } on InsufficientStockException catch (e) {
                onResult('エラー: $e');
              } catch (e) {
                onResult('エラー: $e');
              }
            },
            child: const Text('1点会計確定'),
          ),
        ],
      ),
    );
  }
}

// ============== Orders ==============

class _OrdersSection extends ConsumerWidget {
  const _OrdersSection({required this.onResult});
  final void Function(String) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: '5. 注文一覧 / 取消',
      child: StreamBuilder<List<Order>>(
        stream: ref.watch(orderRepositoryProvider).watchAll(),
        builder: (BuildContext c, AsyncSnapshot<List<Order>> snap) {
          final List<Order> list = snap.data ?? <Order>[];
          if (list.isEmpty) return const Text('注文なし');
          return Column(
            children: list
                .map(
                  (Order o) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '#${o.id} 整理券=${o.ticketNumber}  ${o.finalPrice}  ${o.orderStatus.name}',
                            style: TextStyle(
                              decoration: o.orderStatus == OrderStatus.cancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (o.orderStatus != OrderStatus.cancelled)
                          TextButton(
                            onPressed: () async {
                              final flags = await ref
                                  .read(settingsRepositoryProvider)
                                  .getFeatureFlags();
                              try {
                                await ref
                                    .read(cancelOrderUseCaseProvider)
                                    .execute(
                                      orderId: o.id,
                                      flags: flags,
                                      originalCashDelta: const <int, int>{},
                                    );
                                onResult('#${o.id} を取消');
                              } catch (e) {
                                onResult('エラー: $e');
                              }
                            },
                            child: const Text('取消'),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

// ============== Export ==============

// ============== Transport Mode ==============

class _TransportModeSection extends ConsumerWidget {
  const _TransportModeSection({required this.onResult});
  final void Function(String) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TransportMode> async =
        ref.watch(transportModeProvider);
    return _Section(
      title: '8. 通信モード',
      child: async.when(
        loading: () => const CircularProgressIndicator.adaptive(),
        error: (Object e, _) => Text('error: $e'),
        data: (TransportMode current) => Wrap(
          spacing: 8,
          children: <Widget>[
            for (final TransportMode m in TransportMode.values)
              ChoiceChip(
                label: Text(_labelOf(m)),
                selected: m == current,
                onSelected: (bool sel) async {
                  if (!sel) return;
                  await ref
                      .read(settingsRepositoryProvider)
                      .setTransportMode(m);
                  onResult('通信モード: ${_labelOf(m)}');
                },
              ),
          ],
        ),
      ),
    );
  }

  String _labelOf(TransportMode m) {
    switch (m) {
      case TransportMode.online:
        return 'オンライン';
      case TransportMode.localLan:
        return 'ローカルLAN';
      case TransportMode.bluetooth:
        return 'BLE';
    }
  }
}

// ============== Realtime ==============

class _RealtimeSection extends ConsumerWidget {
  const _RealtimeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RealtimeOrderLineEvent> events =
        ref.watch(realtimeOrderLineEventsProvider);
    return _Section(
      title: '9. Realtime 受信（直近1件）',
      child: events.when(
        loading: () => const Text('購読待機中...'),
        error: (Object e, _) => Text('error: $e'),
        data: (RealtimeOrderLineEvent ev) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('種別: ${ev.eventType.name}'),
            Text('整理券=${ev.ticketNumber} 注文ID=${ev.localOrderId} 行=${ev.lineNo}'),
            Text('${ev.productName} x${ev.quantity}'),
            Text('ステータス=${ev.orderStatus} 取消=${ev.isCancelled}'),
          ],
        ),
      ),
    );
  }
}

// ============== OperationLog 閲覧 ==============

class _OperationLogSection extends ConsumerStatefulWidget {
  const _OperationLogSection();

  @override
  ConsumerState<_OperationLogSection> createState() =>
      _OperationLogSectionState();
}

class _OperationLogSectionState extends ConsumerState<_OperationLogSection> {
  List<OperationLog> _logs = <OperationLog>[];
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final List<OperationLog> logs =
        await ref.read(operationLogRepositoryProvider).findRecent(limit: 50);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_refresh()));
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '10. 操作ログ（直近50件）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('再読み込み'),
          ),
          const SizedBox(height: 8),
          if (_logs.isEmpty)
            const Text('（ログなし）')
          else
            for (final OperationLog log in _logs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '#${log.id} ${log.kind} target=${log.targetId ?? "-"} '
                  '@${log.occurredAt.toIso8601String()}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
        ],
      ),
    );
  }
}

// ============== Sync ==============

class _SyncSection extends ConsumerWidget {
  const _SyncSection({required this.onResult});
  final void Function(String) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SyncWarningLevel> warning =
        ref.watch(syncWarningProvider);
    return _Section(
      title: '7. クラウド同期',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!Env.hasSupabaseCredentials)
            Text(
              'Supabase 接続情報が未設定です（.env を埋めてください）',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (warning.value == SyncWarningLevel.prolongedFailure)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '同期失敗が1時間以上続いています（§8.2）。回線と Supabase 接続を確認してください。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          FilledButton(
            onPressed: () async {
              try {
                final SyncResult r =
                    await ref.read(syncServiceProvider).runOnce();
                onResult('同期 OK=${r.successCount} NG=${r.failureCount}');
              } catch (e) {
                onResult('エラー: $e');
              }
            },
            child: const Text('未同期注文を一括送信'),
          ),
        ],
      ),
    );
  }
}

class _ExportSection extends ConsumerWidget {
  const _ExportSection({required this.onResult});
  final void Function(String) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: '6. CSV 出力',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OutlinedButton(
            onPressed: () async {
              final List<Order> orders =
                  await ref.read(orderRepositoryProvider).findAll();
              final ShopId? shopId =
                  await ref.read(settingsRepositoryProvider).getShopId();
              final String csv = const CsvExportService().serialize(
                orders: orders,
                shopId: shopId?.value ?? '(unset)',
              );
              final List<String> lines = csv.split('\r\n');
              final String preview = lines.take(5).join('\n');
              onResult('CSV ${lines.length}行\n$preview');
            },
            child: const Text('プレビュー（画面表示）'),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () async {
              final List<Order> orders =
                  await ref.read(orderRepositoryProvider).findAll();
              final ShopId? shopId =
                  await ref.read(settingsRepositoryProvider).getShopId();
              try {
                final String path = await CsvExportFileService().writeAndShare(
                  orders: orders,
                  shopId: shopId?.value ?? 'unset',
                );
                onResult('保存して共有: $path');
              } catch (e) {
                onResult('エラー: $e');
              }
            },
            child: const Text('ファイルに保存して共有シートを開く'),
          ),
        ],
      ),
    );
  }
}
