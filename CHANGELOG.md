## 1.0.11

- Enforce class restrictions in constructor usage as well as prefixed access.
- Apply the same symbol lookup in quick-fix for both `widgets` and `classes`.
- Improve `team_guard:init` scaffolding in Flutter projects:
  - generate richer starter templates for text-like replacement widgets
  - generate color palette starter templates for color-like helper classes
- Update README with regeneration behavior (existing files are not overwritten) and starter template examples.

## 1.0.10

- Add `dart run team_guard:setup` command to run `team_guard:init` then `custom_lint` in one step.
- Update README setup flow to prefer single-command setup while keeping manual steps documented.

## 1.0.9

- Add `custom_lint` to runtime dependencies so `dart run custom_lint` is available after installing `team_guard`.
- Improve quick-fix import behavior:
  - accept `import` values in both package-path form and full Dart import statement form
  - auto-detect replacement imports from `lib/` when a replacement class is found in exactly one file
- Enhance `dart run team_guard:init`:
  - scaffold missing replacement files in `lib/core` from `team_guard.yaml`
  - keep init idempotent by skipping files that already exist
- Refresh README for setup, auto-import, and init scaffolding flow.

## 1.0.8

- Lower minimum Dart SDK constraint to `>=3.0.0 <4.0.0`.
- Update README:
  - document that `team_guard.yaml` is generated automatically by `dart run team_guard:init`
  - remove `info` from supported severity values (`warning`, `error` only)
  - refresh install snippet to `team_guard: ^1.0.8`

## 1.0.7

- Add uninstall command to README:
  - `flutter pub remove team_guard custom_lint`

## 1.0.6

- Update docs and examples to use `severity: error` by default.
- Update generated default `team_guard.yaml` template to use `severity: error`.

## 1.0.5

- Improve pub score compliance:
  - Add Dartdoc for public API entrypoints.
  - Shorten package description in `pubspec.yaml`.
  - Replace deprecated analyzer API usage in lint/fix implementation.
- Broaden analyzer compatibility constraint to `>=8.4.0 <12.0.0`.

## 1.0.4

- Add `dart run team_guard:init` command to generate `team_guard.yaml` directly.
- Auto-configure `analysis_options.yaml` to include `analyzer.plugins: [custom_lint]` when missing.
- Refresh README setup flow and add an updated full example in `example/team_guard_example.dart`.

## 1.0.3

- Clarify `import` field format in docs/config template: use package path only (not a Dart `import '...';` statement).

## 1.0.2

- Rewrite README with complete setup steps, correct team_guard.yaml configuration, and troubleshooting for IDE visibility/generation.

## 1.0.1

- Update README with explicit custom lint run command (dart run custom_lint).

## 1.0.0

- Initial version.



