import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/providers/outfit_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/widgets/occasion_group_dialog.dart';

/// Kaydedilmiş bir kombini bir veya birden fazla amaç grubuna atar.
Future<void> showOccasionPicker(BuildContext context, Outfit outfit) async {
  if (outfit.id == null) return;

  final occasions = context.read<OccasionProvider>();
  if (occasions.groups.isEmpty) {
    await occasions.load();
  }
  if (!context.mounted) return;

  final selected = outfit.groups.map((g) => g.id).toSet();

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
                  'Amaç grupları',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bu kombini hangi ortamlarda giyersin? Birden fazla seçebilirsin.',
                  style: TextStyle(fontSize: 13, color: AppColors.slate),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (groups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Henüz grup yok. Aşağıdan yeni bir grup oluştur.',
                            style: TextStyle(color: AppColors.slate),
                          ),
                        ),
                      for (final group in groups)
                        CheckboxListTile(
                          value: selected.contains(group.id),
                          onChanged: (value) {
                            setSheet(() {
                              if (value == true) {
                                selected.add(group.id);
                              } else {
                                selected.remove(group.id);
                              }
                            });
                          },
                          title: Text(group.label),
                          secondary: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: group.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.slate,
                        ),
                        title: const Text('Yeni grup oluştur'),
                        onTap: () async {
                          final created = await showOccasionGroupDialog(ctx);
                          if (created != null) {
                            setSheet(() => selected.add(created.id));
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Vazgeç'),
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

  if (saved != true || !context.mounted) return;

  final outfits = context.read<OutfitProvider>();
  final ok = await outfits.setOccasions(outfit, selected.toList());
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Gruplar güncellendi'
            : (outfits.error ?? 'Gruplar güncellenemedi'),
      ),
    ),
  );
}
