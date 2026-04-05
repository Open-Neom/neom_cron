/// Cron-based task scheduler for Open Neom agents.
///
/// Registers tasks with cron expressions, evaluates them every minute,
/// and executes matching callbacks. Supports process execution via
/// [ProcessManager] integration.
///
/// ```dart
/// final scheduler = CronScheduler();
///
/// // Schedule a Dart callback.
/// scheduler.schedule(
///   CronJob(
///     id: 'cleanup',
///     expression: CronExpression.parse('0 3 * * *'),
///     action: () async => print('Running cleanup at 3am'),
///   ),
/// );
///
/// // Schedule a process.
/// scheduler.scheduleProcess(
///   id: 'backup',
///   expression: CronExpression.parse('0 */6 * * *'),
///   config: ProcessConfig(command: 'pg_dump', args: ['mydb']),
/// );
///
/// scheduler.start();
/// ```
library;

import 'dart:async';

import '../process/process_manager.dart';
import 'cron_expression.dart';

// ---------------------------------------------------------------------------
// CronJob
// ---------------------------------------------------------------------------

/// A scheduled task with a cron expression.
class CronJob {
  /// Unique identifier for this job.
  final String id;

  /// Cron expression determining when this job runs.
  final CronExpression expression;

  /// The async action to execute.
  final Future<void> Function() action;

  /// Optional human-readable description.
  final String? description;

  /// Whether to skip this execution if the previous one is still running.
  final bool skipIfRunning;

  /// Whether the job is enabled.
  bool enabled;

  /// Last time this job was executed.
  DateTime? lastRun;

  /// Next calculated execution time.
  DateTime? nextRun;

  /// Number of times this job has executed.
  int runCount = 0;

  /// Number of times this job has failed.
  int failCount = 0;

  /// Whether the job is currently executing.
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  CronJob({
    required this.id,
    required this.expression,
    required this.action,
    this.description,
    this.skipIfRunning = true,
    this.enabled = true,
  });

  @override
  String toString() =>
      'CronJob($id, ${expression.raw}, enabled=$enabled, runs=$runCount)';
}

// ---------------------------------------------------------------------------
// CronEvent
// ---------------------------------------------------------------------------

/// Events emitted by the scheduler.
sealed class CronEvent {
  final String jobId;
  final DateTime timestamp;
  const CronEvent(this.jobId, this.timestamp);
}

/// Emitted when a job starts executing.
class CronJobStarted extends CronEvent {
  const CronJobStarted(super.jobId, super.timestamp);
}

/// Emitted when a job completes successfully.
class CronJobCompleted extends CronEvent {
  final Duration duration;
  const CronJobCompleted(super.jobId, super.timestamp, this.duration);
}

/// Emitted when a job fails.
class CronJobFailed extends CronEvent {
  final Object error;
  final StackTrace? stackTrace;
  const CronJobFailed(super.jobId, super.timestamp, this.error, [this.stackTrace]);
}

/// Emitted when a job is skipped because it was still running.
class CronJobSkipped extends CronEvent {
  const CronJobSkipped(super.jobId, super.timestamp);
}

// ---------------------------------------------------------------------------
// CronScheduler
// ---------------------------------------------------------------------------

/// Evaluates registered [CronJob]s every minute and executes those that match.
class CronScheduler {
  final Map<String, CronJob> _jobs = {};
  Timer? _timer;
  bool _running = false;

  /// Optional [ProcessManager] for process-based jobs.
  final ProcessManager? processManager;

  final StreamController<CronEvent> _eventController =
      StreamController<CronEvent>.broadcast();

  /// Stream of scheduler events.
  Stream<CronEvent> get events => _eventController.stream;

  CronScheduler({this.processManager});

  /// Whether the scheduler tick loop is active.
  bool get isRunning => _running;

  /// All registered jobs.
  List<CronJob> get jobs => List.unmodifiable(_jobs.values);

  /// Number of registered jobs.
  int get jobCount => _jobs.length;

  // -------------------------------------------------------------------------
  // Job management
  // -------------------------------------------------------------------------

  /// Register a cron job. Replaces any existing job with the same [CronJob.id].
  void schedule(CronJob job) {
    job.nextRun = job.expression.nextAfter(DateTime.now());
    _jobs[job.id] = job;
  }

