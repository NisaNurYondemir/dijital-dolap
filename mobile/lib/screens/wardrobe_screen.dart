import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/widgets/clothing_card.dart';
import 'package:dijital_dolap/screens/add_clothing_screen.dart';
import 'package:dijital_dolap/screens/dashboard_screen.dart';
import 'package:dijital_dolap/screens/edit_clothing_screen.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';
import 'package:dijital_dolap/utils/error_text.dart';

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
    // Seçili kategoride parça kalmadıysa (düzenleme/silme sonrası) Tümü'ne dön
    final selected =
        _selectedCategory != null && all.any((i) => i.category == _selectedCategory)
            ? _selectedCategory
            : null;
    final items = selected == null
        ? all
        : all.where((i) => i.category == selected).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dolabım'),
        actions: [
          IconButton(
            tooltip: 'Dolap özeti',
            icon: const Icon(Icons.donut_small_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            ),
          ),
        ],
      ),
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
              ? _ErrorState(
                  message: friendlyError(provider.error),
                  onRetry: () => provider.loadAll(),
                )
              : all.isEmpty
                  ? _EmptyWardrobe(
                      onAdd: () => Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const AddClothingScreen(),
                        ),
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
                          _chip('Tümü', selected == null,
                              () => setState(() => _selectedCategory = null)),
                          for (final c in _categories(all))
                            _chip(categoryLabel(c), selected == c,
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
                              child: _EmptyHint(
                                icon: Icons.checkroom,
                                text: 'Bu kategoride henüz parça yok',
                              ),
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
                                itemBuilder: (context, i) => ClothingCard(
                                  item: items[i],
                                  onTap: () => Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditClothingScreen(item: items[i]),
                                    ),
                                  ),
                                ),
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

/// Hata + tekrar dene ekranı (offline/sunucu sorunları dahil).
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 44, color: AppColors.slate),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dolap tamamen boş: ilk parça ekleme çağrısı (onboarding).
class _EmptyWardrobe extends StatelessWidget {
  const _EmptyWardrobe({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.chalk,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.checkroom,
                  size: 40, color: AppColors.slate),
            ),
            const SizedBox(height: 16),
            Text(
              'Dolabın boş',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'İlk parçanı ekleyince uygulama renk uyumuna göre\n'
              'kombin önermeye başlar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('İlk parçanı ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Küçük boş durum ipucu (ikon + metin).
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 38, color: AppColors.slate),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}