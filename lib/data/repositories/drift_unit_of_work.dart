import '../../domain/repositories/unit_of_work.dart';
import '../datasources/local/database.dart';

/// drift のトランザクションで [UnitOfWork] を実装する。
class DriftUnitOfWork implements UnitOfWork {
  DriftUnitOfWork(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() body) {
    return _db.transaction<T>(body);
  }
}
