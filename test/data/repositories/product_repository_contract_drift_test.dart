import 'package:drift/native.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_product_repository.dart';
import 'package:tofu_pos/domain/repositories/product_repository.dart';

import '../../domain/contracts/product_repository_contract.dart';

void main() {
  AppDatabase? db;

  runProductRepositoryContract(
    'DriftProductRepository',
    create: () async {
      await db?.close();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      return DriftProductRepository(db!) as ProductRepository;
    },
    cleanup: () async {
      await db?.close();
      db = null;
    },
  );
}
