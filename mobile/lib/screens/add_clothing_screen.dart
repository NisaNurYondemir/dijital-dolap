import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/analysis_result.dart';
import 'package:dijital_dolap/models/clothing_categories.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

class AddClothingScreen extends StatefulWidget {
  const AddClothingScreen({super.key});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final _colorNameCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _image; // seçilen orijinal fotoğraf
  AnalysisResult? _analysis; // analiz sonucu
  bool _analyzing = false;
  bool _saving = false;

  String _category = 'tshirt';
  String _season = 'tum';
  bool _isDirty = false;
  bool _needsIroning = false;
  bool _isIroned = false;

  @override
  void dispose() {
    _colorNameCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _analysis = null;
      });
      await _analyze();
    } catch (e) {
      if (mounted) _snack('Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) return;

    setState(() => _analyzing = true);
    final provider = context.read<ClothingProvider>();
    final bytes = await image.readAsBytes();
    final filename = image.path.split(Platform.pathSeparator).last;

    final result = await provider.analyzeImage(bytes, filename);
    if (!mounted) return;

    setState(() {
      _analyzing = false;
      if (result != null) {
        _analysis = result;
        _category = kCategoryLabels.containsKey(result.category)
            ? result.category
            : 'tshirt';
        _season = kSeasonLabels.containsKey(result.season) ? result.season : 'tum';
        _colorNameCtrl.text = result.colorName ?? '';
      }
    });

    if (result == null) {
      _snack(provider.error ?? 'Fotoğraf analiz edilemedi');
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _analysis = null;
      _colorNameCtrl.clear();
      _isDirty = false;
      _needsIroning = false;
      _isIroned = false;
    });
  }

  Future<void> _save() async {
    final analysis = _analysis;
    if (analysis == null) return;

    setState(() => _saving = true);
    final provider = context.read<ClothingProvider>();

    final created = await provider.createFromAnalysis(
      analysis: analysis,
      category: _category,
      season: _season,
      colorName: _colorNameCtrl.text.trim().isEmpty
          ? null
          : _colorNameCtrl.text.trim(),
      isDirty: _isDirty,
      needsIroning: _needsIroning,
      isIroned: _isIroned,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (created != null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eklendi: ${categoryLabel(created.category)}')),
      );
    } else {
      _snack(provider.error ?? 'Kaydedilemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni kıyafet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PhotoBox(
            image: _image,
            previewUrl: _analysis?.previewUrlFor(ApiClient.baseUrl),
            analyzing: _analyzing,
            onPickCamera: () => _pickImage(ImageSource.camera),
            onPickGallery: () => _pickImage(ImageSource.gallery),
            onClear: _reset,
          ),
          const SizedBox(height: 20),
          if (_image != null && !_analyzing && _analysis == null)
            OutlinedButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.refresh),
              label: const Text('Analizi tekrar dene'),
            ),
          if (_analysis != null) ..._buildForm(_analysis!),
        ],
      ),
    );
  }

  List<Widget> _buildForm(AnalysisResult analysis) {
    final color = analysis.color;
    return [
      Text('Kıyafet türü', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      if (analysis.candidates.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in analysis.candidates)
              if (c.category.isNotEmpty)
                ChoiceChip(
                  label: Text(
                    '${categoryLabel(c.category)} %${c.percent.toStringAsFixed(0)}',
                  ),
                  selected: _category == c.category,
                  onSelected: kCategoryLabels.containsKey(c.category)
                      ? (_) => setState(() => _category = c.category)
                      : null,
                ),
          ],
        ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey(_category),
        initialValue: _category,
        decoration: const InputDecoration(
          labelText: 'Tür',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.checkroom_outlined),
        ),
        items: [
          for (final e in kCategoryLabels.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => _category = v ?? _category),
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(
        key: ValueKey(_season),
        initialValue: _season,
        decoration: const InputDecoration(
          labelText: 'Mevsim',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.wb_sunny_outlined),
        ),
        items: [
          for (final e in kSeasonLabels.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => _season = v ?? _season),
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
              decoration: const InputDecoration(
                labelText: 'Renk adı',
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
        onChanged: (v) => setState(() => _isDirty = v),
        title: const Text('Kirli'),
        secondary: const Icon(Icons.local_laundry_service_outlined),
      ),
      SwitchListTile(
        value: _needsIroning,
        onChanged: (v) => setState(() => _needsIroning = v),
        title: const Text('Ütü gerekiyor'),
        secondary: const Icon(Icons.iron_outlined),
      ),
      if (_needsIroning)
        SwitchListTile(
          value: _isIroned,
          onChanged: (v) => setState(() => _isIroned = v),
          title: const Text('Ütülendi'),
          secondary: const Icon(Icons.check_circle_outline),
        ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
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
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: const Text('Vazgeç'),
      ),
    ];
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.image,
    required this.previewUrl,
    required this.analyzing,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onClear,
  });

  final File? image;
  final String? previewUrl;
  final bool analyzing;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_a_photo_outlined,
                    size: 48, color: AppColors.slate),
                const SizedBox(height: 12),
                const Text('Fotoğraf ekle'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onPickCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Kamera'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onPickGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeri'),
                    ),
                  ],
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (previewUrl != null)
                  Image.network(
                    previewUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Image.file(image!, fit: BoxFit.contain),
                  )
                else
                  Image.file(image!, fit: BoxFit.contain),
                if (analyzing)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text('Analiz ediliyor...',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                if (!analyzing)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: onClear,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}