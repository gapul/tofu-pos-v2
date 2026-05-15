import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/calling_order.dart';
import '../../../../providers/repository_providers.dart';

final StreamProvider<List<CallingOrder>> callingOrdersProvider =
    StreamProvider<List<CallingOrder>>(
      (ref) => ref.watch(callingOrderRepositoryProvider).watchAll(),
    );
