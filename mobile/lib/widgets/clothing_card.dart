import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

class ClothingCard extends StatelessWidget {
  const ClothingCard({super.key, required this.item, this.onTap});

  final ClothingItem item;
  final VoidCallback? onTap;

  /// Palet varsa ilk üç rengi küçük noktalar olarak gösterir.
  List<Widget> _paletteDots(Color fallback) {
    if (item.palette.isEmpty) {
      return [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: fallback,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
          ),
        ),
        const SizedBox(width: 6),
      ];
    }
    return [
      for (final p in item.palette.take(3)) ...[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: p.color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
          ),
        ),
        const SizedBox(width: 3),
      ],
      const SizedBox(width: 3),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? AppColors.line;
    final isLight =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    final iconColor = isLight ? AppColors.ink : Colors.white;
    final url = item.imageUrlFor(ApiClient.baseUrl);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  // Görsel varsa nötr zemin (arka planı silinmiş PNG net görünsün),
                  // yoksa kıyafetin rengi
                  color: url != null ? AppColors.chalk : color,
                  child: url != null
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(Icons.broken_image_outlined,
                                  size: 40, color: AppColors.slate),
                            ),
                          ),
                        )
                      : Icon(Icons.checkroom, size: 52, color: iconColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabel(item.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ..._paletteDots(color),
                        Expanded(
                          child: Text(
                            [
                              if (item.colorName != null) item.colorName!,
                              if (item.pattern != null &&
                                  item.pattern != 'duz' &&
                                  item.pattern != 'bilinmiyor')
                                patternLabel(item.pattern),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
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