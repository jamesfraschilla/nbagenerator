## NBA Scenario Generator — Copilot instructions

Quick context
- This is a small Flutter app that generates late-game NBA scenarios. Main UI lives in `lib/main.dart` (ScenarioScreen). Core logic is in `lib/scenario_generator.dart` (Scenario, ScenarioGenerator). Edit UI is `lib/edit_scenario_screen.dart` and a simple `HomeScreen` exists in `lib/home_screen.dart`.

What to prioritize
- Preserve the deterministic shape of `Scenario` when changing code: fields in `Scenario` (team scores, fouls, timeouts, gameClock, shotClock, period, possession, startType) are passed between generator, UI, and editor.
- Keep UI state handling simple: `Scenario` instances are created by `ScenarioGenerator.generateScenario(...)` and passed through Navigator when editing. Return the edited `Scenario` via `Navigator.pop(context, scenario)`.

Project-specific conventions
- Random generation logic is centralized in `ScenarioGenerator` — any new generation options should be added here and exposed as optional parameters on `generateScenario`.
- Clock and score formats are simple strings (e.g. `"0:00.3"`, `"1:23"`) — many UI formatting helpers assume this shape (see `formatGameClock` in `main.dart`). When changing format, update formatting helpers and editor dropdown options in `edit_scenario_screen.dart`.

Build / run / test notes
- Standard Flutter project. Use Flutter tooling for everything:
  - Run app (macOS/iOS/Android): `flutter run` (or use IDE run)
  - Run tests: `flutter test` (no custom test setup present)
  - Ensure Flutter SDK >= 3.9.2 per `pubspec.yaml`.

Integration & dependencies
- No network or native plugins used. Fonts are provided at `assets/fonts/Erbos.ttf` and declared in `pubspec.yaml` — keep asset paths and `pubspec.yaml` in sync.

Examples & patterns
- Generator usage (from `main.dart`):
  - Create generator: `final generator = ScenarioGenerator();`
  - Generate: `generator.generateScenario(scoreRange: selectedScoreRange, clockRange: selectedClockRange);`
- Edit flow (from `main.dart`):
  - Push editor: `Navigator.push(..., builder: (_) => EditScenarioScreen(scenario: currentScenario))`
  - Receive updated Scenario: `final updated = await Navigator.push(...); if (updated is Scenario) setState(() => currentScenario = updated);`

When changing UI
- If you add new Scenario fields, update:
  1. `Scenario` class in `lib/scenario_generator.dart`
  2. `EditScenarioScreen` to allow editing the value and returning it
  3. Any UI that formats or displays the value (e.g., `buildScoreboard` in `main.dart`)

Edge cases to watch for (discoverable from code)
- `formatGameClock` expects "M:SS" or "0:SS.s" patterns; malformed strings fall back to raw value. Keep dropdown options in `main.dart` and `edit_scenario_screen.dart` consistent.
- `Scenario.blank()` exists for empty defaults — use when you need a placeholder scenario.

If uncertain, open these files first
- `lib/scenario_generator.dart` — core model + generator
- `lib/main.dart` — primary UI and formatting helpers
- `lib/edit_scenario_screen.dart` — editor and navigator contract

If you change behavior that affects user-visible values, include a short note in commit message referencing which files were updated and why.

Ask the maintainer if
- You plan to introduce JSON serialization, network sync, or persistent storage for scenarios (none exist now).
