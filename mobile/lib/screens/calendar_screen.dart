import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/calendar.dart';
import 'package:dijital_dolap/providers/calendar_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

/// Takvim sekmesi: yaklaşan kıyafet gerektiren olaylar + hazırlık uyarıları.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CalendarProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Takvim')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEvent(context),
        icon: const Icon(Icons.event_available),
        label: const Text('Olay ekle'),
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : p.error != null
              ? Center(child: Text('Hata: ${p.error}'))
              : p.events.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Yaklaşan bir olay yok. Düğün, nişan veya özel bir\n'
                          'gün için hatırlatıcı ekleyebilirsin.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: p.events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _EventTile(event: p.events[i], onEdit: () => _editEvent(
                              context, existing: p.events[i])),
                    ),
    );
  }

  Future<void> _editEvent(BuildContext context,
      {CalendarEvent? existing}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _EventDialog(existing: existing),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null
            ? 'Olay eklendi'
            : 'Olay güncellendi')),
      );
    }
  }
}

const _kinds = <String, String>{
  'dugun': 'Düğün',
  'nisan': 'Nişan',
  'kina': 'Kına',
  'nikah': 'Nikah',
  'mezuniyet': 'Mezuniyet',
  'ozel_gun': 'Özel gün',
  'sinav': 'Sınav',
  'bayram': 'Bayram',
  'dogum_gunu': 'Doğum günü',
  'genel': 'Genel',
};

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onEdit});

  final CalendarEvent event;
  final VoidCallback onEdit;

  String get _daysText {
    final diff = event.eventDate.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return '$diff gün sonra';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CalendarProvider>();
    final insights = p.insights
        .where((i) => i.eventId == event.id)
        .toList();
    final insight = insights.isEmpty ? null : insights.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: insight != null && !insight.ready
              ? Colors.red.shade300
              : AppColors.line,
          width: insight != null && !insight.ready ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${event.eventDate.day}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 18),
                ),
                Text(
                  _monthName(event.eventDate.month),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(event.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '$_daysText · ${_kinds[event.kind] ?? event.kind}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (insight != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    insight.message,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: insight.ready
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Sil',
            onPressed: () {
              if (event.id != null) {
                context.read<CalendarProvider>().delete(event.id!);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Düzenle',
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  String _monthName(int month) {
    if (month < 1 || month > 12) return '';
    return _months[month - 1];
  }
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({this.existing});

  final CalendarEvent? existing;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final TextEditingController _controller;
  late String _kind;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _controller = TextEditingController(text: existing?.title ?? '');
    // Takvime disiplinli durum oluşturmak için normalize edelim.
    _kind = _kinds.containsKey(existing?.kind) ? existing!.kind : 'genel';
    _date = existing?.eventDate ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, 18));
    }
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.length < 2) return;
    final provider = context.read<CalendarProvider>();
    final event = CalendarEvent(
      id: widget.existing?.id,
      title: title,
      kind: _kind,
      eventDate: _date,
      occasionGroupId: widget.existing?.occasionGroupId,
      note: widget.existing?.note,
    );
    final ok = widget.existing == null
        ? provider.create(event)
        : provider.update(event);
    ok.then((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Olay ekle' : 'Olayı düzenle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Olay başlığı'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Tür'),
            items: _kinds.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _kind = v ?? 'genel'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              '${_date.day}/${_date.month}/${_date.year}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.existing == null ? 'Ekle' : 'Kaydet'),
        ),
      ],
    );
  }
}
