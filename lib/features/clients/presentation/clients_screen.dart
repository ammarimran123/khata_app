import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/khata_chip.dart';
import '../data/client_summary.dart';
import 'clients_providers.dart';
import 'widgets/client_list_tile.dart';

enum _ClientFilter { all, receivable, payable, settled }

enum _ClientSort { recent, name, highest }

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _ClientFilter _filter = _ClientFilter.all;
  _ClientSort _sort = _ClientSort.recent;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _cycleSort() {
    setState(() {
      _sort = _ClientSort.values[(_sort.index + 1) % _ClientSort.values.length];
    });
  }

  List<ClientSummary> _applyFilters(List<ClientSummary> input) {
    final q = _query.trim().toLowerCase();
    final digitsQuery = q.replaceAll(RegExp(r'\D'), '');

    var list = input.where((s) {
      if (q.isEmpty) return true;
      final nameMatch = s.client.name.toLowerCase().contains(q);
      final phoneMatch =
          digitsQuery.isNotEmpty &&
          s.client.phone.replaceAll(RegExp(r'\D'), '').contains(digitsQuery);
      final businessMatch = (s.client.businessName ?? '').toLowerCase().contains(
        q,
      );
      return nameMatch || phoneMatch || businessMatch;
    }).where((s) {
      return switch (_filter) {
        _ClientFilter.all => true,
        _ClientFilter.receivable => s.balance > 0,
        _ClientFilter.payable => s.balance < 0,
        _ClientFilter.settled => s.balance == 0,
      };
    }).toList();

    switch (_sort) {
      case _ClientSort.recent:
        list.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
      case _ClientSort.name:
        list.sort((a, b) => a.client.name.compareTo(b.client.name));
      case _ClientSort.highest:
        list.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
    }
    return list;
  }

  String _filterLabel(_ClientFilter f) => switch (f) {
    _ClientFilter.all => 'All',
    _ClientFilter.receivable => 'Receivable',
    _ClientFilter.payable => 'Payable',
    _ClientFilter.settled => 'Settled',
  };

  String _sortLabel(_ClientSort s) => switch (s) {
    _ClientSort.recent => 'Recent',
    _ClientSort.name => 'Name',
    _ClientSort.highest => 'Highest',
  };

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(clientSummariesProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Clients',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                ElevatedButton(
                  onPressed: () => context.push('/clients/new'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('+ Add Client'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.text, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.neutral700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search name or phone number',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _ClientFilter.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final f = _ClientFilter.values[i];
                  return KhataChip(
                    label: _filterLabel(f),
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: summariesAsync.when(
              data: (list) => _buildList(context, list),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                message: 'Could not load clients.\n$e',
                action: OutlinedButton(
                  onPressed: () =>
                      ref.read(clientSummariesProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ClientSummary> list) {
    final filtered = _applyFilters(list);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filtered.length} of ${list.length} clients',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.neutral600,
                ),
              ),
              TextButton.icon(
                onPressed: _cycleSort,
                icon: const Icon(Icons.sort, size: 14),
                label: Text('Sort · ${_sortLabel(_sort)}'),
              ),
            ],
          ),
        ),
        Container(
          height: AppSpacing.ruleWidth,
          color: AppColors.text,
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        Expanded(
          child: list.isEmpty
              ? EmptyState(
                  message:
                      'No clients yet. Add your first client to start tracking their khata.',
                  action: ElevatedButton(
                    onPressed: () => context.push('/clients/new'),
                    child: const Text('+ Add Client'),
                  ),
                )
              : filtered.isEmpty
              ? EmptyState(message: 'No client matches "$_query".')
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(clientSummariesProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        ClientListTile(summary: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
