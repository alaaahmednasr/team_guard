# Team Guard

A custom lint plugin for Dart and Flutter that helps teams enforce UI rules by blocking specific widgets/classes and suggesting approved replacements.

## Features

- Integrates with `custom_lint` for live IDE feedback.
- Supports configurable restrictions for both widgets and classes.
- Class restrictions are enforced for both prefixed access (for example `Colors.red`) and constructor usage (for example `Color(...)`).
- Supports `warning` and `error` severities per rule.
- Provides quick-fix suggestions with replacement names/imports.
- Scaffolds Flutter-friendly starter files for common replacements such as text widgets and color classes.

## Prerequisites

- Dart SDK `>=3.0.0 <4.0.0`
- IDE plugin:
  - VS Code: `Custom Lint`
  - Android Studio / IntelliJ: `Custom Lint`

## Installation

Add dependencies to your app's `pubspec.yaml`:

```yaml
dev_dependencies:
  team_guard: ^1.0.17
```

Then run:

```bash
# Flutter project
flutter pub get

# Dart project
dart pub get
```

`pub get` downloads the package only. It does not auto-configure your project files.

## Setup (Required)

Run one command in your project root:

```bash
dart run team_guard:setup
```

This command:
- generates `team_guard.yaml` automatically in the project root (if missing)
- creates `analysis_options.yaml` if missing
- adds `custom_lint` plugin under `analyzer.plugins` if missing
- generates missing replacement files in `lib/core` based on `team_guard.yaml`
- skips generation when a file with the same name already exists anywhere under `lib/`
- never overwrites existing files
- starts `custom_lint`

If your IDE still does not show lints, restart analysis server/IDE.

## Configuration

After running `dart run team_guard:setup`, you will find `team_guard.yaml` generated in your project root. Edit it as needed:

```yaml
widgets:
  Text:
    replacement: CustomText
    # import: package:your_app/widgets/custom_text.dart
    severity: error

  ElevatedButton:
    replacement: AppElevatedButton
    # import: package:your_app/core/ui/buttons/app_elevated_button.dart
    severity: error

classes:
  Colors:
    replacement: AppColors
    # import: package:your_app/theme/app_colors.dart
    severity: error

  Dio:
    replacement: AppDio
    # import: package:your_app/core/network/app_dio.dart
    severity: error

  GetIt:
    replacement: AppLocator
    # import: package:your_app/core/di/app_locator.dart
    severity: error

  Cubit:
    replacement: AppCubit
    # import: package:your_app/core/state/app_cubit.dart
    severity: error
```

Full setup example: [`example/team_guard_example.dart`](example/team_guard_example.dart)

Class-name matching is tolerant for separators/case, so values like `GetIt`, `get_it`, or `getit` in config are treated as the same symbol.

### Minimal Policy Example

If you only need a compact setup, use:

```yaml
widgets:
  Text:
    replacement: CustomText
    severity: error
  ElevatedButton:
    replacement: AppElevatedButton
    severity: error

classes:
  Colors:
    replacement: AppColors
    severity: error
  Dio:
    replacement: AppDio
    severity: error
```

When you run `dart run team_guard:setup`, replacement stubs are created automatically in `lib/core` (for example, `CustomText` -> `lib/core/custom_text.dart`) only when no file with the same name already exists anywhere under `lib/`.

If `lib/widgets/custom_text.dart` already exists, Team Guard will not create `lib/core/custom_text.dart`.

If a matching file already exists, Team Guard keeps your current file unchanged.
To regenerate with the latest template, either edit the file manually or delete/rename it and run `dart run team_guard:setup` again.

### Generated Starter Templates (Flutter projects)

For text-like replacement names (contains `text`), Team Guard generates a starter similar to:

```dart
import 'package:flutter/widgets.dart';

class CustomText extends StatelessWidget {
  const CustomText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
}
```

For color-like replacement names (contains `color`), Team Guard generates a starter similar to:

```dart
import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF6200EE);
  static const Color primaryVariant = Color(0xFF3700B3);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryVariant = Color(0xFF018786);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF000000);
  static const Color overlay = Color.fromARGB(5, 2, 4, 5);
}
```

Usage example when an API requires `Color`:

```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: AppColors.primary,
),
```

### Import Field Format

`import` in `team_guard.yaml` is optional.

- If provided, Team Guard uses it directly for quick-fix auto-import.
- If omitted, Team Guard tries to auto-detect the import from your `lib/` folder when the replacement class exists in exactly one file.

Correct:

```yaml
import: package:your_app/widgets/custom_text.dart
```

or

```yaml
import: "package:your_app/widgets/custom_text.dart"
```

Also accepted:

```yaml
import: "import 'package:your_app/widgets/custom_text.dart';"
```

### Severity Values

- `warning`
- `error`

Use `error` if you want violations to appear as red errors in IDE problems.

## Example Violation

If `Text` is restricted:

```dart
Text('Hello');
```

You will get a lint message suggesting `CustomText` instead.

## Troubleshooting

### Lints appear in terminal but not in IDE

1. Confirm `analysis_options.yaml` contains:

```yaml
analyzer:
  plugins:
    - custom_lint
```

2. Install IDE plugin `Custom Lint`.
3. Restart analysis:
   - VS Code: `Dart: Restart Analysis Server`
   - Android Studio/IntelliJ: restart IDE
4. Check Problems filter is not set to errors-only if your rules are `warning`.

### `team_guard.yaml` was not generated

- Run `dart run team_guard:setup` from the project root.
- If still missing, create `team_guard.yaml` manually using the example above.

## To Uninstall

```bash
flutter pub remove team_guard
```

## Additional Information

- Package: https://pub.dev/packages/team_guard
- custom_lint docs: https://pub.dev/packages/custom_lint
- Issues and contributions: https://github.com/HazemHamdy7/team_guard
