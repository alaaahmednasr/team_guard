import 'dart:io';

import 'init.dart' as init_command;

Future<void> main(List<String> args) async {
  final separatorIndex = args.indexOf('--');
  final setupArgs =
      separatorIndex == -1 ? args : args.sublist(0, separatorIndex);

  if (setupArgs.contains('--help') || setupArgs.contains('-h')) {
    stdout.writeln('Usage: dart run team_guard:setup [-- <custom_lint args>]');
    stdout.writeln(
      'Runs team_guard:init first, then starts custom_lint in the same command.',
    );
    return;
  }

  final lintArgs = separatorIndex == -1
      ? const <String>[]
      : args.sublist(separatorIndex + 1);

  stdout.writeln('Running team_guard:init...');
  init_command.main(const []);
  if (exitCode != 0) {
    stderr.writeln('team_guard:init failed. Setup stopped.');
    return;
  }

  stdout.writeln('Running custom_lint...');
  final process = await Process.start(
    'dart',
    ['run', 'custom_lint', ...lintArgs],
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );

  exitCode = await process.exitCode;
}
