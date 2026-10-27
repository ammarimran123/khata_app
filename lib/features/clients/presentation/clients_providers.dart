import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_bootstrap.dart';
import '../data/client.dart';
import '../data/client_detail.dart';
import '../data/client_summary.dart';
import '../data/clients_repository.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(supabase);
});

final clientSummariesProvider =
    AsyncNotifierProvider<ClientSummariesController, List<ClientSummary>>(
      ClientSummariesController.new,
    );

class ClientSummariesController extends AsyncNotifier<List<ClientSummary>> {
  @override
  Future<List<ClientSummary>> build() {
    return ref.read(clientsRepositoryProvider).fetchClientSummaries();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(clientsRepositoryProvider).fetchClientSummaries(),
    );
  }
}

/// Client + full transaction history, for the client profile screen.
final clientDetailProvider = FutureProvider.autoDispose
    .family<ClientDetail, String>((ref, id) async {
      final repo = ref.read(clientsRepositoryProvider);
      final client = await repo.fetchClient(id);
      final transactions = await repo.fetchTransactions(id);
      return ClientDetail(client: client, transactions: transactions);
    });

/// Just the client row, for pre-filling the edit form without also
/// fetching every transaction.
final singleClientProvider = FutureProvider.autoDispose.family<Client, String>(
  (ref, id) => ref.read(clientsRepositoryProvider).fetchClient(id),
);
