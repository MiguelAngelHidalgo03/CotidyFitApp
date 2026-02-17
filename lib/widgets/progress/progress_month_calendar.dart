import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme.dart';
import '../../utils/date_utils.dart';
import 'progress_section_card.dart';

class ProgressCalendarDayData {
  final int cf;
  final bool trained;

  const ProgressCalendarDayData({required this.cf, required this.trained});
}

class ProgressMonthCalendar extends StatelessWidget {
  const ProgressMonthCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.dataByDateKey,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPickMonthYear,
    required this.onDaySelected,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Map<String, ProgressCalendarDayData> dataByDateKey;

  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonthYear;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Calendario', style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ProgressSectionCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _Header(
                focusedDay: focusedDay,
                onPrev: onPrevMonth,
                onNext: onNextMonth,
                onPick: onPickMonthYear,
              ),
              const SizedBox(height: 10),
              TableCalendar(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2100, 12, 31),
                focusedDay: focusedDay,
                headerVisible: false,
                availableGestures: AvailableGestures.horizontalSwipe,
                startingDayOfWeek: StartingDayOfWeek.monday,
                daysOfWeekHeight: 22,
                rowHeight: 44,
                selectedDayPredicate: (d) {
                  final s = selectedDay;
                  if (s == null) return false;
                  return DateUtilsCF.isSameDay(d, s);
                },
                onDaySelected: (selected, _) => onDaySelected(DateUtilsCF.dateOnly(selected)),
                onPageChanged: (_) {},
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, _) => _DayCell(
                    day: day,
                    selected: false,
                    data: dataByDateKey[DateUtilsCF.toKey(day)],
                  ),
                  todayBuilder: (context, day, _) => _DayCell(
                    day: day,
                    selected: false,
                    isToday: true,
                    data: dataByDateKey[DateUtilsCF.toKey(day)],
                  ),
                  selectedBuilder: (context, day, _) => _DayCell(
                    day: day,
                    selected: true,
                    data: dataByDateKey[DateUtilsCF.toKey(day)],
                  ),
                  outsideBuilder: (context, day, _) => _DayCell(
                    day: day,
                    selected: false,
                    isOutside: true,
                    data: dataByDateKey[DateUtilsCF.toKey(day)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.focusedDay,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  final DateTime focusedDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final label = _monthYearLabel(focusedDay);

    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          color: CFColors.textSecondary,
          tooltip: 'Mes anterior',
        ),
        Expanded(
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: CFColors.textPrimary,
                        ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more, size: 18, color: CFColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          color: CFColors.textSecondary,
          tooltip: 'Mes siguiente',
        ),
      ],
    );
  }

  String _monthYearLabel(DateTime d) {
    const months = <String>[
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.data,
    this.isToday = false,
    this.isOutside = false,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool isOutside;
  final ProgressCalendarDayData? data;

  @override
  Widget build(BuildContext context) {
    final cf = data?.cf ?? 0;

    final baseBg = _backgroundForCf(cf);
    final baseBorder = _borderForCf(cf);

    final bg = selected ? Color.alphaBlend(CFColors.primary.withValues(alpha: 0.12), baseBg) : baseBg;
    final border = selected ? CFColors.primary : baseBorder;

    final opacity = isOutside ? 0.40 : 1.0;
    final textColor = _textColorForCf(cf, selected: selected);

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${day.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
            ),
            if (isToday)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: CFColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _backgroundForCf(int cf) {
    if (cf >= 80) return CFColors.primary;
    if (cf >= 40) return CFColors.primaryLight.withValues(alpha: 0.18);
    return CFColors.background;
  }

  Color _borderForCf(int cf) {
    if (cf >= 80) return CFColors.primary;
    if (cf >= 40) return CFColors.primaryLight.withValues(alpha: 0.55);
    return CFColors.softGray;
  }

  Color _textColorForCf(int cf, {required bool selected}) {
    if (cf >= 80) return Colors.white;
    if (selected) return CFColors.primary;
    if (cf >= 40) return CFColors.textPrimary;
    return CFColors.textSecondary;
  }
}
