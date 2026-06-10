import 'dart:io';
import 'package:yaml/yaml.dart';

class WidgetRestriction {
  final String replacement;
  final String? import;
  final String severity;
  final List<String> ignore;

  WidgetRestriction({
    required this.replacement,
    this.import,
    this.severity = 'info',
    this.ignore = const [],
  });
}

class WidgetGuardConfig {
  final Map<String, WidgetRestriction> widgets;
  final Map<String, WidgetRestriction> classes;
  final List<String> ignore;
  final String? projectRoot;

  WidgetGuardConfig({
    required this.widgets,
    required this.classes,
    required this.ignore,
    this.projectRoot,
  });

  WidgetRestriction? restrictionForSymbol(String symbolName) {
    final direct = widgets[symbolName] ?? classes[symbolName];
    if (direct != null) {
      return direct;
    }

    final normalized = _normalizeSymbol(symbolName);
    return _findByNormalized(widgets, normalized) ??
        _findByNormalized(classes, normalized);
  }

  static WidgetGuardConfig load(String startPath) {
    final file = ensureConfigFile(startPath);

    if (file == null || !file.existsSync()) {
      return WidgetGuardConfig(widgets: {}, classes: {}, ignore: [], projectRoot: null);
    }

    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! YamlMap) {
      return WidgetGuardConfig(widgets: {}, classes: {}, ignore: [], projectRoot: null);
    }

    final widgets = _parseRestrictionsMap(yaml['widgets']);
    final classes = _parseRestrictionsMap(yaml['classes']);
    final ignore = _parseIgnoreList(yaml['ignore'] ?? yaml['exclude']);
    final projectRoot = file.parent.absolute.path;

