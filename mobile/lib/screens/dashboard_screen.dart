import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';
import 'package:dijital_dolap/models/dashboard.dart';
import 'package:dijital_dolap/providers/dashboard_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

/// Dolap özeti: sayaçlar, mevsim/kategori dağılımı, en çok giyilenler,
/// hiç giyilmeyenler ve kısa Türkçe içgörüler.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DashboardProvider>();
    final d = p.data;

    return Scaffold(
      appBar: AppBar(title: const Text('Dolap Özeti')),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : p.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.error!),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => p.load(),
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                )
              : d == null
                  ? const SizedBox.shrink()
                  : _DashboardView(d),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView(this.d);

  final WardrobeDashboard d;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── İçgörüler ─────────────────────────────────────────────────────
          if (d.insightLines.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.weatherGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined,
                          size: 18, color: AppColors.thread),
                      const SizedBox(width: 6),
                      const Text(
                        'Dolabın hakkında',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...d.insightLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              line,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          // ── Sayaçlar ──────────────────────────────────────────────────────
          Row(
            children: [
              _Counter(d.totals.items, 'Parça'),
              const SizedBox(width: 10),
              _Counter(d.totals.wearable, 'Giyilebilir'),
              const SizedBox(width: 10),
              _Counter(d.totals.dirty, 'Yıkamada'),
              const SizedBox(width: 10),
              _Counter(d.totals.ironing, 'Ütü bekleyen'),
            ],
          ),
          const SizedBox(height: 18),
          // ── Mevsim dağılımı ───────────────────────────────────────────────
          _SectionTitle('Mevsime göre dağılım'),
          const SizedBox(height: 10),
          _SeasonBars(d.bySeason),
          const SizedBox(height: 18),
          // ── Amaç kullanımı ────────────────────────────────────────────────
          if (d.occasionUsage.isNotEmpty) ...[
            _SectionTitle('Nereye giyiyorsun?'),
            const SizedBox(height: 10),
            ...d.occasionUsage
                .map((o) => _OccasionRow(o, d.totals.wearTotal)),
            const SizedBox(height: 18),
          ],
          // ── En çok giyilenler ────────────────────────────────────────────
          if (d.topWorn.isNotEmpty) ...[
            _SectionTitle('En çok giydiğin parçalar'),
            const SizedBox(height: 10),
            ...d.topWorn.map((e) => _TopWornTile(e)),
            const SizedBox(height: 18),
          ],
          // ── Hiç giyilmeyenler ────────────────────────────────────────────
          if (d.neverWorn.isNotEmpty) ...[
            _SectionTitle('Hiç giymediğin parçalar'),
            const SizedBox(height: 10),
            ...d.neverWorn.map((e) => _NeverWornChip(e)),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.value, this.label);
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SeasonBars extends StatelessWidget {
  const _SeasonBars(this.data);
  final List<SeasonCount> data;

  @override
  Widget build(BuildContext context) {
    final max = data.fold<int>(1, (m, s) => m > s.count ? m : s.count);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (final s in data) ...[
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    kSeasonLabels[s.season] ?? s.season,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: s.count / max,
                      minHeight: 10,
                      backgroundColor: AppColors.chalk,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text('${s.count}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );

class _OccasionRow extends StatelessWidget {
  const _OccasionRow(this.usage, this.totalWears);
  final OccasionUsage usage;
  final int totalWears;

  @override
  Widget build(BuildContext context) {
    final ratio =
        totalWears > 0 ? (usage.wears / totalWears).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            usage.emoji != null && usage.emoji!.isNotEmpty
                ? Icons.label_outline
                : Icons.label_outline,
            size: 18,
            color: AppColors.slate,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(usage.name,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: AppColors.chalk,
                color: AppColors.thread,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              '${usage.wears} giyim${usage.avgRating != null ? ' · ★${usage.avgRating!.toStringAsFixed(1)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopWornTile extends StatelessWidget {
  const _TopWornTile(this.item);
  final WornItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: _ItemImage(item.imagePath),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryLabel(item.category),
                    style: Theme.of(context).textTheme.titleMedium),
                if (item.colorName != null &&
                    item.colorName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.colorName!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${item.wearCount} kez',
                  style: Theme.of(context).textTheme.titleMedium),
              if (item.avgRating != null)
                Text('★ ${item.avgRating!.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage(this.path);
  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.chalk,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.checkroom, color: AppColors.slate),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        '${ApiClient.baseUrl}/${path!.replaceAll('\\', '/').replaceFirst(RegExp('^/'), '')}',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.chalk,
          child: const Icon(Icons.broken_image_outlined,
              color: AppColors.slate),
        ),
      ),
    );
  }
}

class _NeverWornChip extends StatelessWidget {
  const _NeverWornChip(this.item);
  final NeverWornItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(width: 44, height: 44, child: _ItemImage(item.imagePath)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryLabel(item.category),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  item.daysInWardrobe != null
                      ? 'Dolabında ${item.daysInWardrobe} gündür ama hiç giymedin'
                      : 'Henüz hiç giyilmedi',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (item.dirtyOrIroning)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.local_laundry_service_outlined,
                  size: 18, color: Colors.orange.shade700),
            ),
        ],
      ),
    );
  }
}
