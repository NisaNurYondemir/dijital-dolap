import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/data/outfit_repository.dart';
import 'package:dijital_dolap/models/calendar.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/screens/outfit_detail_screen.dart';
import 'package:dijital_dolap/utils/error_text.dart';
import 'package:dijital_dolap/widgets/clothing_thumb.dart';

/// Bir olaya uygun kombinleri listeler: önce o amaçla kaydedilmiş
/// kombinler (kombin kimliğiyle), sonra öneri motorunun adayları.
/// Kartlara fotoğraflarla gösterilir; tıklayınca kombin detay sayfası
/// (giyim geçmişi, puanlar, sıcaklık hissi) açılır.
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
  List<Outfit>? _saved;
  List<Outfit>? _suggestions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = OutfitRepository();
    try {
      final saved = await repo.getAll(occasionId: widget.event.occasionGroupId);
      if (!mounted) return;
      setState(() => _saved = saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
    try {
      final suggestions = await repo.getSuggestions(
        occasionId: widget.event.occasionGroupId,
      );
      if (!mounted) return;
      setState(() => _suggestions = suggestions);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
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
    if (_error != null && _saved == null && _suggestions == null) {
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
    if (_saved == null && _suggestions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final saved = _saved ?? const [];
    final suggestions = _suggestions ?? const [];
    if (saved.isEmpty && suggestions.isEmpty) {
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
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (saved.isNotEmpty) ...[
          _sectionLabel('Kaydedilmiş kombinler'),
          for (final outfit in saved) ...[
            _OutfitTile(outfit: outfit),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],
        if (suggestions.isNotEmpty) ...[
          _sectionLabel('Öneriler'),
          for (final outfit in suggestions) ...[
            _OutfitTile(outfit: outfit),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _OutfitTile extends StatelessWidget {
  const _OutfitTile({required this.outfit});

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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                    child: Text(
                      outfit.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _availabilityText,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: outfit.clothes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => ClothingThumb(
                    item: outfit.clothes[i],
                    width: 64,
                    height: 84,
                  ),
                ),
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
              const SizedBox(height: 4),
              Text(
                'Detay ve giyim geçmişi için dokun',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
