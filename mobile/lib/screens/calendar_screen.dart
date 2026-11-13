import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/calendar.dart';
import 'package:dijital_dolap/models/week_plan.dart';
import 'package:dijital_dolap/providers/calendar_provider.dart';
import 'package:dijital_dolap/providers/weather_provider.dart';
import 'package:dijital_dolap/providers/week_plan_provider.dart';
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
      final city = context.read<WeatherProvider>().city;
      context.read<WeekPlanProvider>().load(
            latitude: city?.latitude,
            longitude: city?.longitude,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CalendarProvider>();
    final week = context.watch<WeekPlanProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Takvim')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEvent(context),
        icon: const Icon(Icons.event_available),
        label: const Text('Olay ekle'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final city = context.read<WeatherProvider>().city;
          await Future.wait([
            context.read<CalendarProvider>().loadAll(),
            context.read<WeekPlanProvider>().load(
                  latitude: city?.latitude,
                  longitude: city?.longitude,
                ),
          ]);
        },
        child: p.loading && p.events.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : p.error != null && p.events.isEmpty
                ? Center(child: Text('Hata: ${p.error}'))
                : _buildList(context, p, week),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    CalendarProvider p,
    WeekPlanProvider week,
  ) {
    final plans = week.plansSafe;
    if (p.events.isEmpty && plans.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Yaklaşan bir olay yok. Düğün, nişan veya özel bir\n'
                'gün için hatırlatıcı ekleyebilirsin.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: p.events.length + (plans.isNotEmpty ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (plans.isNotEmpty && i == 0) {
          return _WeekPlanSection(result: week.data!);
        }
        final index = i - (plans.isNotEmpty ? 1 : 0);
        return _EventTile(
          event: p.events[index],
          onEdit: () =>
              _editEvent(context, existing: p.events[index]),
        );
      },
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

/// Hafta planı: yaklaşan olaylar için hava + hazır set kartı.
class _WeekPlanSection extends StatelessWidget {
  const _WeekPlanSection({required this.result});
  final WeekPlanResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            'Önümüzdeki hafta',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final plan in result.plans.take(4))
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.weatherGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      plan.needsOuterwear
                          ? Icons.ac_unit
                          : Icons.event_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${plan.daysLeft} gün sonra: ${plan.title}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          if (plan.weatherHeadline != null)
                            Text(
                              plan.weatherHeadline!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Hazır set görselleri
                    Row(
                      children: [
                        for (final id in plan.itemIds)
                          if (_imagePathOf(result, id) != null)
                            Container(
                              margin: const EdgeInsets.only(left: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: _PlanThumb(_imagePathOf(result, id)!),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  plan.message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String? _imagePathOf(WeekPlanResult result, int id) {
    final img = result.item(id)?.imagePath;
    if (img == null || img.isEmpty) return null;
    return '${ApiClient.baseUrl}/'
        '${img.replaceAll('\\', '/').replaceFirst(RegExp('^/'), '')}';
  }
}

class _PlanThumb extends StatelessWidget {
  const _PlanThumb(this.url);
  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => Container(
        color: AppColors.chalk,
        child: const Icon(Icons.checkroom, size: 16, color: AppColors.slate),
      ),
    );
  }
}

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
              : AppColors.line.withValues(alpha: 0.7),
          width: insight != null && !insight.ready ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
