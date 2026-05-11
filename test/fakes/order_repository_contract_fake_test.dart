import '../domain/contracts/order_repository_contract.dart';
import 'fake_repositories.dart';

void main() {
  runOrderRepositoryContract(
    'InMemoryOrderRepository',
    create: () async => InMemoryOrderRepository(),
  );
}
