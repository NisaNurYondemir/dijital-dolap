import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/occasion_group.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/models/outfit_score.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/providers/outfit_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/utils/error_text.dart';
import 'package:dijital_dolap/widgets/clothing_thumb.dart';

/// Kullanıcının kendi kombinini seçerek oluşturduğu ekran.
///
/// Seçim değiştikçe backend'den canlı uyum puanı alınır; böylece kullanıcı
/// kaydetmeden önce renk/desen ve seçtiyse etkinlik uyumunu görür.
class NewOutfitScreen extends StatefulWidget {
  const NewOutfitScreen({super.key});

  @override
  State<NewOutfitScreen> createState() => _NewOutfitScreenState();
}

class _NewOutfitScreenState extends State<NewOutfitScreen> {
  final Set<int> _selected = <int>{};
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _category;
  int? _occasionId;
  OutfitScore? _score;
  bool _scoreLoading = false;
  String? _scoreError;
  bool _saving = false;

  Timer? _debounce;
  int _evalToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clothing = context.read<ClothingProvider>();
      if (clothing.items.isEmpty) clothing.loadAll();
      final occasions = context.read<OccasionProvider>();
      if (occasions.groups.isEmpty) occasions.load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<String> _categories(List<ClothingItem> items) {
    final present = items.map((i) => i.category).toSet();
    final known = kCategoryLabels.keys.where(present.contains);
    final others = present.difference(kCategoryLabels.keys.toSet()).toList()
      ..sort();
    return [...known, ...others];
  }

  void _toggle(ClothingItem item) {
    setState(() {
      if (!_selected.remove(item.id)) {
        _selected.add(item.id);
      }
    });
    _scheduleEvaluation();
  }

  void _scheduleEvaluation() {
    _debounce?.cancel();
    if (_selected.length < 2) {
      _evalToken++;
      setState(() {
        _score = null;
        _scoreLoading = false;
        _scoreError = null;
      });
      return;
    }
    setState(() {
      _scoreLoading = true;
      _scoreError = null;
    });
    _debounce = Timer(const Duration(milliseconds: 250), _evaluate);
  }

  Future<void> _evaluate() async {
    final ids = _selected.toList();
    if (ids.length < 2) return;
    final token = ++_evalToken;
    final provider = context.read<OutfitProvider>();
    final result = await provider.evaluate(ids, occasionId: _occasionId);
    if (!mounted || token != _evalToken) return;
    setState(() {
      _score = result;
      _scoreLoading = false;
      _scoreError = result == null
          ? friendlyError(provider.error ?? 'Uyum puanı alınamadı')
          : null;
    });
  }

