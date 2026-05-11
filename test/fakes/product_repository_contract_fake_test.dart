import '../domain/contracts/product_repository_contract.dart';
import 'fake_repositories.dart';

void main() {
  runProductRepositoryContract(
    'InMemoryProductRepository',
    create: () async => InMemoryProductRepository(const <Never>[]),
  );
}
