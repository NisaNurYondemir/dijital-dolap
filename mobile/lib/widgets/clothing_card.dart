import 'package:flutter/material.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

class ClothingCard extends StatelessWidget {
  const ClothingCard({super.key, required this.item, this.onTap});

  final ClothingItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? AppColors.line;
    final isLight =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    final iconColor = isLight ? AppColors.ink : Colors.white;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: color,
                  child: item.imagePath != null
                      ? Image.network(item.imagePath!, fit: BoxFit.cover)
                      : Icon(Icons.checkroom, size: 48, color: iconColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.colorName ?? item.season,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}