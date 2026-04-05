/// Standard cron expression parser.
///
/// Supports 5-field cron format: `minute hour day month weekday`
///
/// Field values:
///   - `*`       — any value
///   - `*/n`     — every n-th value (step)
///   - `n`       — exact value
///   - `n-m`     — range (inclusive)
///   - `n,m,o`   — list of values
///
/// Shortcuts:
///   - `@yearly`   / `@annually`  → `0 0 1 1 *`
///   - `@monthly`                 → `0 0 1 * *`
///   - `@weekly`                  → `0 0 * * 0`
///   - `@daily`    / `@midnight`  → `0 0 * * *`
///   - `@hourly`                  → `0 * * * *`
///   - `@every_5m`               → `*/5 * * * *`
///   - `@every_15m`              → `*/15 * * * *`
///   - `@every_30m`              → `*/30 * * * *`
library;

/// Parsed cron expression that can test whether a [DateTime] matches.
class CronExpression {
  final Set<int> minutes;
  final Set<int> hours;
  final Set<int> daysOfMonth;
  final Set<int> months;
  final Set<int> daysOfWeek;
  final String raw;

  const CronExpression._({
    required this.minutes,
    required this.hours,
    required this.daysOfMonth,
    required this.months,
    required this.daysOfWeek,
    required this.raw,
  });

  /// Parse a cron expression string.
  ///
  /// Throws [FormatException] if the expression is invalid.
  factory CronExpression.parse(String expression) {
    final expr = expression.trim();

    // Handle shortcuts.
    final expanded = _shortcuts[expr];
    if (expanded != null) return CronExpression.parse(expanded);

    final parts = expr.split(RegExp(r'\s+'));
    if (parts.length != 5) {
      throw FormatException(
        'Cron expression must have 5 fields (minute hour day month weekday), '
        'got ${parts.length}: "$expr"',
      );
    }

    return CronExpression._(
      minutes: _parseField(parts[0], 0, 59, 'minute'),
      hours: _parseField(parts[1], 0, 23, 'hour'),
      daysOfMonth: _parseField(parts[2], 1, 31, 'day'),
      months: _parseField(parts[3], 1, 12, 'month'),
      daysOfWeek: _parseField(parts[4], 0, 7, 'weekday'), // 0 & 7 = Sunday
      raw: expr,
    );
  }

  /// Whether [dateTime] matches this cron expression.
  bool matches(DateTime dateTime) {
    // Normalize weekday: Dart uses 1=Mon..7=Sun, cron uses 0=Sun..6=Sat (7=Sun).
    final cronWeekday = dateTime.weekday == 7 ? 0 : dateTime.weekday;

    return minutes.contains(dateTime.minute) &&
        hours.contains(dateTime.hour) &&
        daysOfMonth.contains(dateTime.day) &&
        months.contains(dateTime.month) &&
        (daysOfWeek.contains(cronWeekday) || daysOfWeek.contains(7));
  }

  /// Returns the next [DateTime] at or after [from] that matches this expression.
  ///
  /// Searches up to [maxIterations] minutes ahead (default: 2 years).
  DateTime? nextAfter(DateTime from, {int maxIterations = 1051200}) {
    // Start from the next whole minute.
    var candidate = DateTime(
      from.year, from.month, from.day,
      from.hour, from.minute,
    ).add(const Duration(minutes: 1));

    for (var i = 0; i < maxIterations; i++) {
      if (matches(candidate)) return candidate;
      candidate = candidate.add(const Duration(minutes: 1));
    }
    return null; // No match found within range.
  }

  /// Returns the previous [DateTime] before [from] that matches this expression.
  DateTime? previousBefore(DateTime from, {int maxIterations = 1051200}) {
    var candidate = DateTime(
      from.year, from.month, from.day,
      from.hour, from.minute,
    ).subtract(const Duration(minutes: 1));

    for (var i = 0; i < maxIterations; i++) {
      if (matches(candidate)) return candidate;
      candidate = candidate.subtract(const Duration(minutes: 1));
    }
    return null;
  }

