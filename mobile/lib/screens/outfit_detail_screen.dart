import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/outfit_repository.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/models/wear_entry.dart';
import 'package:dijital_dolap/providers/outfit_provider.dart';
import 'package:dijital_dolap/providers/wear_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/utils/error_text.dart';
import 'package:dijital_dolap/widgets/clothing_thumb.dart';
import 'package:dijital_dolap/widgets/wear_feedback_sheet.dart';

/// Bir kombinin detay sayfası: görseller, isim/açıklama, skor, amaç
/// grupları ve giyim geçmişi (tarih, puan, sıcaklık hissi, hava).
///
/// Kaydedilmemiş öneriler de açılabilir; onlarda geçmiş yerine
/// "kaydet" ipucu gösterilir.
class OutfitDetailScreen extends StatefulWidget {
  const OutfitDetailScreen({super.key, required this.outfit});

  final Outfit outfit;

  @override
  State<OutfitDetailScreen> createState() => _OutfitDetailScreenState();
}

class _OutfitDetailScreenState extends State<OutfitDetailScreen> {
  List<WearEntry>? _history;
  String? _error;

  late Outfit _outfit = widget.outfit;

  bool get _saved => _outfit.id != null;

  @override
  void initState() {
    super.initState();
    if (_saved) _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await OutfitRepository().getHistory(_outfit.id!);
      if (!mounted) return;
      setState(() => _history = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e.toString()));
    }
  }

  Future<void> _editDetails() async {
    final nameCtrl = TextEditingController(text: _outfit.name ?? '');
    final descCtrl = TextEditingController(text: _outfit.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kombini düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Kombin adı (isteğe bağlı)',
                hintText: 'Örn. Hafta içi okul',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: descCtrl,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
                hintText: 'Örn. Soğuk günler için montla iyi gider',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final updated = await context.read<OutfitProvider>().updateDetails(
          _outfit,
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _outfit = updated);
  }

  Future<void> _worn() async {
    final wear = context.read<WearProvider>();
    final entry = _saved
        ? await wear.log(outfitId: _outfit.id)
        : await wear.log(
            clothingIds: _outfit.clothes.map((c) => c.id).toList(),
          );
    if (!mounted) return;
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wear.error ?? 'Giyim kaydedilemedi')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Giyildi olarak işaretlendi!')),
    );
    await showWearFeedbackSheet(context, entry);
    if (mounted && _saved) _loadHistory();
  }

  Future<void> _toggleFavorite() async {
    if (!_saved) return;
    final updated = await context
        .read<OutfitProvider>()
        .toggleFavorite(_outfit);
    if (!mounted) return;
    setState(() => _outfit = updated);
  }

  /// Geçmişin sıcaklık hissi özeti.
  String get _comfortSummary {
    final entries = _history;
    if (entries == null) return '';
    final values = entries
        .map((e) => e.comfort)
        .whereType<int>()
        .toList();
    if (values.isEmpty) return '';
    final avg = values.reduce((a, b) => a + b) / values.length;
    if (avg <= -0.5) return 'Bu kombinde genelde üşüyorsun';
    if (avg >= 0.5) return 'Bu kombinde genelde sıcaklıyorsun';
    return 'Bu kombin genelde tam ayarında';
  }

  double? get _averageRating {
    final entries = _history;
    if (entries == null) return null;
    final rated = entries.where((e) => e.hasRating).toList();
    if (rated.isEmpty) return null;
    final total = rated.fold<int>(0, (sum, e) => sum + e.rating!);
    return total / rated.length;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        title: Text(_outfit.displayName),
        actions: [
          if (_saved)
            IconButton(
              tooltip: 'İsim / açıklama düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editDetails,
            ),
          if (_saved)
            IconButton(
              tooltip: _outfit.isFavorite
                  ? 'Favorilerden çıkar'
                  : 'Favorilere ekle',
              icon: Icon(
                _outfit.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _outfit.isFavorite ? Colors.redAccent : AppColors.slate,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
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
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _outfit.clothes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) =>
                        ClothingThumb(item: _outfit.clothes[i], height: 110),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_outfit.scoreLabel.isNotEmpty)
                      Text(
                        _outfit.scoreLabel,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.thread,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    for (final group in _outfit.groups)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                      ),
                  ],
                ),
                if (_outfit.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    _outfit.description!,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.slate,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _worn,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Giydim'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!_saved)
            Text(
              'Bu kombin henüz kaydedilmemiş. "Giydim" ile kaydedebilir veya '
              'kombinler ekranından kaydedip giyim geçmişini burada izleyebilirsin.',
              style: text.bodySmall?.copyWith(color: AppColors.slate),
            )
          else ...[
            Text('Giyim geçmişi', style: text.titleMedium),
            const SizedBox(height: 4),
            Builder(
              builder: (_) {
                final entries = _history;
                if (entries == null && _error == null) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (_error != null) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  );
                }
                final summary = <String>[
                  '${entries!.length} giyim',
                  if (_averageRating != null)
                    'ort. ${_averageRating!.toStringAsFixed(1)} puan',
                  if (_comfortSummary.isNotEmpty) _comfortSummary,
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.join(' · '),
                      style: text.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                    const SizedBox(height: 8),
                    if (entries.isEmpty)
                      Text(
                        'Bu kombin henüz giyilmemiş. Giydikçe geçmişi burada '
                        'göreceksin: tarih, verdiğin puan, sıcaklık hissi ve '
                        'o günkü hava.',
                        style: text.bodySmall?.copyWith(color: AppColors.slate),
                      )
                    else
                      for (final entry in entries)
                        _HistoryTile(entry: entry),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final WearEntry entry;

  String _date(DateTime? value) {
    if (value == null) return 'Tarih yok';
    final local = value.toLocal();
    return '${local.day}.${local.month}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final parts = <String>[
      if (entry.comfortLabel.isNotEmpty)
        '${entry.comfortEmoji} ${entry.comfortLabel}',
      if (entry.weatherTemp != null)
        '${entry.weatherTemp!.round()}°C'
            '${entry.weatherCondition != null ? ' ${entry.weatherCondition}' : ''}',
      if (entry.occasion?.isNotEmpty == true) entry.occasion!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _date(entry.wornAt),
                  style: text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (parts.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    parts.join(' · '),
                    style: text.bodySmall?.copyWith(color: AppColors.slate),
                  ),
                ],
                if (entry.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    '“${entry.note}”',
                    style: text.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entry.hasRating)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: AppColors.thread,
                ),
                Text(
                  '${entry.rating}',
                  style: text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
