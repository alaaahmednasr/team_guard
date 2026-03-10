import 'dart:io';

import 'package:team_guard/src/config_loader.dart';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('Usage: dart run team_guard:init');
    stdout.writeln(
      'Creates team_guard.yaml, configures custom_lint, and scaffolds replacement files in lib/core.',
    );
    return;
  }

  final configFile = WidgetGuardConfig.ensureConfigFile(Directory.current.path);
  if (configFile == null) {
    stderr.writeln(
      'Could not find a project root (pubspec.yaml) from: ${Directory.current.path}',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('team_guard.yaml is ready at: ${configFile.path}');

  final analysisOptionsFile = File(
    '${configFile.parent.path}${Platform.pathSeparator}analysis_options.yaml',
  );
  final setupResult = _ensureCustomLintPlugin(analysisOptionsFile);

  switch (setupResult) {
    case _AnalysisSetupResult.created:
      stdout.writeln(
        'Created analysis_options.yaml with custom_lint plugin at: ${analysisOptionsFile.path}',
      );
      break;
    case _AnalysisSetupResult.updated:
      stdout
          .writeln('Added custom_lint plugin to: ${analysisOptionsFile.path}');
      break;
    case _AnalysisSetupResult.alreadyConfigured:
      stdout.writeln(
        'analysis_options.yaml already contains custom_lint plugin.',
      );
      break;
    case _AnalysisSetupResult.failed:
      stderr.writeln(
        'Could not update analysis_options.yaml automatically. Add this manually:'
        '\n'
        'analyzer:\n'
        '  plugins:\n'
        '    - custom_lint',
      );
      exitCode = 1;
      break;
  }

  final config = WidgetGuardConfig.load(configFile.parent.path);
  final scaffoldResult =
      _createReplacementFiles(configFile.parent.path, config);
  if (scaffoldResult.createdFiles.isNotEmpty) {
    stdout.writeln('Created replacement files in lib/core:');
    for (final filePath in scaffoldResult.createdFiles) {
      stdout.writeln('- $filePath');
    }
  } else {
    stdout.writeln('No new replacement files were needed in lib/core.');
  }
}

enum _AnalysisSetupResult {
  created,
  updated,
  alreadyConfigured,
  failed,
}

_AnalysisSetupResult _ensureCustomLintPlugin(File file) {
  try {
    if (!file.existsSync()) {
      file.writeAsStringSync(
        'analyzer:\n'
        '  plugins:\n'
        '    - custom_lint\n',
      );
      return _AnalysisSetupResult.created;
    }

    final content = file.readAsStringSync();
    final lineBreak = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(RegExp(r'\r?\n'));

    if (_containsCustomLintPlugin(lines)) {
      return _AnalysisSetupResult.alreadyConfigured;
    }

    final analyzerIndex = _findKeyLineIndex(lines, 'analyzer');
    if (analyzerIndex == -1) {
      final updated = [
        ...lines,
        if (lines.isNotEmpty && lines.last.trim().isNotEmpty) '',
        'analyzer:',
        '  plugins:',
        '    - custom_lint',
      ].join(lineBreak);
      file.writeAsStringSync('$updated$lineBreak');
      return _AnalysisSetupResult.updated;
    }

    final analyzerIndent = _indentOf(lines[analyzerIndex]);
    final analyzerEnd = _blockEndIndex(lines, analyzerIndex, analyzerIndent);

    final pluginIndex = _findChildKeyLineIndex(
      lines,
      analyzerIndex + 1,
      analyzerEnd,
      analyzerIndent,
      'plugins',
    );

    if (pluginIndex != -1) {
      final pluginIndent = _indentOf(lines[pluginIndex]);
      final pluginEnd = _blockEndIndex(lines, pluginIndex, pluginIndent);
      lines.insert(pluginEnd, '${' ' * (pluginIndent + 2)}- custom_lint');
      final updated = lines.join(lineBreak);
      file.writeAsStringSync('$updated$lineBreak');
      return _AnalysisSetupResult.updated;
    }

    lines.insertAll(analyzerIndex + 1, [
      '${' ' * (analyzerIndent + 2)}plugins:',
      '${' ' * (analyzerIndent + 4)}- custom_lint',
    ]);

    final updated = lines.join(lineBreak);
    file.writeAsStringSync('$updated$lineBreak');
    return _AnalysisSetupResult.updated;
  } catch (_) {
    return _AnalysisSetupResult.failed;
  }
}

bool _containsCustomLintPlugin(List<String> lines) {
  for (final line in lines) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('-')) {
      continue;
    }

    var value = trimmed.substring(1).trim();
    if (value.length >= 2 &&
        ((value.startsWith("'") && value.endsWith("'")) ||
            (value.startsWith('"') && value.endsWith('"')))) {
      value = value.substring(1, value.length - 1);
    }

    if (value == 'custom_lint') {
      return true;
    }
  }
  return false;
}

