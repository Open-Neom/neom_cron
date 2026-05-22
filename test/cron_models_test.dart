// Tests for `CronWakeMode`, `CronExecutionResult`, `CronJobConfig`,
// `CronListPageResult`.

import 'package:test/test.dart';
import 'package:neom_cron/domain/models/cron_execution_result.dart';
import 'package:neom_cron/domain/models/cron_job_config.dart';
import 'package:neom_cron/domain/models/cron_list_page_result.dart';
import 'package:neom_cron/domain/models/cron_wake_mode.dart';

void main() {
  group('CronWakeMode', () {
    test('tiene 3 valores: timer, text, manual', () {
      expect(CronWakeMode.values, hasLength(3));
      expect(CronWakeMode.values, [
        CronWakeMode.timer,
        CronWakeMode.text,
        CronWakeMode.manual,
      ]);
    });
  });

  group('CronExecutionResult', () {
    test('default attemptNumber=1', () {
      final result = CronExecutionResult(
        jobId: 'j1',
        success: true,
        duration: const Duration(seconds: 5),
        executedAt: DateTime(2026, 1, 1),
      );
      expect(result.attemptNumber, 1);
      expect(result.output, isNull);
      expect(result.error, isNull);
    });

    test('error preservado', () {
      final result = CronExecutionResult(
        jobId: 'j1',
        success: false,
        duration: const Duration(seconds: 1),
        error: 'Timeout',
        executedAt: DateTime(2026),
        attemptNumber: 3,
      );
      expect(result.error, 'Timeout');
      expect(result.attemptNumber, 3);
      expect(result.success, isFalse);
    });
  });

  group('CronJobConfig', () {
    test('defaults', () {
      final job = CronJobConfig(
        id: 'j1',
        expression: '0 0 * * *',
        createdAt: DateTime(2026),
      );
      expect(job.description, '');
      expect(job.enabled, isTrue);
      expect(job.timeout, const Duration(minutes: 5));
      expect(job.maxRetries, 0);
      expect(job.metadata, isEmpty);
      expect(job.lastRunAt, isNull);
      expect(job.nextRunAt, isNull);
    });

    test('expression cron 5-field estándar', () {
      final job = CronJobConfig(
        id: 'j1',
        expression: '*/5 * * * *', // cada 5 minutos
        createdAt: DateTime(2026),
      );
      expect(job.expression, '*/5 * * * *');
    });

    test('metadata custom', () {
      final job = CronJobConfig(
        id: 'j1',
        expression: '0 0 * * *',
        metadata: const {'taskType': 'embedding', 'agentId': 'a1'},
        createdAt: DateTime(2026),
      );
      expect(job.metadata['taskType'], 'embedding');
      expect(job.metadata['agentId'], 'a1');
    });
  });

  group('CronListPageResult', () {
    test('lista vacía con hasMore=false', () {
      const result = CronListPageResult(
        jobs: [],
        offset: 0,
        limit: 10,
        total: 0,
        hasMore: false,
      );
      expect(result.jobs, isEmpty);
      expect(result.total, 0);
      expect(result.hasMore, isFalse);
    });

    test('paginación: offset=10, limit=5, total=20, hasMore=true', () {
      final result = CronListPageResult(
        jobs: [
          CronJobConfig(id: 'j1', expression: '* * * * *', createdAt: DateTime(2026)),
        ],
        offset: 10,
        limit: 5,
        total: 20,
        hasMore: true,
      );
      expect(result.offset, 10);
      expect(result.limit, 5);
      expect(result.total, 20);
      expect(result.hasMore, isTrue);
      expect(result.jobs, hasLength(1));
    });
  });
}
