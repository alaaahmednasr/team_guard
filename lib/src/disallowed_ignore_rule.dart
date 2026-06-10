import 'package:analyzer/dart/ast/token.dart' show CommentToken;
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

class DisallowedIgnoreRule extends DartLintRule {
  DisallowedIgnoreRule() : super(code: _errorCode);

  static const _errorCode = LintCode(
    name: 'team_guard.disallowed_ignore',
    problemMessage: '{0}',
    errorSeverity: DiagnosticSeverity.ERROR,
    uniqueName: 'team_guard.disallowed_ignore.error',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      var token = node.beginToken;
      while (token != null && !token.isEof) {
        var comment = token.precedingComments;
        while (comment != null) {
          final commentText = comment.lexeme;
          if (commentText.contains('team_guard.forbidden_widget')) {
            reporter.atOffset(
              offset: comment.offset,
              length: comment.length,
              errorCode: _errorCode,
              arguments: ['Ignoring team_guard.forbidden_widget is not allowed.'],
            );
          }
          comment = comment.next as CommentToken?;
        }
        token = token.next;
      }
    });
  }
}