  Future<void> _save() async {
    if (_selected.length < 2 || _saving) return;
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      final description = _descCtrl.text.trim();
      final created = await context.read<OutfitProvider>().saveOutfit(
            _selected.toList(),
            occasionIds: _occasionId == null ? const [] : [_occasionId!],
            name: name.isEmpty ? null : name,
            description: description.isEmpty ? null : description,
          );
      if (!mounted) return;
      Navigator.of(context).pop<Outfit>(created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clothing = context.watch<ClothingProvider>();
    final occasions = context.watch<OccasionProvider>();
    final all = clothing.items;
    final categories = _categories(all);

    final selectedCategory =
        _category != null && all.any((i) => i.category == _category)
            ? _category
            : null;
    final shown = selectedCategory == null
        ? all
        : all.where((i) => i.category == selectedCategory).toList();

    final byId = {for (final item in all) item.id: item};
    final selectedItems = [
      for (final id in _selected)
        if (byId[id] != null) byId[id]!,
    ];

    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(title: const Text('Yeni kombin')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selected.length < 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'En az iki parça seçince puan hesaplanır.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _selected.length >= 2 && !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bookmark_add_outlined, size: 19),
                  label: Text(
                    _saving
                        ? 'Kaydediliyor…'
                        : 'Kombini kaydet (${_selected.length} parça)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: clothing.loading && all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : all.isEmpty
              ? _EmptyWardrobe(
                  error: clothing.error,
                  onRetry: () => clothing.loadAll(),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _scoreCard(theme),
                    const SizedBox(height: 16),
                    _selectedSection(theme, selectedItems),
                    const SizedBox(height: 16),
                    _detailsSection(theme, occasions.groups),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Parçalar',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          '${shown.length} parça',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _categoryChip('Tümü', selectedCategory == null,
                              () => setState(() => _category = null)),
                          for (final category in categories)
                            _categoryChip(
                              categoryLabel(category),
                              selectedCategory == category,
                              () => setState(() => _category = category),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Bu kategoride parça yok.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: shown.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.70,
                        ),
                        itemBuilder: (context, i) {
                          final item = shown[i];
                          return _PickCard(
                            item: item,
                            selected: _selected.contains(item.id),
                            onTap: () => _toggle(item),
                          );
                        },
                      ),
                  ],
                ),
    );
  }

  Widget _categoryChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _surface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  Widget _scoreCard(ThemeData theme) {
    if (_selected.length < 2) {
      return _surface(
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, color: AppColors.slate),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'İki veya daha fazla parça seç; renk, desen ve etkinlik '
                'uyumunu burada canlı gör.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    if (_scoreLoading && _score == null) {
      return _surface(
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Uyum puanı hesaplanıyor…'),
          ],
        ),
      );
    }
    if (_scoreError != null) {
      return _surface(
        child: Text(
          friendlyError(_scoreError),
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    final score = _score;
    if (score == null) return const SizedBox.shrink();

    final color = score.score >= 0.70
        ? Colors.green.shade700
        : score.score >= 0.50
            ? Colors.orange.shade800
            : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${score.percent}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score.levelLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      score.percentLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (score.breakdown.isNotEmpty)
                      Text(
                        score.breakdown,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_occasionId != null && score.occasionScore <= 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seçtiğin etkinlik için uygun olmayan parçalar var. '
                      'Yine de kaydedebilirsin; önerilerde bu kombin '
                      'kullanılmaz.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (score.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final reason in score.reasons.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 15, color: AppColors.slate),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reason,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _selectedSection(ThemeData theme, List<ClothingItem> items) {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Seçilen parçalar (${items.length})',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _selected.clear());
                    _scheduleEvaluation();
                  },
                  child: const Text('Temizle'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text(
              'Dolabından parça seçerek kombinini oluştur.',
              style: theme.textTheme.bodySmall,
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return Stack(
                    children: [
                      ClothingThumb(item: item, width: 82, height: 104),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _toggle(item),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailsSection(ThemeData theme, List<OccasionGroup> groups) {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kombin bilgileri', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Kombin adı (isteğe bağlı)',
              hintText: 'Örn. Hafta sonu şehir kombini',
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _descCtrl,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Açıklama (isteğe bağlı)',
              hintText: 'Örn. Beyaz sneaker ile daha rahat',
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            key: ValueKey('occasion-${_occasionId ?? 0}-${groups.length}'),
            initialValue: _occasionId ?? 0,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Etkinlik (isteğe bağlı)',
              helperText: 'Seçersen puan etkinlik uyumunu da kapsar',
            ),
            items: [
              const DropdownMenuItem<int>(
                value: 0,
                child: Text('Etkinlik yok'),
              ),
              for (final group in groups)
                DropdownMenuItem<int>(
                  value: group.id,
                  child: Text(group.label),
                ),
            ],
            onChanged: (value) {
              setState(() => _occasionId = value == 0 ? null : value);
              _scheduleEvaluation();
            },
          ),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ClothingItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.colorName != null) item.colorName!,
      if (item.pattern != null &&
          item.pattern != 'duz' &&
          item.pattern != 'bilinmiyor')
        patternLabel(item.pattern),
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClothingThumb(
                      item: item,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    if (selected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (!item.isWearable)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.isDirty ? 'Kirli' : 'Ütü gerek',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabel(item.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle.isEmpty ? 'Renk bilgisi yok' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _EmptyWardrobe extends StatelessWidget {
  const _EmptyWardrobe({this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checkroom_outlined,
                size: 46, color: AppColors.slate),
            const SizedBox(height: 12),
            Text(
              error == null
                  ? 'Kombin oluşturmak için önce dolabına parça eklemelisin.'
                  : friendlyError(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_outlined, size: 18),
                label: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
