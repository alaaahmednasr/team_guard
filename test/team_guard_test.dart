import 'package:test/test.dart';
import 'package:team_guard/src/config_loader.dart';

void main() {
  group('WidgetGuardConfig ignore/exclude tests', () {
    test('Empty ignore list returns false', () {
      final config = WidgetGuardConfig(
        widgets: {},
        classes: {},
        ignore: [],
        projectRoot: '/project',
      );
      expect(config.isPathIgnored('/project/lib/main.dart'), isFalse);
    });

    test('Exact file match', () {
      final config = WidgetGuardConfig(
        widgets: {},
        classes: {},
        ignore: ['lib/core/app_colors.dart'],
        projectRoot: '/project',
      );
      expect(config.isPathIgnored('/project/lib/core/app_colors.dart'), isTrue);
      expect(config.isPathIgnored('/project/lib/core/app_dio.dart'), isFalse);
    });

    test('Glob match with single *', () {
      final config = WidgetGuardConfig(
        widgets: {},
        classes: {},
        ignore: ['lib/core/*.g.dart'],
        projectRoot: '/project',
      );
      expect(config.isPathIgnored('/project/lib/core/app_colors.g.dart'), isTrue);
      expect(config.isPathIgnored('/project/lib/core/subdir/app_colors.g.dart'), isFalse);
    });

    test('Glob match with **', () {
      final config = WidgetGuardConfig(
        widgets: {},
        classes: {},
        ignore: ['**/*.g.dart'],
        projectRoot: '/project',
      );
      expect(config.isPathIgnored('/project/lib/app.g.dart'), isTrue);
      expect(config.isPathIgnored('/project/lib/core/app_colors.g.dart'), isTrue);
      expect(config.isPathIgnored('/project/lib/core/subdir/app_colors.g.dart'), isTrue);
      expect(config.isPathIgnored('/project/lib/app.dart'), isFalse);
    });

    test('No slash in pattern matches anywhere', () {
      final config = WidgetGuardConfig(
        widgets: {},
        classes: {},
        ignore: ['ignored_file.dart'],
        projectRoot: '/project',
      );
      expect(config.isPathIgnored('/project/lib/ignored_file.dart'), isTrue);
      expect(config.isPathIgnored('/project/lib/core/ignored_file.dart'), isTrue);
      expect(config.isPathIgnored('/project/ignored_file.dart'), isTrue);
    });

    test('Directory recursive match with trailing slash', () {
      final config = WidgetGuardConfig(
        widgets: {},
        classes: {},
        ignore: ['lib/core/'],
        projectRoot: '/project',
      );
      expect(config.isPathIgnored('/project/lib/core/app_colors.dart'), isTrue);
      expect(config.isPathIgnored('/project/lib/core/subdir/file.dart'), isTrue);
      expect(config.isPathIgnored('/project/lib/main.dart'), isFalse);
    });

    test('Windows path separators normalized correctly', () {
      final config = WidgetGuardConfig(
        widgets: {},
        classes: {},
        ignore: ['lib/core/**'],
        projectRoot: r'C:\Users\DBS\Desktop\project',
      );
      expect(config.isPathIgnored(r'C:\Users\DBS\Desktop\project\lib\core\app_colors.dart'), isTrue);
      expect(config.isPathIgnored(r'C:\Users\DBS\Desktop\project\lib\main.dart'), isFalse);
    });

    test('Rule-specific ignore works correctly', () {
      final config = WidgetGuardConfig(
        widgets: {
          'Text': WidgetRestriction(
            replacement: 'CustomText',
            ignore: ['lib/legacy/**'],
          )
        },
        classes: {},
        ignore: [],
        projectRoot: '/project',
      );
      
      final restriction = config.restrictionForSymbol('Text')!;
      expect(config.isPathMatchingPatterns('/project/lib/legacy/old_view.dart', restriction.ignore), isTrue);
      expect(config.isPathMatchingPatterns('/project/lib/new_view.dart', restriction.ignore), isFalse);
    });
  });
}
