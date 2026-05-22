/// Result of a cron job execution.
class CronExecutionResult {
  final String jobId;
  final bool success;
  final Duration duration;
  final String? output;
  final String? error;
  final DateTime executedAt;
  final int attemptNumber;

  const CronExecutionResult({
    required this.jobId,
    required this.success,
    required this.duration,
    this.output,
    this.error,
    required this.executedAt,
    this.attemptNumber = 1,
  });
}