int _findKeyLineIndex(List<String> lines, String key) {
  final pattern = RegExp('^\\s*$key\\s*:\\s*(#.*)?\$');
  for (var i = 0; i < lines.length; i++) {
    if (pattern.hasMatch(lines[i])) return i;
  }
  return -1;
}

int _findChildKeyLineIndex(
  List<String> lines,
  int start,
  int end,
  int parentIndent,
  String key,
) {
  final pattern = RegExp('^\\s*$key\\s*:\\s*(#.*)?\$');
  for (var i = start; i < end; i++) {
    final line = lines[i];
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final indent = _indentOf(line);
    if (indent <= parentIndent) {
      break;
    }
    if (pattern.hasMatch(line)) {
      return i;
    }
  }
  return -1;
}

int _blockEndIndex(List<String> lines, int start, int indent) {
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (_indentOf(line) <= indent) {
      return i;
    }
  }
  return lines.length;
}

int _indentOf(String line) => line.length - line.trimLeft().length;

class _ScaffoldResult {
  final List<String> createdFiles;

  const _ScaffoldResult({required this.createdFiles});
}

enum _ReplacementKind {
  widget,
  helperClass,
}

_ScaffoldResult _createReplacementFiles(
  String projectRoot,
  WidgetGuardConfig config,
) {
  final coreDir = Directory(
    '$projectRoot${Platform.pathSeparator}lib${Platform.pathSeparator}core',
  );
  coreDir.createSync(recursive: true);
  final isFlutterProject = _isFlutterProject(projectRoot);

  final replacements = <String, _ReplacementKind>{};

  for (final restriction in config.classes.values) {
    replacements.putIfAbsent(
      restriction.replacement,
      () => _ReplacementKind.helperClass,
    );
  }

  for (final restriction in config.widgets.values) {
    replacements[restriction.replacement] = _ReplacementKind.widget;
  }

  final createdFiles = <String>[];

  for (final entry in replacements.entries) {
    final replacement = entry.key.trim();
    if (replacement.isEmpty) continue;

    final fileName = '${_toSnakeCase(replacement)}.dart';
    final filePath = '${coreDir.path}${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    if (file.existsSync()) {
      continue;
    }

    final content = entry.value == _ReplacementKind.widget
        ? _widgetTemplate(replacement, isFlutterProject: isFlutterProject)
        : _classTemplate(replacement);

    file.writeAsStringSync(content);
    createdFiles.add(filePath);
  }

  return _ScaffoldResult(createdFiles: createdFiles);
}

String _toSnakeCase(String input) {
  if (input.isEmpty) return input;

  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && i > 0) {
      final previous = input[i - 1];
      final wasLower = previous.toLowerCase() == previous &&
          previous.toUpperCase() != previous;
      if (wasLower) {
        buffer.write('_');
      }
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

String _widgetTemplate(String className, {required bool isFlutterProject}) {
  if (!isFlutterProject) {
    return _classTemplate(className);
  }

  return "import 'package:flutter/widgets.dart';\n"
      '\n'
      'class $className extends StatelessWidget {\n'
      '  const $className({super.key});\n'
      '\n'
      '  @override\n'
      '  Widget build(BuildContext context) {\n'
      '    return const SizedBox.shrink();\n'
      '  }\n'
      '}\n';
}

String _classTemplate(String className) {
  return 'class $className {\n'
      '  const $className._();\n'
      '}\n';
}

bool _isFlutterProject(String projectRoot) {
  final pubspecFile = File('$projectRoot${Platform.pathSeparator}pubspec.yaml');
  if (!pubspecFile.existsSync()) return false;

  try {
    final content = pubspecFile.readAsStringSync();
    return RegExp(r'^\s*flutter\s*:', multiLine: true).hasMatch(content);
  } catch (_) {
    return false;
  }
}
