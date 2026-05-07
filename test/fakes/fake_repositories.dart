import 'dart:async';

import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/repositories/cash_drawer_repository.dart';
import 'package:tofu_pos/domain/repositories/order_repository.dart';
import 'package:tofu_pos/domain/repositories/product_repository.dart';
import 'package:tofu_pos/domain/repositories/ticket_number_pool_repository.dart';
import 'package:tofu_pos/domain/repositories/unit_of_work.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number_pool.dart';

/// テスト用 InMemory の UnitOfWork。
class InMemoryUnitOfWork implements UnitOfWork {
  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class InMemoryProductRepository implements ProductRepository {
  InMemoryProductRepository(List<Product> initial)
      : _products = <String, Product>{
          for (final Product p in initial) p.id: p,
        };

  final Map<String, Product> _products;
  final StreamController<List<Product>> _controller =
      StreamController<List<Product>>.broadcast();

  @override
  Future<Product?> findById(String id) async => _products[id];

  @override
  Future<List<Product>> findAll({bool includeDeleted = false}) async {
    return _products.values
        .where((Product p) => includeDeleted || !p.isDeleted)
        .toList();
  }

  @override
  Stream<List<Product>> watchAll({bool includeDeleted = false}) =>
      _controller.stream;

  @override
  Future<void> upsert(Product product) async {
    _products[product.id] = product;
    _controller.add(_snapshot());
  }

  @override
  Future<void> markDeleted(String id) async {
    final Product? p = _products[id];
    if (p != null) {
      _products[id] = p.copyWith(isDeleted: true);
      _controller.add(_snapshot());
    }
  }

  @override
  Future<void> adjustStock(String productId, int delta) async {
    final Product? p = _products[productId];
    if (p == null) {
      throw StateError('Product not found: $productId');
    }
    _products[productId] = p.copyWith(stock: p.stock + delta);
    _controller.add(_snapshot());
  }

  List<Product> _snapshot() => _products.values.toList();
}

class InMemoryOrderRepository implements OrderRepository {
  final Map<int, Order> _orders = <int, Order>{};
  int _nextId = 1;
  final StreamController<List<Order>> _controller =
      StreamController<List<Order>>.broadcast();

  @override
  Future<Order?> findById(int id) async => _orders[id];

  @override
  Future<List<Order>> findAll({DateTime? from, DateTime? to}) async {
    return _orders.values.where((Order o) {
      if (from != null && o.createdAt.isBefore(from)) return false;
      if (to != null && o.createdAt.isAfter(to)) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<Order>> findUnsynced() async {
    return _orders.values
        .where((Order o) => o.syncStatus == SyncStatus.notSynced)
        .toList();
  }

  @override
  Stream<List<Order>> watchAll({DateTime? from, DateTime? to}) =>
      _controller.stream;

  @override
  Future<Order> create(Order order) async {
    final int id = _nextId++;
    final Order saved = order.copyWith(id: id);
    _orders[id] = saved;
    _controller.add(_orders.values.toList());
    return saved;
  }

  @override
  Future<void> updateStatus(int id, OrderStatus status) async {
    final Order? o = _orders[id];
    if (o != null) {
      _orders[id] = o.copyWith(orderStatus: status);
      _controller.add(_orders.values.toList());
    }
  }

  @override
  Future<void> updateSyncStatus(int id, SyncStatus status) async {
    final Order? o = _orders[id];
    if (o != null) {
      _orders[id] = o.copyWith(syncStatus: status);
      _controller.add(_orders.values.toList());
    }
  }
}

class InMemoryCashDrawerRepository implements CashDrawerRepository {
  CashDrawer _drawer = CashDrawer.empty();
  final StreamController<CashDrawer> _controller =
      StreamController<CashDrawer>.broadcast();

  @override
  Future<CashDrawer> get() async => _drawer;

  @override
  Stream<CashDrawer> watch() => _controller.stream;

  @override
  Future<void> apply(Map<Denomination, int> delta) async {
    _drawer = _drawer.apply(delta);
    _controller.add(_drawer);
  }

  @override
  Future<void> replace(CashDrawer drawer) async {
    _drawer = drawer;
    _controller.add(_drawer);
  }
}

class InMemoryTicketPoolRepository implements TicketNumberPoolRepository {
  InMemoryTicketPoolRepository([TicketNumberPool? initial])
      : _pool = initial ?? TicketNumberPool.empty();

  TicketNumberPool _pool;

  @override
  Future<TicketNumberPool> load() async => _pool;

  @override
  Future<void> save(TicketNumberPool pool) async {
    _pool = pool;
  }
}
