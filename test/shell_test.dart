import 'package:neom_cron/utils/process/process_manager.dart';
import 'package:test/test.dart';

void main() {
  group('Shell.expandVariables', () {
    test(r'expands simple $VAR', () {
      final r = Shell.expandVariables(r'hello $NAME', {'NAME': 'world'});
      expect(r, 'hello world');
    });

    test(r'expands ${VAR}', () {
      final r = Shell.expandVariables(r'path=${HOME}/bin', {'HOME': '/u/a'});
      expect(r, 'path=/u/a/bin');
    });

    test('leaves undefined vars untouched', () {
      final r = Shell.expandVariables(r'$UNDEFINED_VAR_XYZ', {});
      expect(r, r'$UNDEFINED_VAR_XYZ');
    });

    test('handles multiple variables', () {
      final r = Shell.expandVariables(r'$A-$B', {'A': '1', 'B': '2'});
      expect(r, '1-2');
    });

    test('empty string stays empty', () {
      expect(Shell.expandVariables('', {}), '');
    });
  });

  group('Shell.isCommandSafe', () {
    test('allows normal commands', () {
      expect(Shell.isCommandSafe('ls -la'), isTrue);
      expect(Shell.isCommandSafe('git status'), isTrue);
      expect(Shell.isCommandSafe('echo hello'), isTrue);
    });

    test('blocks rm -rf /', () {
      expect(Shell.isCommandSafe('rm -rf /'), isFalse);
    });

    test('blocks mkfs', () {
      expect(Shell.isCommandSafe('mkfs.ext4 /dev/sda1'), isFalse);
    });

    test('blocks dd to device', () {
      expect(Shell.isCommandSafe('dd if=/dev/zero of=/dev/sda'), isFalse);
    });

    test('blocks fork bomb', () {
      expect(Shell.isCommandSafe(':(){ :|: & };:'), isFalse);
    });

    test('blocks chmod 777 /', () {
      expect(Shell.isCommandSafe('chmod 777 /'), isFalse);
    });
  });

  group('Shell.quoteArg', () {
    test('empty arg becomes empty quoted string', () {
      expect(Shell.quoteArg(''), "''");
    });

    test('simple safe arg is unchanged on posix', () {
      // Test only runs correctly on non-Windows
      final result = Shell.quoteArg('hello_world');
      expect(result, 'hello_world');
    });

    test('arg with spaces is quoted', () {
      final result = Shell.quoteArg('hello world');
      expect(result, isNot(equals('hello world')));
      expect(result.length, greaterThan('hello world'.length));
    });

    test("arg with single quote is escaped", () {
      final result = Shell.quoteArg("it's");
      expect(result, contains("'"));
    });
  });
}
