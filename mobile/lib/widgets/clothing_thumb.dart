import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

/// Kıyafet fotoğrafının küçük, yuvarlak köşeli hâli.
class ClothingThumb extends StatelessWidget {
  const ClothingThumb({
    super.key,
    required this.item,
    this.width = 80,
    this.height = 100,
  });

  final ClothingItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url =
        item.imagePath != null ? item.imageUrlFor(ApiClient.baseUrl) : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                errorBuilder: (_, _, _) => _placeholder(item.color),
              )
            : _placeholder(item.color),
      ),
    );
  }

  Widget _placeholder(Color? color) {
    return Container(
      color: color ?? AppColors.line,
      child: const Icon(Icons.checkroom, color: Colors.white54),
    );
  }
}
