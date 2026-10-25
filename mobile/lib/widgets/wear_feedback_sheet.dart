import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/wear_entry.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/providers/wear_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/widgets/occasion_group_dialog.dart';

/// Giyim kaydından sonra isteğe bağlı puan + amaç sorar.
/// "Atla" denirse kayıt olduğu gibi kalır; sonradan geçmişten düzenlenebilir.
Future<void> showWearFeedbackSheet(
  BuildContext context,
  WearEntry entry,
) async {
  final wear = context.read<WearProvider>();
  final occasions = context.read<OccasionProvider>();
  if (occasions.groups.isEmpty) {
    await occasions.load();
  }
  if (!context.mounted) return;

  var rating = entry.rating ?? 0;
  int? selectedGroupId = entry.occasionGroupId;
  if (selectedGroupId == null && entry.occasion != null) {
    final name = entry.occasion!.toLowerCase();
    for (final group in occasions.groups) {
      if (group.name.toLowerCase() == name) {
        selectedGroupId = group.id;
        break;
      }
    }
  }

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
          final groups = occasions.groups;
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
                          i <= rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: i <= rating
                              ? AppColors.thread
                              : AppColors.slate,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Amaç / ortam',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final group in groups)
                      ChoiceChip(
                        label: Text(group.label),
                        selected: selectedGroupId == group.id,
                        onSelected: (_) => setSheet(
                          () => selectedGroupId = group.id,
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Yeni grup'),
                      onPressed: () async {
                        final created = await showOccasionGroupDialog(ctx);
                        if (created != null) {
                          setSheet(() => selectedGroupId = created.id);
                        }
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
    final newRating = rating > 0 ? rating : null;
    if (newRating != entry.rating ||
        selectedGroupId != entry.occasionGroupId) {
      await wear.updateEntry(
        entry,
        rating: newRating,
        occasionGroupId: selectedGroupId,
      );
    }
  }
}
