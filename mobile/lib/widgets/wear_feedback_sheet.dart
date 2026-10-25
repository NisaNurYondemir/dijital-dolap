import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/wear_entry.dart';
import 'package:dijital_dolap/providers/wear_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

const wearOccasions = [
  'Okul',
  'İş',
  'Arkadaş',
  'Romantik',
  'Özel gün',
  'Spor',
  'Günlük',
];

/// Giyim kaydından sonra isteğe bağlı puan + amaç sorar.
/// "Atla" denirse kayıt puansız kalır; sonradan geçmişten puanlanabilir.
Future<void> showWearFeedbackSheet(
  BuildContext context,
  WearEntry entry,
) async {
  final provider = context.read<WearProvider>();
  var rating = entry.rating ?? 0;
  final occasionCtrl = TextEditingController(text: entry.occasion ?? '');

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bugün nasıldı?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'İstersen puan ver, istersen atla. Sonradan da puanlayabilirsin.',
                  style: TextStyle(fontSize: 13, color: AppColors.slate),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setSheet(() => rating = i),
                        iconSize: 34,
                        icon: Icon(
                          i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: i <= rating ? AppColors.thread : AppColors.slate,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: occasionCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Amaç / ortam',
                    hintText: 'okul, iş, arkadaş buluşması...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_note_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final occasion in wearOccasions)
                      ChoiceChip(
                        label: Text(occasion),
                        selected: occasionCtrl.text == occasion,
                        onSelected: (_) {
                          setSheet(() => occasionCtrl.text = occasion);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Atla'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  if (saved == true) {
    await provider.updateEntry(
      entry,
      rating: rating > 0 ? rating : null,
      occasion: occasionCtrl.text.trim(),
    );
  }
  occasionCtrl.dispose();
}
