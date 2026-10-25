import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/occasion_group.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

const occasionColors = [
  '#4C6FFF',
  '#22305A',
  '#F2B84B',
  '#E85D75',
  '#9B51E0',
  '#27AE60',
  '#5B6478',
  '#C2185B',
];

Color colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null
      ? const Color(0xFF5B6478)
      : Color(0xFF000000 | value);
}

String _friendlyError(String? raw) {
  if (raw == null) return 'Kaydedilemedi';
  if (raw.contains('409')) return 'Bu isimde bir grup zaten var';
  if (raw.contains('422')) return 'Grup adı geçersiz';
  return raw;
}

/// Yeni amaç grubu oluşturur veya mevcut grubu düzenler.
Future<OccasionGroup?> showOccasionGroupDialog(
  BuildContext context, {
  OccasionGroup? group,
}) {
  return showDialog<OccasionGroup>(
    context: context,
    builder: (_) => _OccasionGroupDialog(group: group),
  );
}

class _OccasionGroupDialog extends StatefulWidget {
  const _OccasionGroupDialog({this.group});

  final OccasionGroup? group;

  @override
  State<_OccasionGroupDialog> createState() => _OccasionGroupDialogState();
}

class _OccasionGroupDialogState extends State<_OccasionGroupDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emojiCtrl;
  late String _selectedColor;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group?.name ?? '');
    _emojiCtrl = TextEditingController(text: widget.group?.emoji ?? '');
    _selectedColor = widget.group?.colorHex ?? occasionColors.first;
  }

  @override
  void dispose() {
    // showDialog'ın future'ı rota kapanır kapanmaz döner; kapanış animasyonu
    // sürerken TextField hâlâ bu controller'ları kullanır. Bu yüzden controller
    // ömrü dialog State'ine bağlıdır, future tamamlanınca silinmez.
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Grup adı boş olamaz');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final provider = context.read<OccasionProvider>();
    final emoji = _emojiCtrl.text.trim();
    OccasionGroup? created;
    bool ok;

    if (widget.group == null) {
      created = await provider.create(
        name,
        emoji: emoji.isEmpty ? null : emoji,
        color: _selectedColor,
      );
      ok = created != null;
    } else {
      ok = await provider.update(
        widget.group!,
        name: name,
        emoji: emoji,
        color: _selectedColor,
      );
    }

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _saving = false;
        _error = _friendlyError(provider.error);
      });
      return;
    }

    // Klavyeyi ve metin seçim katmanını dialog kapanmadan önce kapat.
    FocusScope.of(context).unfocus();
    Navigator.pop(context, created ?? widget.group);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.group == null ? 'Yeni amaç grubu' : 'Grubu düzenle',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Grup adı',
                hintText: 'Örn. Düğün, Tatil, Spor',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _emojiCtrl,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Emoji (isteğe bağlı)',
                hintText: '🎓',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Renk',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in occasionColors)
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorFromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == hex
                              ? AppColors.ink
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _selectedColor == hex
                          ? Icon(
                              Icons.check,
                              size: 17,
                              color: colorFromHex(hex).computeLuminance() >
                                      0.55
                                  ? Colors.black87
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
