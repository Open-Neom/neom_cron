import 'package:neom_cron/utils/cron/cron_expression.dart';
import 'package:test/test.dart';

void main() {
  group('CronExpression.parse', () {
    test('parses wildcard expression', () {
      final e = CronExpression.parse('* * * * *');
      expect(e.minutes.length, 60);
      expect(e.hours.length, 24);
      expect(e.daysOfMonth.length, 31);
      expect(e.months.length, 12);
      expect(e.daysOfWeek.length, 8); // 0-7
    });

    test('parses single values', () {
      final e = CronExpression.parse('30 14 1 6 3');
      expect(e.minutes, {30});
      expect(e.hours, {14});
      expect(e.daysOfMonth, {1});
      expect(e.months, {6});
      expect(e.daysOfWeek, {3});
    });

    test('parses ranges', () {
      final e = CronExpression.parse('0 9-17 * * 1-5');
      expect(e.hours, {9, 10, 11, 12, 13, 14, 15, 16, 17});
      expect(e.daysOfWeek, {1, 2, 3, 4, 5});
    });

    test('parses steps', () {
      final e = CronExpression.parse('*/15 * * * *');
      expect(e.minutes, {0, 15, 30, 45});
    });

    test('parses lists', () {
      final e = CronExpression.parse('0,15,30,45 * * * *');
      expect(e.minutes, {0, 15, 30, 45});
    });

    test('parses range with step', () {
      final e = CronExpression.parse('10-20/2 * * * *');
      expect(e.minutes, {10, 12, 14, 16, 18, 20});
    });

    test('parses shortcuts: @hourly', () {
      final e = CronExpression.parse('@hourly');
      expect(e.minutes, {0});
      expect(e.hours.length, 24);
    });

    test('parses shortcuts: @daily', () {
      final e = CronExpression.parse('@daily');
      expect(e.minutes, {0});
      expect(e.hours, {0});
    });

    test('parses shortcuts: @yearly', () {
      final e = CronExpression.parse('@yearly');
      expect(e.minutes, {0});
      expect(e.hours, {0});
      expect(e.daysOfMonth, {1});
      expect(e.months, {1});
    });

    test('trims whitespace', () {
      final e = CronExpression.parse('  0 0 1 1 *  ');
      expect(e.raw, '0 0 1 1 *');
    });

    test('throws on wrong number of fields', () {
      expect(() => CronExpression.parse('* * *'), throwsFormatException);
      expect(() => CronExpression.parse('* * * * * *'), throwsFormatException);
      expect(() => CronExpression.parse(''), throwsFormatException);
    });

    test('throws on out-of-range values', () {
      expect(() => CronExpression.parse('60 * * * *'), throwsFormatException);
      expect(() => CronExpression.parse('* 24 * * *'), throwsFormatException);
      expect(() => CronExpression.parse('* * 0 * *'), throwsFormatException);
      expect(() => CronExpression.parse('* * 32 * *'), throwsFormatException);
      expect(() => CronExpression.parse('* * * 13 *'), throwsFormatException);
    });

    test('throws on invalid range (start > end)', () {
      expect(() => CronExpression.parse('20-10 * * * *'), throwsFormatException);
    });

    test('throws on non-numeric value', () {
      expect(() => CronExpression.parse('abc * * * *'), throwsFormatException);
    });

    test('throws on step zero', () {
      expect(() => CronExpression.parse('*/0 * * * *'), throwsFormatException);
    });
  });

  group('CronExpression.matches', () {
    test('@daily matches midnight only', () {
      final e = CronExpression.parse('@daily');
      expect(e.matches(DateTime(2025, 6, 15, 0, 0)), isTrue);
      expect(e.matches(DateTime(2025, 6, 15, 0, 1)), isFalse);
      expect(e.matches(DateTime(2025, 6, 15, 12, 0)), isFalse);
    });

    test('weekday 0 and 7 both represent Sunday', () {
      final e0 = CronExpression.parse('0 0 * * 0');
      final e7 = CronExpression.parse('0 0 * * 7');
      // 2025-06-15 is a Sunday.
      final sunday = DateTime(2025, 6, 15, 0, 0);
      expect(e0.matches(sunday), isTrue);
      expect(e7.matches(sunday), isTrue);
    });

    test('weekday 1 matches Monday', () {
      final e = CronExpression.parse('0 0 * * 1');
      // 2025-06-16 is a Monday.
      expect(e.matches(DateTime(2025, 6, 16, 0, 0)), isTrue);
      expect(e.matches(DateTime(2025, 6, 15, 0, 0)), isFalse); // Sunday
    });
  });

  group('CronExpression.nextAfter', () {
    test('computes next midnight for @daily', () {
      final e = CronExpression.parse('@daily');
      final from = DateTime(2025, 6, 15, 23, 30);
      final next = e.nextAfter(from);
      expect(next, DateTime(2025, 6, 16, 0, 0));
    });

    test('next minute for */5 pattern', () {
      final e = CronExpression.parse('*/5 * * * *');
      final from = DateTime(2025, 1, 1, 10, 7);
      final next = e.nextAfter(from);
      expect(next, DateTime(2025, 1, 1, 10, 10));
    });

    test('returns null if maxIterations too low', () {
      final e = CronExpression.parse('0 0 29 2 *'); // Feb 29
      final next = e.nextAfter(DateTime(2025, 3, 1), maxIterations: 10);
      expect(next, isNull);
    });
  });

  group('CronExpression.previousBefore', () {
    test('computes previous midnight', () {
      final e = CronExpression.parse('@daily');
      final from = DateTime(2025, 6, 15, 12, 30);
      final prev = e.previousBefore(from);
      expect(prev, DateTime(2025, 6, 15, 0, 0));
    });
  });

  group('CronExpression equality', () {
    test('two identical expressions are equal', () {
      expect(
        CronExpression.parse('* * * * *'),
        equals(CronExpression.parse('* * * * *')),
      );
    });
  });
}
