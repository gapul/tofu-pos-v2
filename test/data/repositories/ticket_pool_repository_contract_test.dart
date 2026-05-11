import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_ticket_pool_repository.dart';

import '../../domain/contracts/ticket_pool_repository_contract.dart';
import '../../fakes/fake_repositories.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  runTicketPoolRepositoryContract(
    'SharedPrefsTicketPoolRepository',
    create: () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return SharedPrefsTicketPoolRepository(prefs);
    },
  );

  runTicketPoolRepositoryContract(
    'InMemoryTicketPoolRepository',
    create: () async => InMemoryTicketPoolRepository(),
  );
}
