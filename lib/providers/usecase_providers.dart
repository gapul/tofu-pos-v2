import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usecases/cancel_order_usecase.dart';
import '../domain/usecases/checkout_usecase.dart';
import 'repository_providers.dart';

final Provider<CheckoutUseCase> checkoutUseCaseProvider =
    Provider<CheckoutUseCase>(
  (Ref<CheckoutUseCase> ref) => CheckoutUseCase(
    unitOfWork: ref.watch(unitOfWorkProvider),
    orderRepository: ref.watch(orderRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
    cashDrawerRepository: ref.watch(cashDrawerRepositoryProvider),
    ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
  ),
);

final Provider<CancelOrderUseCase> cancelOrderUseCaseProvider =
    Provider<CancelOrderUseCase>(
  (Ref<CancelOrderUseCase> ref) => CancelOrderUseCase(
    unitOfWork: ref.watch(unitOfWorkProvider),
    orderRepository: ref.watch(orderRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
    cashDrawerRepository: ref.watch(cashDrawerRepositoryProvider),
    ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
  ),
);