  /// Schedule a process to run on a cron schedule.
  ///
  /// Convenience method that wraps a [ProcessConfig] in a [CronJob].
  /// Requires a [ProcessManager] (passed in constructor or provided here).
  void scheduleProcess({
    required String id,
    required CronExpression expression,
    required ProcessConfig config,
    String? description,
    bool skipIfRunning = true,
    ProcessManager? manager,
    void Function(ProcessOutput result)? onResult,
  }) {
    final pm = manager ?? processManager;
    if (pm == null) {
      throw StateError(
        'No ProcessManager available. Pass one in the constructor or '
        'the scheduleProcess() call.',
      );
    }

    schedule(CronJob(
      id: id,
      expression: expression,
      description: description ?? 'Process: ${config.fullCommand}',
      skipIfRunning: skipIfRunning,
      action: () async {
        final result = await pm.run(config);
        onResult?.call(result);
      },
    ));
  }

  /// Remove a job by ID.
  CronJob? unschedule(String id) => _jobs.remove(id);

  /// Enable or disable a job.
  bool setEnabled(String id, bool enabled) {
    final job = _jobs[id];
    if (job == null) return false;
    job.enabled = enabled;
    return true;
  }

  /// Get a job by ID.
  CronJob? getJob(String id) => _jobs[id];

  /// Remove all jobs.
  void clear() => _jobs.clear();

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Start the scheduler.
  ///
  /// Ticks once per minute, aligned to the start of each minute.
  void start() {
    if (_running) return;
    _running = true;

    // Calculate delay to the start of the next minute.
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(minutes: 1));
    final delay = nextMinute.difference(now);

    // First tick at the next minute boundary, then every 60 seconds.
    Timer(delay, () {
      if (!_running) return;
      _tick();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    });
  }

  /// Stop the scheduler. Running jobs are not cancelled.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Manually trigger evaluation of all jobs (useful for testing).
  Future<void> tick() => _tick();

  /// Force-run a specific job regardless of its cron schedule.
  Future<void> runNow(String id) async {
    final job = _jobs[id];
    if (job == null) throw ArgumentError('Job "$id" not found');
    await _executeJob(job);
  }

  /// Dispose of resources.
  void dispose() {
    stop();
    _eventController.close();
  }

  // -------------------------------------------------------------------------
  // Status
  // -------------------------------------------------------------------------

  /// Summary of all jobs and their status.
  Map<String, Map<String, dynamic>> status() {
    final result = <String, Map<String, dynamic>>{};
    for (final job in _jobs.values) {
      result[job.id] = {
        'expression': job.expression.raw,
        'description': job.description,
        'enabled': job.enabled,
        'isRunning': job.isRunning,
        'lastRun': job.lastRun?.toIso8601String(),
        'nextRun': job.nextRun?.toIso8601String(),
        'runCount': job.runCount,
        'failCount': job.failCount,
      };
    }
    return result;
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  Future<void> _tick() async {
    final now = DateTime.now();

    for (final job in _jobs.values.toList()) {
      if (!job.enabled) continue;
      if (!job.expression.matches(now)) continue;

      // Avoid double-execution within the same minute.
      if (job.lastRun != null &&
          job.lastRun!.year == now.year &&
          job.lastRun!.month == now.month &&
          job.lastRun!.day == now.day &&
          job.lastRun!.hour == now.hour &&
          job.lastRun!.minute == now.minute) {
        continue;
      }

      if (job._isRunning && job.skipIfRunning) {
        _eventController.add(CronJobSkipped(job.id, now));
        continue;
      }

      // Fire and forget — don't block the tick loop.
      unawaited(_executeJob(job));
    }
  }

  Future<void> _executeJob(CronJob job) async {
    final now = DateTime.now();
    job._isRunning = true;
    job.lastRun = now;
    job.nextRun = job.expression.nextAfter(now);
    job.runCount++;
    _eventController.add(CronJobStarted(job.id, now));

    final sw = Stopwatch()..start();
    try {
      await job.action();
      sw.stop();
      _eventController.add(CronJobCompleted(job.id, DateTime.now(), sw.elapsed));
    } catch (e, st) {
      sw.stop();
      job.failCount++;
      _eventController.add(CronJobFailed(job.id, DateTime.now(), e, st));
    } finally {
      job._isRunning = false;
    }
  }
}
