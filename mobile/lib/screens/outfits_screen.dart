import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/providers/outfit_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<OutfitProvider>();
      p.loadSuggestions();
      p.loadAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kombinler'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Öneriler'),
            Tab(text: 'Kombinlerim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _SuggestionsTab(),
          _MyOutfitsTab(),
        ],
      ),
    );
  }
}

// ── Öneriler sekmesi ──────────────────────────────────────────────────────────

class _SuggestionsTab extends StatelessWidget {
  const _SuggestionsTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OutfitProvider>();

    if (p.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null) {
      return Center(child: Text('Hata: ${p.error}'));
    }
    if (p.suggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Öneri üretmek için dolabında en az bir üst ve bir alt giysi olmalı.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: p.suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) => _SuggestionCard(outfit: p.suggestions[i]),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kıyafet görselleri
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: outfit.clothes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _ClothingThumb(item: outfit.clothes[i]),
            ),
          ),
          const SizedBox(height: 10),
          // Uyum skoru
          if (outfit.scoreLabel.isNotEmpty)
            Text(outfit.scoreLabel,
                style: text.bodySmall
                    ?.copyWith(color: AppColors.thread, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          // Kaydet butonu
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Kombini Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final ids = outfit.clothes.map((c) => c.id).toList();
    try {
      await context.read<OutfitProvider>().saveOutfit(ids);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kombin kaydedildi!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }
}

// ── Kombinlerim sekmesi ───────────────────────────────────────────────────────

class _MyOutfitsTab extends StatelessWidget {
  const _MyOutfitsTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OutfitProvider>();

    if (p.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.outfits.isEmpty) {
      return const Center(child: Text('Henüz kaydedilmiş kombin yok.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: p.outfits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) => _SavedOutfitCard(outfit: p.outfits[i]),
    );
  }
}

class _SavedOutfitCard extends StatelessWidget {
  const _SavedOutfitCard({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.read<OutfitProvider>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: outfit.clothes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _ClothingThumb(item: outfit.clothes[i]),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(outfit.displayName, style: text.titleMedium),
              ),
              // Favori
              IconButton(
                icon: Icon(
                  outfit.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: outfit.isFavorite ? Colors.redAccent : AppColors.slate,
                ),
                onPressed: () => p.toggleFavorite(outfit),
              ),
              // Giydim
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                color: AppColors.slate,
                onPressed: () async {
                  if (outfit.id != null) await p.logWear(outfit.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Giyim kaydedildi!')),
                    );
                  }
                },
              ),
              // Sil
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: AppColors.slate,
                onPressed: () async {
                  if (outfit.id != null) await p.deleteOutfit(outfit.id!);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ortak küçük görsel ────────────────────────────────────────────────────────

class _ClothingThumb extends StatelessWidget {
  const _ClothingThumb({required this.item});
  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.imagePath != null
        ? item.imageUrlFor(ApiClient.baseUrl)
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        height: 100,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorBuilder: (_, __, ___) => _placeholder(item.color),
              )
            : _placeholder(item.color),
      ),
    );
  }

  Widget _placeholder(Color? color) {
    return Container(
      color: color ?? AppColors.line,
      child: const Icon(Icons.checkroom, color: Colors.white54),
    );
  }
}