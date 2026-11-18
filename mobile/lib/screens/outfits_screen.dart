import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/occasion_group.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/data/weather_repository.dart';
import 'package:dijital_dolap/models/weather.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/providers/outfit_provider.dart';
import 'package:dijital_dolap/providers/wear_provider.dart';
import 'package:dijital_dolap/providers/weather_provider.dart';
import 'package:dijital_dolap/screens/outfit_detail_screen.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/widgets/clothing_thumb.dart';
import 'package:dijital_dolap/widgets/occasion_picker_sheet.dart';
import 'package:dijital_dolap/utils/error_text.dart';
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

/// Hava şeridi: şehir seçiliyse günlük hava özetini gösterir, değilse
/// şehir seçme çağrısı yapar. Seçim sonrası _SuggestionsTab önerileri havayla yeniler.
class _WeatherBar extends StatelessWidget {
  const _WeatherBar({
    required this.onPick,
    required this.onClear,
    required this.onLocate,
  });

  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final info = weather.weather;

    final hasWeather = info != null || weather.error != null;
    if (!hasWeather) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: weather.gpsBusy ? null : onLocate,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(
                    weather.gpsBusy ? 'Konum alınıyor…' : 'Konumumu kullan',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: weather.loading || weather.gpsBusy ? null : onPick,
                  icon: const Icon(Icons.cloud_outlined, size: 18),
                  label: const Text(
                    'Şehri seç',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.weatherGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_iconFor(info), size: 22, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info != null
                      ? '${info.headline}${info.city != null ? ' — ${info.city}' : ''}'
                      : (weather.error ?? 'Hava bilgisi alınamadı'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (info != null && info.needsOuterwear)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Soğuk görünüyor; mont veya ceket iyi gelir',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onPick,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Değiştir'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white70),
            onPressed: onClear,
            tooltip: 'Hava önerisini kapat',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(WeatherInfo? info) {
    if (info == null) return Icons.wb_cloudy_outlined;
    final desc = info.description;
    if (desc.contains('kar')) return Icons.ac_unit;
    if (desc.contains('yağmur') || desc.contains('sağanak') ||
        desc.contains('çiseleme')) {
      return Icons.umbrella_outlined;
    }
    if (desc.contains('bulut') || desc.contains('kapalı')) {
      return Icons.cloud_outlined;
    }
    return Icons.wb_sunny_outlined;
  }
}

/// Şehir arama diyaloğu: yazı yazıldıkça Open-Meteo geocoding üzerinden
/// Türkiye şehirleri listeler; seçilen aday döner (null = iptal).
class CitySearchDialog extends StatefulWidget {
  const CitySearchDialog({super.key});

  @override
  State<CitySearchDialog> createState() => _CitySearchDialogState();
}

class _CitySearchDialogState extends State<CitySearchDialog> {
  final _controller = TextEditingController();
  final _client = WeatherRepository();

  List<CitySuggestion> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _client.searchCity(query.trim());
      setState(() => _results = results);
    } catch (_) {
      setState(() => _error = 'Şehir arama başarısız');
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şehir seç'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Örn. Eskişehir',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SizedBox(
                height: 260,
                child: _searching
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _error != null
                        ? Center(child: Text(_error!))
                        : _results.isEmpty
                            ? const Center(
                                child: Text(
                                  'Arama yap ya da şehir adı yaz — \n '
                                  'bulunan şehirler burada listelenir.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: _results.length,
                                itemBuilder: (_, i) {
                                  final city = _results[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(city.label),
                                    onTap: () => Navigator.of(context)
                                        .pop<CitySuggestion>(city),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
      ],
    );
  }
}

class _SuggestionsTab extends StatefulWidget {
  const _SuggestionsTab();

  @override
  State<_SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<_SuggestionsTab> {
  int? _selectedGroupId;
  CitySuggestion? _selectedCity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final occasions = context.read<OccasionProvider>();
      if (occasions.groups.isEmpty) occasions.load();
    });
  }

  void _selectGroup(int? groupId) {
    if (_selectedGroupId == groupId) return;
    setState(() => _selectedGroupId = groupId);
    _reloadSuggestions();
  }

  void _reloadSuggestions() {
    final city = _selectedCity;
    context.read<OutfitProvider>().loadSuggestions(
          occasionId: _selectedGroupId,
          latitude: city?.latitude,
          longitude: city?.longitude,
          city: city?.name,
        );
  }

  Future<void> _pickCity() async {
    final city = await showDialog<CitySuggestion>(
      context: context,
      builder: (_) => const CitySearchDialog(),
    );
    if (city == null || !mounted) return;
    setState(() => _selectedCity = city);
    final weather = context.read<WeatherProvider>();
    await weather.select(city);
    if (!mounted) return;
    _reloadSuggestions();
  }

  Future<void> _useDeviceLocation() async {
    final weather = context.read<WeatherProvider>();
    await weather.useDeviceLocation();
    if (!mounted) return;
    setState(() => _selectedCity = weather.city);
    _reloadSuggestions();
  }

  void _clearCity() {
    setState(() => _selectedCity = null);
    context.read<WeatherProvider>().clearCity();
    _reloadSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OutfitProvider>();
    final groups = context.watch<OccasionProvider>().groups;
    final selectedId = groups.any((g) => g.id == _selectedGroupId)
        ? _selectedGroupId
        : null;

    return Column(
      children: [
        _WeatherBar(
          onPick: _pickCity,
          onClear: _clearCity,
          onLocate: _useDeviceLocation,
        ),
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
                    onSelected: (_) => _selectGroup(null),
                  );
                }
                final group = groups[i - 1];
                return ChoiceChip(
                  label: Text(group.label),
                  selected: selectedId == group.id,
                  onSelected: (_) => _selectGroup(group.id),
                );
              },
            ),
          ),
        Expanded(
          child: p.suggestionsLoading
              ? const Center(child: CircularProgressIndicator())
              : p.suggestionsError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              friendlyError(p.suggestionsError),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => context
                                  .read<OutfitProvider>()
                                  .loadSuggestions(),
                              icon: const Icon(Icons.refresh_outlined,
                                  size: 18),
                              label: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : p.suggestions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              selectedId == null
                                  ? 'Öneri üretmek için dolabında en az bir üst ve bir alt giysi olmalı.'
                                  : 'Bu amaç için yeterli parça yok. Başka bir grup seçebilir veya Tümü’ne dönebilirsin.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: p.suggestions.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, i) =>
                              _SuggestionCard(outfit: p.suggestions[i]),
                        ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OutfitDetailScreen(outfit: outfit),
          ),
        );
      },
      child: Container(
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
          if (outfit.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reason in outfit.reasons)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.thread.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.thread.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: AppColors.thread,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // Aksiyonlar: Giydim (bir adımda kayıt + puan) / Kaydet / Beğendim
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _worn(context),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Giydim'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _save(context),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Kaydet'),
                ),
              ),
              IconButton(
                tooltip: 'Beğendim (favorilere ekle)',
                icon: const Icon(Icons.favorite_border),
                color: AppColors.slate,
                onPressed: () => _favorite(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Detay için dokun',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Öneriyi hemen giydim olarak kaydeder; puan/amaç geri bildirim açılır.
  Future<void> _worn(BuildContext context) async {
    final ids = outfit.clothes.map((c) => c.id).toList();
    final wear = context.read<WearProvider>();
    final entry = await wear.log(clothingIds: ids);
    if (!context.mounted) return;
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wear.error ?? 'Giyim kaydedilemedi')),
      );
      return;
    }
    // Puanlama ekranı hemen açılır; bildirim sadece onay verir
    // (bildirim butonu web'de güvenilir çalışmadığı için aksiyon yok).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Giyildi olarak işaretlendi!')),
    );
    await showWearFeedbackSheet(context, entry);
  }

  /// Beğendim: kombin favori olarak kaydedilir (tek hareketle).
  Future<void> _favorite(BuildContext context) async {
    final ids = outfit.clothes.map((c) => c.id).toList();
    try {
      await context.read<OutfitProvider>().saveOutfit(ids, isFavorite: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Favorilere eklendi!')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _save(BuildContext context) async {
    final ids = outfit.clothes.map((c) => c.id).toList();
    try {
      final created = await context.read<OutfitProvider>().saveOutfit(ids);
      if (!context.mounted) return;
      // Grup seçme ekranı hemen açılır; bildirim butonu web'de
      // güvenilir çalışmadığı için aksiyonsuz onay gösterilir.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kombin kaydedildi!')),
      );
      await showOccasionPicker(context, created);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
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
          child: p.outfitsLoading && p.outfits.isEmpty
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

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OutfitDetailScreen(outfit: outfit),
          ),
        );
      },
      child: Container(
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
          if (outfit.description?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              outfit.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ],
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

