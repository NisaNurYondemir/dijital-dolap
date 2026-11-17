import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/data/outfit_repository.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/models/wear_entry.dart';
import 'package:dijital_dolap/providers/calendar_provider.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/providers/wear_provider.dart';
import 'package:dijital_dolap/providers/weather_provider.dart';
import 'package:dijital_dolap/screens/laundry_screen.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/utils/error_text.dart';
import 'package:dijital_dolap/widgets/event_outfits_sheet.dart';
import 'package:dijital_dolap/widgets/mini_calendar.dart';

/// Ana Sayfa: mini takvim, son giyilen kombin, günün en iyi önerisi
/// ve kirli kıyafet özeti.
class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key, required this.onOpenSuggestions});

  /// "Daha fazla öneri gör" → Kombinler sekmesine geçiş.
  final VoidCallback onOpenSuggestions;

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  DateTime _selectedDay = _dayOf(DateTime.now());
  List<Outfit>? _suggestions;
  String? _suggestionsError;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadAll();
      context.read<ClothingProvider>().loadAll();
      context.read<WearProvider>().load();
      _loadSuggestions();
    });
  }

  Future<void> _loadSuggestions() async {
    final city = context.read<WeatherProvider>().city;
    try {
      final res = await OutfitRepository().getSuggestions(
        latitude: city?.latitude,
        longitude: city?.longitude,
        city: city?.name,
      );
      if (!mounted) return;
      setState(() => _suggestions = res);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _suggestionsError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _suggestionsError = 'Bağlantı hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final clothing = context.watch<ClothingProvider>();
    final wear = context.watch<WearProvider>();

    final total = clothing.items.length;
    final dirtyItems =
        clothing.items.where((i) => i.isDirty).toList();

    final selectedDayEvents = calendar.events
        .where((e) => _dayOf(e.eventDate) == _selectedDay)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          context.read<CalendarProvider>().loadAll(),
          context.read<ClothingProvider>().loadAll(),
          context.read<WearProvider>().load(),
          _loadSuggestions(),
        ]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Mini takvim ──
            MiniCalendar(
              eventDates: calendar.events
                  .map((e) => _dayOf(e.eventDate))
                  .toSet(),
              initialDate: _selectedDay,
              onDaySelected: (d) => setState(() => _selectedDay = d),
            ),
            if (selectedDayEvents.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final e in selectedDayEvents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: e.id == null
                        ? null
                        : () => showEventOutfitsSheet(context, e),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.thread,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined,
                              size: 16, color: Colors.blueGrey.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'kombinler',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey.shade600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right,
                              size: 16, color: Colors.blueGrey.shade600),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),

            // ── Bugünün önerisi ──
            _SectionHeader(
              title: 'Bugünün önerisi',
              actionLabel: 'Daha fazla gör',
              onAction: widget.onOpenSuggestions,
            ),
            const SizedBox(height: 8),
            _BestSuggestionCard(
              suggestions: _suggestions,
              error: _suggestionsError,
            ),
            const SizedBox(height: 20),

            // ── Son giyilen kombin ──
            const _SectionHeader(title: 'Son giyilen kombin'),
            const SizedBox(height: 8),
            _LastWornCard(entries: wear.entries),
            const SizedBox(height: 20),

            // ── Kirli kıyafet durumu ──
            _SectionHeader(
              title: 'Kirli kıyafet durumu',
              actionLabel: 'Çamaşır',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LaundryScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _DirtySummary(
              dirtyCount: dirtyItems.length,
              total: total,
              dirtyItems: dirtyItems,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

// ── Günün önerisi ────────────────────────────────────────────────────────────

class _BestSuggestionCard extends StatelessWidget {
  const _BestSuggestionCard({required this.suggestions, required this.error});

  final List<Outfit>? suggestions;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _Card(
        child: Text(
          friendlyError(error),
          style: const TextStyle(color: AppColors.slate, fontSize: 13),
        ),
      );
    }
    final list = suggestions;
    if (list == null) {
      return const _Card(
        child: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (list.isEmpty) {
      return const _Card(
        child: Text(
          'Henüz öneri yok. Dolabına parça ekledikçe öneriler burada görünür.',
          style: TextStyle(color: AppColors.slate, fontSize: 13),
        ),
      );
    }
    final best = list.first;
    final ready = best.clothes.every((c) => c.isWearable);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in best.clothes.take(6))
                      _ItemPill(item: c),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            best.reasons.take(2).join(' · '),
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate,
                height: 1.35),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle : Icons.error_outline,
                size: 15,
                color: ready ? Colors.green.shade700 : Colors.orange.shade900,
              ),
              const SizedBox(width: 5),
              Text(
                ready ? 'Hepsi hazır' : 'Bazı parçalar hazırlanmalı',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ready ? Colors.green.shade700 : Colors.orange.shade900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemPill extends StatelessWidget {
  const _ItemPill({required this.item});

  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final ready = item.isWearable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ready ? Colors.grey.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check : Icons.error_outline,
            size: 13,
            color: ready ? Colors.green.shade700 : Colors.orange.shade900,
          ),
          const SizedBox(width: 4),
          Text(
            categoryLabel(item.category),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Son giyilen kombin ───────────────────────────────────────────────────────

class _LastWornCard extends StatelessWidget {
  const _LastWornCard({required this.entries});

  final List<WearEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _Card(
        child: Text(
          'Henüz giyim kaydı yok. Önerilerden "Giydim" ile kaydet.',
          style: TextStyle(color: AppColors.slate, fontSize: 13),
        ),
      );
    }
    final last = entries.first;
    final DateTime? wornAt = last.wornAt;
    String wornText;
    if (wornAt == null) {
      wornText = 'kaydedildi';
    } else {
      final diff = DateTime.now().difference(wornAt);
      if (diff.inDays == 0) {
        wornText = 'bugün giyildi';
      } else if (diff.inDays == 1) {
        wornText = 'dün giyildi';
      } else {
        wornText = '${diff.inDays} gün önce giyildi';
      }
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in last.clothes.take(6))
                      _WornPill(label: categoryLabel(c.category)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            wornText,
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _WornPill extends StatelessWidget {
  const _WornPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.thread,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

// ── Kirli kıyafet özeti ──────────────────────────────────────────────────────

class _DirtySummary extends StatelessWidget {
  const _DirtySummary({
    required this.dirtyCount,
    required this.total,
    required this.dirtyItems,
  });

  final int dirtyCount;
  final int total;
  final List<ClothingItem> dirtyItems;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: dirtyCount == 0
          ? const Text(
              'Kirli kıyafet yok. Dolabın hazır!',
              style: TextStyle(color: AppColors.slate, fontSize: 13),
            )
          : ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              shape: const Border(),
              title: Text(
                '$dirtyCount/$total kıyafet kirli',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
              subtitle: const Text(
                'Detay için dokun',
                style: TextStyle(fontSize: 12),
              ),
              children: [
                for (final item in dirtyItems.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.local_laundry_service_outlined,
                            size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${categoryLabel(item.category)}'
                            '${item.colorName != null ? ' · ${item.colorName}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${item.wearCountSinceWash} giyilme',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (dirtyItems.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${dirtyItems.length - 8} parça daha…',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}
