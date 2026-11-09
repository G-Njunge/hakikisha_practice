// Parses the pharmacy hours format the seed data uses,
// "<Daily|Xxx-Yyy> HH:MM-HH:MM" (e.g. "Mon-Sat 08:00-20:00"), and says whether
// a pharmacy is open. Ported from the Express server's lib/pharmacyHours.ts.
// Anything unrecognised is unknown (null) rather than guessed at.

const _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
final _pattern = RegExp(r'^(daily|[a-z]{3}(?:-[a-z]{3})?)\s+(\d{2}):(\d{2})-(\d{2}):(\d{2})$', caseSensitive: false);

/// Hours are evaluated in Kigali local time (UTC+2 all year, no DST), as the
/// server did, since most seeded pharmacies are in Kigali.
const _kigaliOffset = Duration(hours: 2);

int? _dayIndex(String abbreviation) {
  final index = _days.indexOf(abbreviation.toLowerCase());
  return index == -1 ? null : index;
}

bool? isOpenNow(String? hours, {DateTime? at}) {
  if (hours == null) return null;
  final match = _pattern.firstMatch(hours.trim());
  if (match == null) return null;

  final dayPart = match.group(1)!.toLowerCase();
  int startDay;
  int endDay;
  if (dayPart == 'daily') {
    startDay = 0;
    endDay = 6;
  } else {
    final parts = dayPart.split('-');
    final start = _dayIndex(parts.first);
    final end = _dayIndex(parts.last);
    if (start == null || end == null) return null;
    startDay = start;
    endDay = end;
  }

  final startMinutes = int.parse(match.group(2)!) * 60 + int.parse(match.group(3)!);
  final endMinutes = int.parse(match.group(4)!) * 60 + int.parse(match.group(5)!);
  // No overnight ranges (e.g. 22:00-02:00) in the data, so none supported.
  if (startMinutes >= endMinutes) return null;

  final local = (at ?? DateTime.now()).toUtc().add(_kigaliOffset);
  final day = local.weekday % 7; // DateTime: Mon=1..Sun=7 → Sun=0..Sat=6
  final dayInRange = startDay <= endDay ? day >= startDay && day <= endDay : day >= startDay || day <= endDay;
  if (!dayInRange) return false;

  final minutesNow = local.hour * 60 + local.minute;
  return minutesNow >= startMinutes && minutesNow < endMinutes;
}
