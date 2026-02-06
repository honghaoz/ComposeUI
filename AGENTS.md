# Your role

You are an expert iOS/macOS UI developer focused on clean, maintainable declarative UI code.

# Repository Guidelines

## Project Structure & Module Organization
- Root-level tooling and metadata live in `Makefile`, `scripts/`, `configs/`, and `bin/`.
- Main framework code is in `ComposeUI/Sources/ComposeUI`.
- Tests are in `ComposeUI/Tests/ComposeUITests`.
- Playgrounds live in `playgrounds/` with separate projects for macOS and iOS.
- Root `Package.swift` is for public package consumption; internal day-to-day development and tests run from `ComposeUI/`.

## Build, Test, and Development Commands
- `make bootstrap` — bootstrap tools, hooks, and dependencies.
- `make build` — build root package in release mode.
- `make format` — run SwiftFormat + SwiftLint autocorrect across the repo.
- `make lint` — run SwiftFormat lint + SwiftLint checks.
- `make build-playground-macOS` / `make build-playground-iOS` — build playground projects.
- `make -C ComposeUI build` — build framework workspace in Debug for macOS/iOS/tvOS/visionOS.
- `make -C ComposeUI build-release-<platform>` — release build per platform.
- `make -C ComposeUI test-macOS` / `test-iOS` / `test-tvOS` / `test-visionOS` — run platform tests.
- `make -C ComposeUI test-codecov` — run SwiftPM tests with coverage output.
- `cd ComposeUI && swift test --filter <TestCase>.<test_name>` — run a focused test quickly.

## Coding Style & Naming Conventions
- Use `make format` and `make lint` as the source of truth for style.
- Follow existing Swift naming conventions: `lowerCamelCase` for functions/vars, `UpperCamelCase` for types.
- Keep public APIs documented with concise, practical comments and examples when useful.
- Preserve existing file header style for new Swift files.
- Prefer small, focused changes; avoid incidental refactors in unrelated areas.
- Use `private enum Constants` for repeated literals and magic numbers where it improves clarity. For example:
  ```swift
  // MARK: - Constants

  private enum Constants {

    /// The spacing between the items.
    static let spacing: CGFloat = 8
  }
  ```

## Testing Guidelines
- Test framework is **ChouTiTest** with `XCTestCase` (`expect`, `fail`, etc.).
- Avoid `XCTFail()`; prefer `fail()` from ChouTiTest. If there's no available ChouTiTest helper, recommend adding one.
- Test files should end with `Tests.swift` and mirror source structure when practical.
- Follow local test naming style in the file you are editing (many tests use `test_<behavior>`).
- Test methods should be prefixed with `test_`.
- Add or update tests for behavior changes, especially layout, rendering, and animation transitions.

## Commit & Pull Request Guidelines
- Follow existing commit style: optional bracketed scopes/tags + short summary (e.g. `[theme] add theme publisher tests`).
- Keep commits focused and atomic.
- For PRs, include: what changed, why, and how to test the changes.

## Agent-Specific Instructions
- Prefer `rg` for search, and keep edits minimal and focused.
- When touching cross-platform code, validate conditional compilation paths (`AppKit`/`UIKit`) and platform-specific tests.

## Workflow Orchestration

### 1. Plan Mode Default

- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Self-Improvement Loop
- After ANY correction from the user, update 'AGENTS.md' with the new pattern and lessons learned.
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

## Lessons and Conventions

Add short, actionable rules here when a pattern repeats.

- When adding a new `ComposeNode` extension API, place it in a dedicated file named after its concern (for example `ComposeNode+Transform.swift`) instead of appending to an unrelated extension file.
- Keep test file organization aligned with source organization; tests for a new source extension should live in a matching test file name (for example `ComposeNode+TransformTests.swift`).
- For modifier/transform tests, verify observable render output or applied attributes (for example layer color, text font), not only closure execution or indirect proxies like item count.
- Run internal framework tests from `ComposeUI/` (for example `cd ComposeUI && swift test --filter ...`) rather than relying on the root package, which is configured for public consumption.
