import 'package:flutter/material.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  // ⚠️ Şimdilik boş liste. Sonra provider'dan gelecek.
  final List<Outfit> _outfits = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kombinler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kombin oluşturma ekranı yakında')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Kombin oluştur',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _outfits.isEmpty
          ? const Center(child: Text('Henüz kombin yok'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _outfits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _OutfitCard(outfit: _outfits[i]),
            ),
    );
  }
}

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.outfit});

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
        children: [
          Row(
            children: [
              for (var i = 0; i < outfit.clothes.length; i++)
                Expanded(
                  child: Container(
                    height: 84,
                    margin: EdgeInsets.only(
                      right: i == outfit.clothes.length - 1 ? 0 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: outfit.clothes[i].color ?? AppColors.line,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.checkroom,
                      color: ThemeData.estimateBrightnessForColor(
                                  outfit.clothes[i].color ?? AppColors.line) ==
                              Brightness.light
                          ? AppColors.ink
                          : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(outfit.displayName, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${outfit.clothes.length} parça',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                outfit.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: outfit.isFavorite ? Colors.redAccent : AppColors.slate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}