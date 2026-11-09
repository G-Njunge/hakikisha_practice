import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/medicine.dart';
import '../verify/medicine_repository.dart';
import 'approval_chip.dart';

/// The Search tab: look a medicine up by name when the barcode can't be
/// scanned. With no query it lists the whole registry, A to Z.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(medicineCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search medicines')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Brand or generic name, e.g. Panadol',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: _query.clear),
              ),
            ),
          ),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(medicineCatalogProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (medicines) {
                final query = _query.text.trim();
                final results = query.isEmpty ? medicines : searchMedicines(medicines, query);
                if (results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No registered medicine matches "$query".\n'
                        "If you have it in hand, that's worth reporting.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _MedicineTile(medicine: results[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  const _MedicineTile({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final details = [medicine.genericName, medicine.strength, medicine.dosageForm].whereType<String>().join(' · ');
    return ListTile(
      title: Text(medicine.name),
      subtitle: Text(details.isEmpty ? medicine.manufacturer : '$details\n${medicine.manufacturer}'),
      isThreeLine: details.isNotEmpty,
      trailing: ApprovalChip(status: medicine.approvalStatus),
      onTap: () => context.push('/medicines/${medicine.id}'),
    );
  }
}
