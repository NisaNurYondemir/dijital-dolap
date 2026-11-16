import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/laundry_repository.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/laundry.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/providers/laundry_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/utils/error_text.dart';

/// Çamaşır günü: kirli sepeti (seç-yıka) + kategori bazlı otomatik
/// kirli işaretleme ayarları.
class LaundryScreen extends StatefulWidget {
  const LaundryScreen({super.key});

  @override
  State<LaundryScreen> createState() => _LaundryScreenState();
}

class _LaundryScreenState extends State<LaundryScreen> {
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LaundryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final laundry = context.watch<LaundryProvider>();
    final items = context
        .watch<ClothingProvider>()
        .items
        .where((i) => i.isDirty)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Çamaşır')),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          context.read<LaundryProvider>().load(),
          context.read<ClothingProvider>().refresh(),
        ]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _DirtyBasket(
              items: items,
              selected: _selected,
              onToggle: (id) => setState(() {
                _selected.contains(id)
                    ? _selected.remove(id)
                    : _selected.add(id);
              }),
              onWashSelected: () => _wash(context, ids: _selected.toList()),
              onWashAll: () => _wash(context, all: true),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Otomatik kirli işaretleme'),
            const SizedBox(height: 8),
            const Text(
              'Giyilme sayısı eşiği dolan parça otomatik olarak kirli '
              'sepetine düşer. İstemediğin kategoride otomatik işaretlemeyi '
              'kapatabilirsin; parçaları her zaman manuel de işaretleyebilirsin.',
              style: TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 12),
            _RulesPanel(rules: laundry.rules),
          ],
        ),
      ),
    );
  }

  Future<void> _wash(
    BuildContext context, {
    List<int>? ids,
    bool all = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final clothing = context.read<ClothingProvider>();
    try {
      final washed = await LaundryRepository().wash(
        clothingIds: all ? null : ids,
        allDirty: all,
      );
      await clothing.refresh();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${washed.length} parça yıkandı olarak işaretlendi')),
      );
      setState(_selected.clear);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    );
  }
}

// ── Kirli sepeti ──────────────────────────────────────────────────────────────

class _DirtyBasket extends StatelessWidget {
  const _DirtyBasket({
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.onWashSelected,
    required this.onWashAll,
  });

  final List<ClothingItem> items;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final VoidCallback onWashSelected;
  final VoidCallback onWashAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Panel(
        child: Text('Kirli sepet boş. Dolabın tertemiz!'),
      );
    }

    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kirli sepeti',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              Text(
                '${items.length} parça',
                style: const TextStyle(color: AppColors.slate, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _DirtyTile(
                item: item,
                selected: selected.contains(item.id),
                onToggle: () => onToggle(item.id),
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: selected.isEmpty ? null : onWashSelected,
                  icon: const Icon(Icons.local_laundry_service_outlined,
                      size: 18),
                  label: Text('Seçilenleri yıkandı (${selected.length})'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onWashAll,
                child: const Text('Tümü'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirtyTile extends StatelessWidget {
  const _DirtyTile({
    required this.item,
    required this.selected,
    required this.onToggle,
  });

  final ClothingItem item;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = '${categoryLabel(item.category)}'
        '${item.colorName != null ? ' · ${item.colorName}' : ''}';
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(value: selected, onChanged: (_) => onToggle()),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${item.wearCountSinceWash} giyilme',
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Otomatik kirli kuralları ─────────────────────────────────────────────────

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({required this.rules});

  final List<LaundryRule> rules;

  @override
  Widget build(BuildContext context) {
    final laundry = context.read<LaundryProvider>();
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rules.length; i++) ...[
            _RuleTile(rule: rules[i], onSave: laundry.saveRule),
            if (i < rules.length - 1)
              const Divider(height: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.onSave});

  final LaundryRule rule;
  final Future<bool> Function(LaundryRule) onSave;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: rule.enabled,
      onChanged: (v) =>
          onSave(rule.copyWith(enabled: v, wearLimit: rule.wearLimit ?? 1)),
      title: Text(
        categoryLabel(rule.category),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: rule.enabled
          ? null
          : const Text('Manuel işaretleme', style: TextStyle(fontSize: 12)),
      secondary: rule.enabled
          ? DropdownButton<int?>(
              value: rule.wearLimit,
              hint: const Text('sınırsız', style: TextStyle(fontSize: 13)),
              items: [
                for (final n in [1, 2, 3, 4, 5])
                  DropdownMenuItem(value: n, child: Text('$n giyilme')),
                const DropdownMenuItem(
                  value: null,
                  child: Text('sınırsız'),
                ),
              ],
              onChanged: (v) => onSave(rule.copyWith(wearLimit: v)),
              underline: const SizedBox.shrink(),
            )
          : null,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
