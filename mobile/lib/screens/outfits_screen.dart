import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/occasion_group.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/providers/outfit_provider.dart';
import 'package:dijital_dolap/providers/wear_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/widgets/clothing_thumb.dart';
import 'package:dijital_dolap/widgets/occasion_picker_sheet.dart';
import 'package:dijital_dolap/widgets/wear_feedback_sheet.dart';

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
      separatorBuilder: (_, _) => const SizedBox(height: 14),
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
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClothingThumb(item: outfit.clothes[i]),
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
      final created = await context.read<OutfitProvider>().saveOutfit(ids);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kombin kaydedildi!'),
          action: SnackBarAction(
            label: 'Grupla',
            onPressed: () => showOccasionPicker(context, created),
          ),
        ),
      );
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

class _MyOutfitsTab extends StatefulWidget {
  const _MyOutfitsTab();

  @override
  State<_MyOutfitsTab> createState() => _MyOutfitsTabState();
}

class _MyOutfitsTabState extends State<_MyOutfitsTab> {
  int? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OutfitProvider>();
    final groups = context.watch<OccasionProvider>().groups;

    final selectedId = groups.any((g) => g.id == _selectedGroupId)
        ? _selectedGroupId
        : null;
    final outfits = selectedId == null
        ? p.outfits
        : p.outfits
            .where((o) => o.groups.any((g) => g.id == selectedId))
            .toList();

    return Column(
      children: [
        if (groups.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: groups.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return ChoiceChip(
                    label: const Text('Tümü'),
                    selected: selectedId == null,
                    onSelected: (_) =>
                        setState(() => _selectedGroupId = null),
                  );
                }
                final group = groups[i - 1];
                return ChoiceChip(
                  label: Text(group.label),
                  selected: selectedId == group.id,
                  onSelected: (_) =>
                      setState(() => _selectedGroupId = group.id),
                );
              },
            ),
          ),
        Expanded(
          child: p.loading && p.outfits.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : outfits.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          selectedId == null
                              ? 'Henüz kaydedilmiş kombin yok.'
                              : 'Bu grupta kombin yok. Kartlardaki "Grupla" ile ekleyebilirsin.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: outfits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, i) =>
                          _SavedOutfitCard(outfit: outfits[i]),
                    ),
        ),
      ],
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
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClothingThumb(item: outfit.clothes[i]),
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
                  if (outfit.id == null) return;
                  final wear = context.read<WearProvider>();
                  final entry = await wear.log(outfitId: outfit.id);
                  if (!context.mounted) return;
                  if (entry == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(wear.error ?? 'Giyim kaydedilemedi'),
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Giyim kaydedildi!')),
                  );
                  await showWearFeedbackSheet(context, entry);
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
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final group in outfit.groups)
                _OutfitGroupChip(group: group),
              ActionChip(
                avatar: const Icon(Icons.local_offer_outlined, size: 15),
                label: Text(
                  outfit.groups.isEmpty ? 'Grupla' : 'Grupları düzenle',
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => showOccasionPicker(context, outfit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutfitGroupChip extends StatelessWidget {
  const _OutfitGroupChip({required this.group});

  final OccasionGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: group.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        group.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

