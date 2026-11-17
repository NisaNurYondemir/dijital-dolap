import 'package:flutter/material.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

/// Ay görünümünde mini takvim: olaylı günlerde nokta, bugün vurgulu,
/// seçili gün işaretli. Ana sayfa ve takvim sayfası ortak kullanır.
class MiniCalendar extends StatefulWidget {
  const MiniCalendar({
    super.key,
    required this.eventDates,
    this.onDaySelected,
    this.initialDate,
  });

  /// Olay olan günler (saat sıfırlanmış yerel tarihler).
  final Set<DateTime> eventDates;

  final ValueChanged<DateTime>? onDaySelected;

  /// Başlangıçta seçili gün (varsayılan: bugün).
  final DateTime? initialDate;

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  late DateTime _month;
  DateTime? _selected;

  static const _monthNames = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.initialDate ?? now;
    _selected = _day(initial);
    _month = DateTime(initial.year, initial.month);
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday; // 1 = Pazartesi
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstWeekday - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          // Başlık: ay + gezinme
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left,
                onTap: () => setState(() => _month = DateTime(
                    _month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right,
                onTap: () => setState(() => _month = DateTime(
                    _month.year, _month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Gün başlıkları
          Row(
            children: [
              for (final d in const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'])
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Gün ızgarası
          ...List.generate((leading + daysInMonth + 6) ~/ 7, (rowIndex) {
            return Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(col, rowIndex, leading, daysInMonth,
                      today)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _cell(int col, int rowIndex, int leading, int daysInMonth,
      DateTime today) {
    final dayNumber = rowIndex * 7 + col - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox(height: 36);

    final date = DateTime(_month.year, _month.month, dayNumber);
    final isToday = date == today;
    final isSelected = date == _selected;
    final hasEvent = widget.eventDates.contains(date);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selected = date);
        widget.onDaySelected?.call(date);
      },
      child: SizedBox(
        height: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.ink
                    : isToday
                        ? AppColors.thread
                        : null,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.ink, width: 1.2)
                    : null,
              ),
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 4,
              height: 4,
              child: hasEvent
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: AppColors.slate),
    );
  }
}
