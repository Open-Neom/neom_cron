/// Process execution and cron scheduling for Open Neom agents.
///
/// Run, pool, and pipe OS processes; schedule recurring tasks
/// with standard cron expressions.
///
/// ## Process execution
///
/// ```dart
/// import 'package:neom_cron/neom_cron.dart';
///
/// final pm = ProcessManager();
/// final result = await pm.run(ProcessConfig(
///   command: 'dart',
///   args: ['analyze'],
///   timeout: Duration(seconds: 30),
/// ));
/// print(result.isSuccess);
/// ```
///
/// ## Cron scheduling
///
/// ```dart
/// final scheduler = CronScheduler(processManager: pm);
///
/// scheduler.schedule(CronJob(
///   id: 'nightly-backup',
///   expression: CronExpression.parse('0 3 * * *'),
///   action: () async => runBackup(),
/// ));
///
/// scheduler.scheduleProcess(
///   id: 'health-check',
///   expression: CronExpression.parse('*/5 * * * *'),
///   config: ProcessConfig(command: 'curl', args: ['-s', 'http://localhost/health']),
/// );
///
/// scheduler.start();
/// ```
library neom_cron;

// ── Process execution ──
export 'utils/process/process_manager.dart';

// ── Cron scheduling ──
export 'utils/cron/cron_expression.dart';
export 'utils/cron/cron_scheduler.dart';
