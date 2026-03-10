import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart'
    show ClassDeclaration, ConstructorName, NamedType;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'config_loader.dart';

class ForbiddenWidgetFix extends DartFix {
  static final Map<String, String?> _autoImportCache = {};

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    Object analysisError,
    List<Object> others,
  ) {
    final root = Directory(resolver.source.fullName).parent.parent.path;
    final config = WidgetGuardConfig.load(root);
    final projectRoot = _findProjectRoot(resolver.source.fullName) ?? root;
    final packageName = _readPackageName(projectRoot);
    final diagnostic = analysisError as dynamic;

    context.registry.addInstanceCreationExpression((node) {
      final typeNode = node.constructorName.type;
      final nameToken = typeNode.name;
      final symbolName = nameToken.lexeme;

      final restriction = config.restrictionForSymbol(symbolName);
      if (restriction == null) return;

      final matchesCurrentError = diagnostic.offset == nameToken.offset &&
          diagnostic.length == nameToken.length;
      if (!matchesCurrentError) return;

      final replacement = restriction.replacement;
      final importPath = _resolveImportPath(
        explicitImport: restriction.import,
        replacement: replacement,
        projectRoot: projectRoot,
        packageName: packageName,
      );
      final enclosingClassName =
          node.thisOrAncestorOfType<ClassDeclaration>()?.name.lexeme;

      if (enclosingClassName == replacement) {
        return;
      }

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Use $replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        if (importPath != null && importPath.isNotEmpty) {
          builder.importLibrary(Uri.parse(importPath));
        }

        builder.addSimpleReplacement(
          typeNode.sourceRange,
          replacement,
        );
      });
    });
    context.registry.addPrefixedIdentifier((node) {
      final className = node.prefix.name;
      final restriction = config.restrictionForSymbol(className);
      if (restriction == null) return;

      final nameToken = node.prefix.token;
      final matchesCurrentError = diagnostic.offset == nameToken.offset &&
          diagnostic.length == nameToken.length;
      if (!matchesCurrentError) return;

      final replacement = restriction.replacement;
      final importPath = _resolveImportPath(
        explicitImport: restriction.import,
        replacement: replacement,
        projectRoot: projectRoot,
        packageName: packageName,
      );
      final enclosingClassName =
          node.thisOrAncestorOfType<ClassDeclaration>()?.name.lexeme;
      if (enclosingClassName == replacement) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Use $replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        if (importPath != null && importPath.isNotEmpty) {
          builder.importLibrary(Uri.parse(importPath));
        }

        builder.addSimpleReplacement(
          node.prefix.sourceRange,
          replacement,
        );
      });
    });

    context.registry.addNamedType((node) {
      if (_isConstructorType(node)) {
        // Already handled by instance creation fix.
        return;
      }

      final nameToken = node.name;
      final symbolName = nameToken.lexeme;
      final restriction = config.restrictionForSymbol(symbolName);
      if (restriction == null) return;

      final matchesCurrentError = diagnostic.offset == nameToken.offset &&
          diagnostic.length == nameToken.length;
      if (!matchesCurrentError) return;

      final replacement = restriction.replacement;
      final importPath = _resolveImportPath(
        explicitImport: restriction.import,
        replacement: replacement,
        projectRoot: projectRoot,
        packageName: packageName,
      );
      final enclosingClassName =
          node.thisOrAncestorOfType<ClassDeclaration>()?.name.lexeme;
      if (enclosingClassName == replacement) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Use $replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        if (importPath != null && importPath.isNotEmpty) {
          builder.importLibrary(Uri.parse(importPath));
        }

        builder.addSimpleReplacement(
          node.name.sourceRange,
          replacement,
        );
      });
    });
  }

  String? _resolveImportPath({
    required String? explicitImport,
    required String replacement,
    required String projectRoot,
    required String? packageName,
  }) {
    final normalizedExplicit = _normalizeImportPath(explicitImport);
    if (normalizedExplicit != null) {
      return normalizedExplicit;
    }

    if (packageName == null || packageName.isEmpty) {
      return null;
    }

    final cacheKey = '$projectRoot|$replacement|$packageName';
    final cached = _autoImportCache[cacheKey];
    if (cached != null || _autoImportCache.containsKey(cacheKey)) {
      return cached;
    }

    final detectedImport = _detectImportFromLib(
      replacement: replacement,
      projectRoot: projectRoot,
      packageName: packageName,
    );
    _autoImportCache[cacheKey] = detectedImport;
    return detectedImport;
  }

  bool _isConstructorType(NamedType node) {
    final parent = node.parent;
    return parent is ConstructorName && identical(parent.type, node);
  }

  String? _normalizeImportPath(String? value) {
    if (value == null) return null;

    var normalized = value.trim();
    if (normalized.isEmpty) return null;

    final fullImportMatch = RegExp(
      r'''^import\s+['"]([^'"]+)['"]\s*;?$''',
    ).firstMatch(normalized);
    if (fullImportMatch != null) {
      normalized = fullImportMatch.group(1)!;
    }

    if ((normalized.startsWith("'") && normalized.endsWith("'")) ||
        (normalized.startsWith('"') && normalized.endsWith('"'))) {
      normalized = normalized.substring(1, normalized.length - 1);
    }

    if (normalized.endsWith(';')) {
      normalized = normalized.substring(0, normalized.length - 1).trim();
    }

    if (normalized.isEmpty) return null;
    return normalized;
  }

  String? _detectImportFromLib({
    required String replacement,
    required String projectRoot,
    required String packageName,
  }) {
    final libDir = Directory('$projectRoot${Platform.pathSeparator}lib');
    if (!libDir.existsSync()) {
      return null;
    }

    final classPattern = RegExp('class\\s+${RegExp.escape(replacement)}\\b');
    final matchedImports = <String>[];

    for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      String content;
      try {
        content = entity.readAsStringSync();
      } catch (_) {
        continue;
      }

      if (!classPattern.hasMatch(content)) {
        continue;
      }

      final relativePath =
          entity.path.substring(libDir.path.length + 1).replaceAll('\\', '/');
      matchedImports.add('package:$packageName/$relativePath');

      // Keep this deterministic: auto-import only when a single match exists.
      if (matchedImports.length > 1) {
        return null;
      }
    }

    return matchedImports.isEmpty ? null : matchedImports.first;
  }

  String? _findProjectRoot(String sourcePath) {
    var current = File(sourcePath).parent.absolute;

    while (true) {
      final pubspec = File(
        '${current.path}${Platform.pathSeparator}pubspec.yaml',
      );
      if (pubspec.existsSync()) {
        return current.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        return null;
      }
      current = parent;
    }
  }

  String? _readPackageName(String projectRoot) {
    final pubspecFile = File(
      '$projectRoot${Platform.pathSeparator}pubspec.yaml',
    );
    if (!pubspecFile.existsSync()) {
      return null;
    }

    try {
      for (final line in pubspecFile.readAsLinesSync()) {
        final match = RegExp(r'^\s*name\s*:\s*([^\s#]+)').firstMatch(line);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
