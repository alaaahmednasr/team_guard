import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart'
    show ClassDeclaration, ConstructorName, NamedType;
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'config_loader.dart';
import 'forbidden_widget_fix.dart';

class ForbiddenWidgetRule extends DartLintRule {
  ForbiddenWidgetRule() : super(code: _errorCode);

  static const _errorCode = LintCode(
    name: 'team_guard.forbidden_widget',
    problemMessage: '{0}',
    errorSeverity: DiagnosticSeverity.ERROR,
    uniqueName: 'team_guard.forbidden_widget.error',
  );

  static const _warningCode = LintCode(
    name: 'team_guard.forbidden_widget',
    problemMessage: '{0}',
    errorSeverity: DiagnosticSeverity.WARNING,
    uniqueName: 'team_guard.forbidden_widget.warning',
  );

  static const _infoCode = LintCode(
    name: 'team_guard.forbidden_widget',
    problemMessage: '{0}',
    errorSeverity: DiagnosticSeverity.INFO,
    uniqueName: 'team_guard.forbidden_widget.info',
  );

  @override
  List<Fix> getFixes() => [ForbiddenWidgetFix()];

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final root = Directory(resolver.source.fullName).parent.parent.path;

    final config = WidgetGuardConfig.load(root);
    if (config.isPathIgnored(resolver.source.fullName)) {
      return;
    }

    context.registry.addInstanceCreationExpression((node) {
      final typeNode = node.constructorName.type;
      final symbolName = typeNode.name.lexeme;

      final restriction = config.restrictionForSymbol(symbolName);
      if (restriction == null) return;
      if (config.isPathMatchingPatterns(resolver.source.fullName, restriction.ignore)) return;

      final replacement = restriction.replacement;
      final enclosingClassName =
          node.thisOrAncestorOfType<ClassDeclaration>()?.name.lexeme;

      // Allow the replacement widget to use the original widget internally.
      if (enclosingClassName == replacement) {
        return;
      }

      final message =
          '$symbolName is restricted. A custom class is available: $replacement. Use it instead.';
      final nameToken = typeNode.name;
      final lintCode = _codeForSeverity(restriction.severity);

      reporter.atToken(
        nameToken,
        lintCode,
        arguments: [message],
      );
    });

    context.registry.addPrefixedIdentifier((node) {
      final className = node.prefix.name;
      final restriction = config.restrictionForSymbol(className);
      if (restriction == null) return;
      if (config.isPathMatchingPatterns(resolver.source.fullName, restriction.ignore)) return;

      final replacement = restriction.replacement;
      final enclosingClassName =
          node.thisOrAncestorOfType<ClassDeclaration>()?.name.lexeme;
      if (enclosingClassName == replacement) return;

      final message =
          '$className is restricted. A custom class is available: $replacement. Use it instead.';

      reporter.atToken(
        node.prefix.token,
        _codeForSeverity(restriction.severity),
        arguments: [message],
      );
    });

    context.registry.addNamedType((node) {
      if (_isConstructorType(node)) {
        // Already covered by instance creation checks.
        return;
      }

      final symbolName = node.name.lexeme;
      final restriction = config.restrictionForSymbol(symbolName);
      if (restriction == null) return;
      if (config.isPathMatchingPatterns(resolver.source.fullName, restriction.ignore)) return;

      final replacement = restriction.replacement;
      final enclosingClassName =
          node.thisOrAncestorOfType<ClassDeclaration>()?.name.lexeme;
      if (enclosingClassName == replacement) return;

      final message =
          '$symbolName is restricted. A custom class is available: $replacement. Use it instead.';

      reporter.atToken(
        node.name,
        _codeForSeverity(restriction.severity),
        arguments: [message],
      );
    });
  }

  LintCode _codeForSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'error':
        return _errorCode;
      case 'warning':
        return _warningCode;
      case 'info':
      default:
        return _infoCode;
    }
  }

  bool _isConstructorType(NamedType node) {
    final parent = node.parent;
    return parent is ConstructorName && identical(parent.type, node);
  }
}
