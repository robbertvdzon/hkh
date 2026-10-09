/// Nederlandse datumnotatie zonder extra pakket.
library;

const _weekdays = [
  'maandag',
  'dinsdag',
  'woensdag',
  'donderdag',
  'vrijdag',
  'zaterdag',
  'zondag',
];
const _weekdaysShort = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
const _months = [
  'januari',
  'februari',
  'maart',
  'april',
  'mei',
  'juni',
  'juli',
  'augustus',
  'september',
  'oktober',
  'november',
  'december',
];
const _monthsShort = [
  'jan',
  'feb',
  'mrt',
  'apr',
  'mei',
  'jun',
  'jul',
  'aug',
  'sep',
  'okt',
  'nov',
  'dec',
];

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];
String monthName(DateTime d) => _months[d.month - 1];
String monthShort(DateTime d) => _monthsShort[d.month - 1];

String _two(int n) => n.toString().padLeft(2, '0');

/// `14.00`
String formatTime(DateTime d) => '${_two(d.hour)}.${_two(d.minute)}';

/// `vrijdag 16 oktober 2026`
String formatLongDate(DateTime d) =>
    '${weekdayName(d)} ${d.day} ${monthName(d)} ${d.year}';

/// `16 oktober 2026`
String formatDate(DateTime d) => '${d.day} ${monthName(d)} ${d.year}';

/// `vr 16 okt`
String formatShortDate(DateTime d) =>
    '${weekdayShort(d)} ${d.day} ${monthShort(d)}';

/// `oktober 2026`
String formatMonthYear(DateTime d) => '${monthName(d)} ${d.year}';

/// Datum en tijd van een activiteit, bijvoorbeeld
/// `Vrijdag 16 oktober 2026, 14.00–16.00 uur` of
/// `Zaterdag 3 oktober t/m donderdag 22 oktober 2026`.
String formatActivityMoment({
  required DateTime start,
  DateTime? end,
  bool allDay = false,
}) {
  String capitalize(String s) => s[0].toUpperCase() + s.substring(1);
  final sameDay =
      end == null ||
      (end.year == start.year &&
          end.month == start.month &&
          end.day == start.day);
  if (!sameDay) {
    return '${capitalize(weekdayName(start))} ${start.day} ${monthName(start)} '
        't/m ${weekdayName(end)} ${end.day} ${monthName(end)} ${end.year}';
  }
  final date = capitalize(formatLongDate(start));
  if (allDay) return date;
  final time = end == null
      ? '${formatTime(start)} uur'
      : '${formatTime(start)}–${formatTime(end)} uur';
  return '$date, $time';
}
