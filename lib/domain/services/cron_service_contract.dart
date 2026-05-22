import '../models/cron_execution_result.dart';
import '../models/cron_job_config.dart';
import '../models/cron_list_page_result.dart';
import '../models/cron_wake_mode.dart';

/// Formal service contract for the SAIA cron scheduler.
///
/// Provides lifecycle management, job CRUD, pagination, and
/// wake modes for scheduled agent tasks.
abstract class CronServiceContract {
  /// Start the cron scheduler.
  Future<void> start();

  /// Stop the cron scheduler gracefully.
  Future<void> stop();

  /// Whether the scheduler is currently running.
  bool get isRunning;

  /// List all registered jobs.
  List<CronJobConfig> list();

  /// List jobs with pagination.
  CronListPageResult listPage({int offset = 0, int limit = 20});

  /// Add a new scheduled job.
  Future<void> add(CronJobConfig job);

  /// Update an existing job's configuration.
  Future<void> update(CronJobConfig job);

  /// Remove a job by ID.
  Future<void> remove(String jobId);

  /// Run a job immediately, regardless of schedule.
  Future<CronExecutionResult> run(String jobId);

  /// Enqueue a job for next available execution slot.
  Future<void> enqueue(String jobId);

  /// Wake the scheduler with the given mode.
  Future<void> wake(CronWakeMode mode, {String? text});

  /// Get the status of a specific job.
  CronJobConfig? getJob(String jobId);
}
