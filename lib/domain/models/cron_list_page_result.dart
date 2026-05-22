import 'cron_job_config.dart';

/// Paginated result for cron job listing.
class CronListPageResult {
  final List<CronJobConfig> jobs;
  final int offset;
  final int limit;
  final int total;
  final bool hasMore;

  const CronListPageResult({
    required this.jobs,
    required this.offset,
    required this.limit,
    required this.total,
    required this.hasMore,
  });
}
