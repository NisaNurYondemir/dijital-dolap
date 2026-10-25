import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/wear_entry.dart';
import 'package:dijital_dolap/providers/wear_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/widgets/clothing_thumb.dart';
import 'package:dijital_dolap/widgets/wear_feedback_sheet.dart';

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _two(int value) => value.toString().padLeft(2, '0');

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Tarih yok';
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final clock = '${_two(local.hour)}:${_two(local.minute)}';

  if (day == today) return 'Bugün • $clock';
  if (day == today.subtract(const Duration(days: 1))) return 'Dün • $clock';
  return '${local.day} ${_months[local.month - 1]} ${local.year} • $clock';
}

class WearHistoryScreen extends StatefulWidget {
  const WearHistoryScreen({super.key});

  @override
  State<WearHistoryScreen> createState() => _WearHistoryScreenState();
}

class _WearHistoryScreenState extends State<WearHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WearProvider>().load();
    });
  }

  Future<void> _rate(WearEntry entry, int rating) async {
    final provider = context.read<WearProvider>();
    final ok = await provider.updateEntry(entry, rating: rating);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Puan kaydedildi' : (provider.error ?? 'Puan kaydedilemedi'),
        ),
      ),
    );
  }

  Future<void> _delete(WearEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kayıt silinsin mi?'),
        content: const Text('Bu giyim kaydı geçmişten kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<WearProvider>();
    final ok = await provider.delete(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Kayıt silindi' : (provider.error ?? 'Kayıt silinemedi'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WearProvider>();
    final entries = provider.entries;

    return Scaffold(
      appBar: AppBar(title: const Text('Giyim Geçmişi')),
      body: provider.loading && entries.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(provider.error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: provider.load,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                )
              : entries.isEmpty
                  ? const _EmptyHistory()
                  : RefreshIndicator(
                      onRefresh: provider.load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        children: [
                          _SummaryCard(provider: provider),
                          const SizedBox(height: 18),
                          ..._buildGroups(context, entries),
                        ],
                      ),
                    ),
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    List<WearEntry> entries,
  ) {
    final groups = <String, List<WearEntry>>{};
    for (final entry in entries) {
      final date = entry.wornAt?.toLocal();
      final key = date == null
          ? 'Tarihsiz'
          : '${_months[date.month - 1]} ${date.year}';
      groups.putIfAbsent(key, () => []).add(entry);
    }

    final widgets = <Widget>[];
    for (final group in groups.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            group.key,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.slate,
            ),
          ),
        ),
      );
      for (final entry in group.value) {
        widgets.add(
          _WearCard(
            entry: entry,
            onRate: (rating) => _rate(entry, rating),
            onEdit: () => showWearFeedbackSheet(context, entry),
            onDelete: () => _delete(entry),
          ),
        );
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(const SizedBox(height: 6));
    }
    return widgets;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.provider});

  final WearProvider provider;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = provider.entries.where((entry) {
      final date = entry.wornAt?.toLocal();
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
    final average = provider.averageRating;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _SummaryStat(value: '${provider.entries.length}', label: 'Giyim'),
          const _SummaryDivider(),
          _SummaryStat(value: '$thisMonth', label: 'Bu ay'),
          const _SummaryDivider(),
          _SummaryStat(
            value: average == null ? '–' : average.toStringAsFixed(1),
            label: 'Ort. puan',
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.line);
  }
}

class _WearCard extends StatelessWidget {
  const _WearCard({
    required this.entry,
    required this.onRate,
    required this.onEdit,
    required this.onDelete,
  });

  final WearEntry entry;
  final ValueChanged<int> onRate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDateTime(entry.wornAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (entry.occasion != null)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x33F2B84B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.occasion!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Düzenle / puanla',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 20, color: AppColors.slate),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Sil',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.slate),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entry.clothes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClothingThumb(
                item: entry.clothes[i],
                width: 64,
                height: 76,
              ),
            ),
          ),
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(entry.note!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => onRate(i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      i <= (entry.rating ?? 0)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 24,
                      color: i <= (entry.rating ?? 0)
                          ? AppColors.thread
                          : AppColors.slate,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '${entry.clothes.length} parça',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 64, color: AppColors.line),
            const SizedBox(height: 16),
            Text(
              'Henüz giyim kaydın yok',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kombinlerim sekmesinde bir kombinin altındaki '
              '"Giydim" ile ilk kaydını oluşturabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