    return WidgetGuardConfig(
      widgets: widgets,
      classes: classes,
      ignore: ignore,
      projectRoot: projectRoot,
    );
  }

  static File? ensureConfigFile(String startPath) {
    return _findConfigFile(startPath) ?? _createDefaultConfig(startPath);
  }

  static File? _createDefaultConfig(String startPath) {
    final projectRoot = _findProjectRoot(startPath);
    if (projectRoot == null) return null;

    final file = File('${projectRoot.path}/team_guard.yaml');
    if (file.existsSync()) return file;

    try {
      file.writeAsStringSync(_defaultConfigTemplate);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Directory? _findProjectRoot(String startPath) {
    var current = Directory(startPath).absolute;

    while (true) {
      final pubspec = File('${current.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        return current;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        return null;
      }
      current = parent;
    }
  }

  static File? _findConfigFile(String startPath) {
    var current = Directory(startPath).absolute;

    while (true) {
      final candidate = File('${current.path}/team_guard.yaml');
      if (candidate.existsSync()) {
        return candidate;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        return null;
      }
      current = parent;
    }
  }

  static WidgetRestriction? _parseRestriction(Object? value) {
    if (value is YamlMap) {
      final replacement = value['replacement']?.toString();
      if (replacement == null || replacement.isEmpty) {
        return null;
      }

      return WidgetRestriction(
        replacement: replacement,
        import: value['import']?.toString(),
        severity: value['severity']?.toString().toLowerCase() ?? 'info',
        ignore: _parseIgnoreList(value['ignore'] ?? value['exclude']),
      );
    }

    if (value is String && value.isNotEmpty) {
      // Backward compatibility for simple shape:
      // widgets:
      //   Text: CustomText
      return WidgetRestriction(replacement: value);
    }

    return null;
  }

  static Map<String, WidgetRestriction> _parseRestrictionsMap(Object? source) {
    if (source is! YamlMap) {
      return {};
    }

    final restrictions = <String, WidgetRestriction>{};
    for (final entry in source.entries) {
      final key = entry.key.toString();
      final restriction = _parseRestriction(entry.value);
      if (restriction == null) continue;
      restrictions[key] = restriction;
    }
    return restrictions;
  }

  static WidgetRestriction? _findByNormalized(
    Map<String, WidgetRestriction> source,
    String normalizedSymbol,
  ) {
    for (final entry in source.entries) {
      if (_normalizeSymbol(entry.key) == normalizedSymbol) {
        return entry.value;
      }
    }
    return null;
  }

  static String _normalizeSymbol(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }

  bool isPathIgnored(String filePath) {
    return isPathMatchingPatterns(filePath, ignore);
  }

  bool isPathMatchingPatterns(String filePath, List<String> patterns) {
    if (projectRoot == null || patterns.isEmpty) return false;

    final normFile = filePath.replaceAll('\\', '/');
    var normRoot = projectRoot!.replaceAll('\\', '/');
    if (!normRoot.endsWith('/')) {
      normRoot += '/';
    }

    if (!normFile.startsWith(normRoot)) {
      return false;
    }

    final relativePath = normFile.substring(normRoot.length);

    for (final pattern in patterns) {
      if (_matchPattern(relativePath, pattern)) {
        return true;
      }
    }

    return false;
  }

  static bool _matchPattern(String relativePath, String pattern) {
    var glob = pattern.trim().replaceAll('\\', '/');
    if (glob.isEmpty) return false;

    // A leading '/' means it is relative to the root.
    final startsWithSlash = glob.startsWith('/');
    if (startsWithSlash) {
      glob = glob.substring(1);
    }

    // A trailing '/' means it is a directory pattern.
    final endsWithSlash = glob.endsWith('/');
    if (endsWithSlash) {
      glob = glob.substring(0, glob.length - 1);
    }

    final sb = StringBuffer();
    sb.write('^');

    // If the glob starts with '**/', we handle it at the start.
    final startsWithDoubleStarSlash = glob.startsWith('**/');
    if (startsWithDoubleStarSlash) {
      glob = glob.substring(3);
      sb.write('(?:^|.*/)');
    } else {
      // If the glob does not contain a slash, match anywhere in path (like gitignore).
      final hasSlash = glob.contains('/');
      if (!hasSlash && !startsWithSlash) {
        sb.write('(?:^|.*/)');
      }
    }

    var i = 0;
    while (i < glob.length) {
      if (i < glob.length - 1 && glob.substring(i, i + 2) == '**') {
        if (i > 0 && glob[i - 1] == '/' && i + 2 < glob.length && glob[i + 2] == '/') {
          sb.write('(?:.*/)?');
          i += 3; // Skip '**/'
          continue;
        }
        sb.write('.*');
        i += 2;
      } else if (glob[i] == '*') {
        sb.write('[^/]*');
        i++;
      } else if (glob[i] == '?') {
        sb.write('[^/]');
        i++;
      } else if (r'\/+*?{}.^$|()[]'.contains(glob[i])) {
        sb.write('\\${glob[i]}');
        i++;
      } else {
        sb.write(glob[i]);
        i++;
      }
    }

    if (endsWithSlash) {
      sb.write(r'(?:/.*)?$');
    } else {
      sb.write(r'$');
    }

    final regexStr = sb.toString();
    try {
      final regExp = RegExp(regexStr, caseSensitive: false);
      return regExp.hasMatch(relativePath);
    } catch (_) {
      return relativePath.toLowerCase().contains(glob.toLowerCase());
    }
  }

  static List<String> _parseIgnoreList(Object? source) {
    if (source == null) return [];
    if (source is YamlList) {
      return source.map((e) => e.toString()).toList();
    }
    if (source is List) {
      return source.map((e) => e.toString()).toList();
    }
    if (source is String) {
      return [source];
    }
    return [];
  }

  static const _defaultConfigTemplate = '''
widgets:
  Text:
    replacement: CustomText
    # import must be a package path only (no Dart import statement).
    # import: package:your_app/core/ui/custom_text.dart
    severity: error

  ElevatedButton:
    replacement: AppElevatedButton
    # import must be a package path only (no Dart import statement).
    # import: package:your_app/core/ui/buttons/app_elevated_button.dart
    severity: error

classes:
  Colors:
    replacement: AppColors
    # import must be a package path only (no Dart import statement).
    # import: package:your_app/core/theme/app_colors.dart
    severity: error

  Dio:
    replacement: AppDio
    # import must be a package path only (no Dart import statement).
    # import: package:your_app/core/network/app_dio.dart
    severity: error

  GetIt:
    replacement: AppLocator
    # import must be a package path only (no Dart import statement).
    # import: package:your_app/core/di/app_locator.dart
    severity: error

  Cubit:
    replacement: AppCubit
    # import must be a package path only (no Dart import statement).
    # import: package:your_app/core/state/app_cubit.dart
    severity: error
''';
}
