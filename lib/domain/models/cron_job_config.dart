/// Configuration for a scheduled cron job.
class CronJobConfig {
  /// Unique job identifier.
  final String id;

  /// Cron expression (5-field standard: min hour dom month dow).
  final String expression;

  /// Human-readable description.
  final String description;

  /// Whether the job is currently enabled.
  final bool enabled;

  /// Maximum execution time before timeout.
  final Duration timeout;

  /// Number of retry attempts on failure.
  final int maxRetries;

  /// Job metadata (task type, agent ID, etc.).
  final Map<String, dynamic> metadata;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last execution timestamp.
  final DateTime? lastRunAt;

  /// Next scheduled execution.
  final DateTime? nextRunAt;

  const CronJobConfig({
    required this.id,
    required this.expression,
    this.description = '',
    this.enabled = true,
    this.timeout = const Duration(minutes: 5),
    this.maxRetries = 0,
    this.metadata = const {},
    required this.createdAt,
    this.lastRunAt,
    this.nextRunAt,
  });
}
