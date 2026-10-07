import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

/// Var olan bir kıyafetin bilgilerini düzenler (fotoğraf değişmez).
class EditClothingScreen extends StatefulWidget {
  const EditClothingScreen({super.key, required this.item});

  final ClothingItem item;

  @override
  State<EditClothingScreen> createState() => _EditClothingScreenState();
}

class _EditClothingScreenState extends State<EditClothingScreen> {
  late final TextEditingController _colorNameCtrl;
  late String _category;
  late String _season;
  late bool _isDirty;
  late bool _needsIroning;
  late bool _isIroned;

  bool _saving = false;
  bool _deleting = false;

  bool get _busy => _saving || _deleting;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _colorNameCtrl = TextEditingController(text: i.colorName ?? '');
    _category = i.category;
    _season = i.season;
    _isDirty = i.isDirty;
    _needsIroning = i.needsIroning;
    _isIroned = i.isIroned;
  }

  @override
  void dispose() {
    _colorNameCtrl.dispose();
    super.dispose();
  }

  /// Haritada olmayan bir değer (ör. eski "unknown" kayıtlar) varsa
  /// dropdown çökmesin diye o değeri de listeye ekler.
  List<DropdownMenuItem<String>> _menuItems(
    Map<String, String> labels,
    String current,
    String currentLabel,
  ) {
    return [
      for (final e in labels.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
      if (!labels.containsKey(current))
        DropdownMenuItem(value: current, child: Text(currentLabel)),
    ];
  }

  Future<void> _save() async {
    final provider = context.read<ClothingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    final name = _colorNameCtrl.text.trim();

    final updated = await provider.updateItem(widget.item.id, {
      'category': _category,
      'season': _season,
      'color_name': name.isEmpty ? null : name,
      'is_dirty': _isDirty,
      'needs_ironing': _needsIroning,
      'is_ironed': _needsIroning ? _isIroned : false,
    });

    if (!mounted) return;
    setState(() => _saving = false);

    if (updated != null) {
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Kıyafet güncellendi')));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Güncellenemedi')),
      );
    }
  }

  Future<void> _delete() async {
    final provider = context.read<ClothingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kıyafet silinsin mi?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sil',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    final ok = await provider.deleteItem(widget.item.id);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (ok) {
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Kıyafet silindi')));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Silinemedi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final url = item.imageUrlFor(ApiClient.baseUrl);
    final color = item.color;

    return Scaffold(
      appBar: AppBar(title: const Text('Kıyafeti düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.chalk,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: url != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 40, color: AppColors.slate),
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.checkroom,
                        size: 48, color: AppColors.slate),
                  ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            key: ValueKey('cat_$_category'),
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Tür',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.checkroom_outlined),
            ),
            items: _menuItems(kCategoryLabels, _category, categoryLabel(_category)),
            onChanged: _busy
                ? null
                : (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: ValueKey('season_$_season'),
            initialValue: _season,
            decoration: const InputDecoration(
              labelText: 'Mevsim',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.wb_sunny_outlined),
            ),
            items: _menuItems(kSeasonLabels, _season, _season),
            onChanged:
                _busy ? null : (v) => setState(() => _season = v ?? _season),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color ?? Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _colorNameCtrl,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Renk adı',
                    helperText: 'Renk önizlemesi fotoğraftan alınır',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.palette_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _isDirty,
            onChanged: _busy ? null : (v) => setState(() => _isDirty = v),
            title: const Text('Kirli'),
            secondary: const Icon(Icons.local_laundry_service_outlined),
          ),
          SwitchListTile(
            value: _needsIroning,
            onChanged: _busy ? null : (v) => setState(() => _needsIroning = v),
            title: const Text('Ütü gerekiyor'),
            secondary: const Icon(Icons.iron_outlined),
          ),
          if (_needsIroning)
            SwitchListTile(
              value: _isIroned,
              onChanged: _busy ? null : (v) => setState(() => _isIroned = v),
              title: const Text('Ütülendi'),
              secondary: const Icon(Icons.check_circle_outline),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Kaydediliyor...' : 'Kaydet',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline),
            label: Text(_deleting ? 'Siliniyor...' : 'Kıyafeti sil'),
          ),
        ],
      ),
    );
  }
}