  /// Human-readable description of the schedule.
  String describe() {
    if (raw == '* * * * *') return 'every minute';
    if (raw == '0 * * * *') return 'every hour';
    if (raw == '0 0 * * *') return 'every day at midnight';
    if (raw == '0 0 * * 0') return 'every Sunday at midnight';
    if (raw == '0 0 1 * *') return 'first day of every month at midnight';
    if (raw == '0 0 1 1 *') return 'every January 1st at midnight';

    final buf = StringBuffer();

    if (minutes.length == 1) {
      buf.write('at minute ${minutes.first}');
    } else if (minutes.length < 60) {
      buf.write('at minutes ${minutes.join(", ")}');
    }

    if (hours.length == 1) {
      buf.write(' of ${hours.first}:00');
    } else if (hours.length < 24) {
      buf.write(' during hours ${hours.join(", ")}');
    }

    if (daysOfMonth.length < 31) {
      buf.write(' on day(s) ${daysOfMonth.join(", ")}');
    }

    if (months.length < 12) {
      buf.write(' in month(s) ${months.join(", ")}');
    }

    if (daysOfWeek.length < 8) {
      buf.write(' on weekday(s) ${daysOfWeek.join(", ")}');
    }

    final result = buf.toString().trim();
    return result.isEmpty ? raw : result;
  }

  @override
  String toString() => 'CronExpression($raw)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CronExpression && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  // -------------------------------------------------------------------------
  // Shortcuts
  // -------------------------------------------------------------------------

  static const _shortcuts = <String, String>{
    '@yearly': '0 0 1 1 *',
    '@annually': '0 0 1 1 *',
    '@monthly': '0 0 1 * *',
    '@weekly': '0 0 * * 0',
    '@daily': '0 0 * * *',
    '@midnight': '0 0 * * *',
    '@hourly': '0 * * * *',
    '@every_5m': '*/5 * * * *',
    '@every_15m': '*/15 * * * *',
    '@every_30m': '*/30 * * * *',
  };

  // -------------------------------------------------------------------------
  // Field parser
  // -------------------------------------------------------------------------

  static Set<int> _parseField(
    String field, int min, int max, String name,
  ) {
    final values = <int>{};

    for (final part in field.split(',')) {
      final trimmed = part.trim();

      if (trimmed == '*') {
        // Every value.
        for (var i = min; i <= max; i++) {
          values.add(i);
        }
        continue;
      }

      // Step: */n or n-m/s
      final stepMatch = RegExp(r'^(\*|\d+-\d+)/(\d+)$').firstMatch(trimmed);
      if (stepMatch != null) {
        final step = int.parse(stepMatch.group(2)!);
        if (step <= 0) {
          throw FormatException('Invalid step value in $name field: "$trimmed"');
        }

        int start = min;
        int end = max;
        final rangePart = stepMatch.group(1)!;
        if (rangePart != '*') {
          final range = rangePart.split('-');
          start = int.parse(range[0]);
          end = int.parse(range[1]);
        }

        for (var i = start; i <= end; i += step) {
          values.add(i);
        }
        continue;
      }

      // Range: n-m
      final rangeMatch = RegExp(r'^(\d+)-(\d+)$').firstMatch(trimmed);
      if (rangeMatch != null) {
        final start = int.parse(rangeMatch.group(1)!);
        final end = int.parse(rangeMatch.group(2)!);
        if (start > end) {
          throw FormatException(
            'Invalid range in $name field: $start > $end in "$trimmed"',
          );
        }
        for (var i = start; i <= end; i++) {
          values.add(i);
        }
        continue;
      }

      // Single value.
      final value = int.tryParse(trimmed);
      if (value == null) {
        throw FormatException(
          'Invalid value in $name field: "$trimmed"',
        );
      }
      if (value < min || value > max) {
        throw FormatException(
          '$name field value $value out of range ($min-$max)',
        );
      }
      values.add(value);
    }

    if (values.isEmpty) {
      throw FormatException('$name field resolved to empty set: "$field"');
    }

    return values;
  }
}
