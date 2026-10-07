import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/widgets/clothing_card.dart';
import 'package:dijital_dolap/screens/add_clothing_screen.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Ekran ilk açıldığında veriyi çek
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClothingProvider>().loadAll();
    });
  }

  List<String> _categories(List<ClothingItem> items) {
    final present = items.map((i) => i.category).toSet();
    final known = kCategoryLabels.keys.where(present.contains);
    final others = present.difference(kCategoryLabels.keys.toSet()).toList()
      ..sort();
    return [...known, ...others];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClothingProvider>();
    final all = provider.items;
    final items = _selectedCategory == null
        ? all
        : all.where((i) => i.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dolabım')),
            floatingActionButton: FloatingActionButton(
        heroTag: 'wardrobe_fab',
        onPressed: () {
          Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddClothingScreen()),
          );
          // Liste provider'da zaten güncelleniyor
        },
        child: const Icon(Icons.add),
      ),
      body: provider.loading && all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && all.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(provider.error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => provider.loadAll(),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _chip('Tümü', _selectedCategory == null,
                              () => setState(() => _selectedCategory = null)),
                          for (final c in _categories(all))
                            _chip(categoryLabel(c), _selectedCategory == c,
                                () => setState(() => _selectedCategory = c)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${items.length} parça',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(
                              child: Text('Bu kategoride henüz parça yok'),
                            )
                          : RefreshIndicator(
                              onRefresh: () => provider.refresh(),
                              child: GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, i) =>
                                    ClothingCard(item: items[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}