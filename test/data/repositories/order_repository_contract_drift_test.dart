import 'package:drift/native.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_order_repository.dart';
import 'package:tofu_pos/domain/repositories/order_repository.dart';

import '../../domain/contracts/order_repository_contract.dart';

void main() {
  AppDatabase? db;

  runOrderRepositoryContract(
    'DriftOrderRepository',
    create: () async {
      await db?.close();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      return DriftOrderRepository(db!) as OrderRepository;
    },
    cleanup: () async {
      await db?.close();
      db = null;
    },
  );
}
