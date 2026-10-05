import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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

  String _season = 'tum';
  bool _isDirty = false;
  bool _needsIroning = false;
  bool _isIroned = false;
  bool _saving = false;

  File? _image;

  static const _seasons = {
    'tum': 'Tüm mevsimler',
    'yaz': 'Yaz',
    'kis': 'Kış',
    'ilkbahar': 'İlkbahar',
    'sonbahar': 'Sonbahar',
  };

  @override
  void dispose() {
    _colorNameCtrl.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage(ImageSource source) async {
    try {
        final picked = await _picker.pickImage(source: source,
      // maxWidth ve imageQuality KESİNLİKLE OLMASIN
      );
    if (picked != null) {
      setState(() => _image = File(picked.path));
      }
    } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
      );
    }
    }
  }

  Future<void> _save() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir fotoğraf seç')),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<ClothingProvider>();

    final bytes = await _image!.readAsBytes();
    final filename = _image!.path.split(Platform.pathSeparator).last;

    final created = await provider.createWithImage(
      season: _season,
      colorName: _colorNameCtrl.text.trim().isEmpty
          ? null
          : _colorNameCtrl.text.trim(),
      imageBytes: bytes,
      filename: filename,
      isDirty: _isDirty,
      needsIroning: _needsIroning,
      isIroned: _isIroned,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (created != null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eklendi: ${created.category}'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Kaydedilemedi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni kıyafet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Fotoğraf alanı
          _ImagePickerBox(
            image: _image,
            onPickCamera: () => _pickImage(ImageSource.camera),
            onPickGallery: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(height: 20),

          // Sezon
          DropdownButtonFormField<String>(
            initialValue: _season,
            decoration: const InputDecoration(
              labelText: 'Sezon',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.wb_sunny_outlined),
            ),
            items: [
              for (final e in _seasons.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _season = v ?? 'tum'),
          ),
          const SizedBox(height: 20),

          // Renk adı (opsiyonel)
          TextFormField(
            controller: _colorNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Renk adı (opsiyonel)',
              hintText: 'Boş bırakırsan otomatik algılanır',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.palette_outlined),
            ),
          ),
          const SizedBox(height: 20),

          // Durumlar
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

          // Kaydet
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _saving
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Kaydediliyor...' : 'Kaydet',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kategori, yüklediğin fotoğraftan otomatik tahmin edilir.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  const _ImagePickerBox({
    required this.image,
    required this.onPickCamera,
    required this.onPickGallery,
  });

  final File? image;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
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
                Image.file(image!, fit: BoxFit.cover),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => onPickGallery(), // geçici, parent setState yapacak
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}