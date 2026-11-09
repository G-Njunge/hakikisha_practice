import 'package:flutter_test/flutter_test.dart';
import 'package:hakikisha/core/opening_hours.dart';

// Same cases as the Express server's pharmacyHours.test.ts. Times are UTC
// instants; Kigali is UTC+2.
void main() {
  DateTime utc(String iso) => DateTime.parse(iso);

  test('returns null when hours are missing or unparseable', () {
    expect(isOpenNow(null), isNull);
    expect(isOpenNow('call for hours'), isNull);
  });

  test('open mid-day on a Monday within Mon-Sat', () {
    // 2026-06-01 is a Monday; 08:00 UTC is 10:00 in Kigali.
    expect(isOpenNow('Mon-Sat 08:00-20:00', at: utc('2026-06-01T08:00:00Z')), isTrue);
  });

  test('closed on a Sunday for Mon-Sat hours', () {
    expect(isOpenNow('Mon-Sat 08:00-20:00', at: utc('2026-06-07T08:00:00Z')), isFalse);
  });

  test('closed before opening time', () {
    expect(isOpenNow('Mon-Sat 08:00-20:00', at: utc('2026-06-01T04:00:00Z')), isFalse);
  });

  test('opening time is inclusive, closing time exclusive', () {
    expect(isOpenNow('Mon-Sat 08:00-20:00', at: utc('2026-06-01T06:00:00Z')), isTrue);
    expect(isOpenNow('Mon-Sat 08:00-20:00', at: utc('2026-06-01T18:00:00Z')), isFalse);
  });

  test("'Daily' covers every day, and day names are case-insensitive", () {
    expect(isOpenNow('Daily 07:00-22:00', at: utc('2026-06-07T10:00:00Z')), isTrue);
    expect(isOpenNow('mon-sat 08:00-20:00', at: utc('2026-06-01T08:00:00Z')), isTrue);
  });

  test('uses Kigali time, not the device time zone, across midnight UTC', () {
    // Sunday 23:00 UTC is Monday 01:00 in Kigali: closed, but on Monday.
    expect(isOpenNow('Mon-Sat 00:30-02:00', at: utc('2026-06-07T23:00:00Z')), isTrue);
  });
}
