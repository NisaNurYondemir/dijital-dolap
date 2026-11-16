import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/data/outfit_repository.dart';
import 'package:dijital_dolap/models/calendar.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/utils/error_text.dart';

/// Bir olaya uygun kombinleri müsaitlik durumuyla listeler.
/// Kirli / ütü bekleyen parça içeren kombinler "hazır değil" rozetli
/// gösterilir; temiz kombinler "hazır" rozetli olur.
Future<void> showEventOutfitsSheet(
  BuildContext context,
  CalendarEvent event,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _EventOutfitsSheet(event: event),
  );
}

class _EventOutfitsSheet extends StatefulWidget {
  const _EventOutfitsSheet({required this.event});

  final CalendarEvent event;

  @override
  State<_EventOutfitsSheet> createState() => _EventOutfitsSheetState();
}

class _EventOutfitsSheetState extends State<_EventOutfitsSheet> {
  List<Outfit>? _suggestions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await OutfitRepository().getSuggestions(
        occasionId: widget.event.occasionGroupId,
      );
      if (!mounted) return;
      setState(() => _suggestions = res);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Bağlantı hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu olay için kombinler',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  widget.event.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body(controller)),
        ],
      ),
    );
  }

  Widget _body(ScrollController controller) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            friendlyError(_error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final list = _suggestions;
    if (list == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bu olay için öneri bulunamadı. Dolabına birkaç parça daha '
            'eklemek veya olaya amaç grubu seçmek yardımcı olabilir.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _SuggestionTile(outfit: list[i]),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.outfit});

  final Outfit outfit;

  String get _availabilityText {
    final unavailable = outfit.clothes.where((c) => !c.isWearable).toList();
    if (unavailable.isEmpty) return 'Hazır';
    final dirty = unavailable.where((c) => c.isDirty).length;
    final ironing = unavailable
        .where((c) => !c.isDirty && c.needsIroning && !c.isIroned)
        .length;
    final parts = <String>[
      if (dirty > 0) '$dirty parça yıkanmalı',
      if (ironing > 0) '$ironing parça ütü bekliyor',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final ready = outfit.clothes.every((c) => c.isWearable);
    final color = ready ? Colors.green.shade700 : Colors.orange.shade900;
    final bg = ready ? Colors.green.shade50 : Colors.orange.shade50;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ready ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1.2,
        ),
      ),
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
                    for (final c in outfit.clothes.take(5)) _ItemChip(item: c),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _availabilityText,
                  style: TextStyle(color: color, fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (outfit.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              outfit.reasons.take(2).join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.item});

  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final label = item.colorName ?? item.category;
    final ready = item.isWearable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ready ? Colors.grey.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.error_outline,
            size: 13,
            color: ready ? Colors.green.shade700 : Colors.orange.shade900,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
