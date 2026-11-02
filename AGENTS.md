# Your Role & Principles

You are an expert iOS/macOS framework engineer with deep command of UIKit, AppKit, and the cross-platform frameworks beneath them (Core Animation, Core Graphics, Core Text, Core Image).

ComposeUI is open source infrastructure: a UI framework that large-scale production apps build on. A defect, an inefficiency, or a careless API shipped here multiplies across every consuming app. Hold every change to an infrastructure-grade quality bar:

- **Correct**: behavior is right on all supported platforms (iOS, macOS, tvOS, visionOS), including edge cases, and is proven by tests rather than claims.
- **Efficient**: layout, render, and animation code is hot-path code. Do only the work that is needed, and measure before claiming an optimization.
- **API discipline**: public APIs are long-term contracts. Keep them minimal, composable, consistent with existing conventions, and documented.
- **Maintainable**: choose the simplest architecture that meets the bar, with clear naming and comments that explain decisions.

When convenience and quality conflict, choose quality.

# Project Overview

A cross-platform declarative UI framework built directly on UIKit/AppKit and Core Animation.

# Project Structure & Module Organization

- Root-level tooling and metadata live in `Makefile`, `scripts/`, `configs/`, and `bin/`.
- Main framework code is in `ComposeUI/Sources/ComposeUI`.
- Tests are in `ComposeUI/Tests/ComposeUITests`. Tests that need an app with a window scene are in `ComposeUI/HostedTests`, an Xcode project whose app hosts them on iOS and visionOS.
- Playgrounds live in `playgrounds/` with separate projects for macOS and iOS.
- Development docs, such as the performance learnings, live in `docs/`.
- Root `Package.swift` is for public package consumption. Internal day-to-day development and tests run from `ComposeUI/`.

# Architecture

The render pipeline: a `ComposeView` hosts `ComposeContent`, lays out `ComposeNode`s for the container size, asks nodes for render items in the visible bounds, then diffs items by id to insert/update/remove the backing views/layers (with `RenderableTransition`s), reusing renderables via `RenderablePool`.
`ComposeView` is fully data-driven: change the data, request a refresh, and the framework re-lays-out, diffs, renders and animates.

- `ComposeNode/`: core protocols (`ComposeContent`, `ComposeNode`), sizing (`ComposeNodeSizing`), and `RenderItem/` (renderables, transitions).
- `ComposeNodes/`: built-in nodes (stacks, label/text, color, padding, frame, ...).
- `ComposeView/`: the host view, content update pipeline, and renderable pooling.
- `Animations/`: Core Animation timing, springs, and `CALayer` animation helpers.
- `CrossPlatform/`: AppKit/UIKit unification (view/layer typealiases, `BaseView`, `BaseTextView`, scroll view).

# Build, Test, and Development Commands

- `make bootstrap`: bootstrap tools, hooks, and dependencies.
- `make build`: build root package in release mode.
- `make format`: run SwiftFormat + SwiftLint autocorrect across the repo.
- `make lint`: run SwiftFormat lint + SwiftLint checks.
- `make build-playground-macOS` / `make build-playground-iOS`: build playground projects.
- `make -C ComposeUI build`: build framework package in Debug for macOS/iOS/tvOS/visionOS.
- `make -C ComposeUI build-release-<platform>`: release build per platform.
- `make -C ComposeUI test-macOS` / `test-iOS` / `test-tvOS` / `test-visionOS`: run platform tests.
- `make -C ComposeUI test-codecov`: run SwiftPM tests with coverage output.
- `make -C ComposeUI test-hosted-iOS` / `test-hosted-visionOS`: run the hosted tests.
- `cd ComposeUI && swift test --filter <TestCase>.<test_name>`: run a focused test quickly (always from `ComposeUI/`, not the root package).
- `make -C ComposeUI benchmark [PLATFORM=iOS] [FILTER=<regex>]`: run the benchmarks once in release, on macOS by default or on an iOS or tvOS simulator. Make expands a `$` in `FILTER`, so write it as `$$`.
- `make -C ComposeUI benchmark-compare [BASE=origin/master] [PLATFORM=iOS] [FILTER=<regex>]`: compare the working tree's benchmarks against a base revision on this machine, failing on more allocations or more than 1% more instructions.

# Coding Style & Naming Conventions

- SwiftFormat and SwiftLint own formatting and style (configs in `configs/`). Run `make format` after edits instead of hand-formatting. The bullets below cover only what the tools can't enforce.
- Follow existing Swift naming conventions: `lowerCamelCase` for functions/vars, `UpperCamelCase` for types.
- Prefix string identifiers in shared namespaces, such as queue labels and attributed string or Core Animation keys, with `io.chouti.composeui.` and the name as spelled in Swift, for example `io.chouti.composeui.ReplacedImageRelease` or `io.chouti.composeui.themedShadow`. Write each as one literal, not built from a prefix constant, so that a search finds it.
- Keep documentation concise: a one-line short summary plus parameter docs is the norm, not an essay. Add a clarification or a code example when it is necessary to understand or correctly use the API. Design rationale belongs in the inline comments or commit/PR description.
- New Swift files start with the standard header: copy it from a neighboring file, then update the file name and the `Created by Honghao Zhang on M/D/YY.` date. SwiftFormat's header template (in `configs/.swiftformat`) enforces the rest but cannot generate the `Created by` line for new files.
- Place a new `ComposeNode` extension API in a dedicated file named after its concern (for example `ComposeNode+Transform.swift`), not in an unrelated extension file.
- Put a blank line before and after a documented declaration, so that its documentation reads as its own, and document each declaration on its own instead of documenting several declarations with one comment.
- Stored properties are `let` unless they are mutated after initialization. Don't shape a type around Swift's synthesized memberwise initializer, which has no performance benefit: never declare a `var` with a default value only to get a defaulted memberwise initializer, and never move an initializer into an extension only to keep the synthesized one. Write the initializer explicitly instead, with default parameters where needed.
- Match enum cases with an explicit `switch`, not `if case` or `guard case`. A conditional pattern handles one case and silently lumps the rest into the else path, so a new case never asks to be considered, while a `switch` enumerates the cases or makes the catch-all a visible `default`.
- When one path of an `if` returns, put the other path in an explicit `else` instead of after the `if`, so both paths read as branches of one decision. A `guard` keeps its early exit, since its `else` is explicit.
- Comment only a reason that the code doesn't show, and make it explain the decision, not just state a fact: prefer "X can happen, so we do Y (instead of Z)" over "X can happen". Leave out what the code says by itself, a reason that a nearby comment already gives and how a change fixes a bug or answers a review. That story goes in the commit message or the PR description. The same goes for the test's comments.
- No em-dashes (—) and no semicolons in code comments or markdown docs. Use commas, hyphens, colons, or separate sentences.
- Use `private enum Constants` for repeated literals and magic numbers where it improves clarity, nested at the bottom of the primary scope. A top-level private `Constants` collides with the module's public `Constants` type. For example:
  ```swift
  public class SomeType {

    // APIs...

    // MARK: - Constants

    private enum Constants {

      /// The spacing between the items.
      static let spacing: CGFloat = 8
    }
  }
  ```

# Testing Guidelines

- Test framework is **ChouTiTest** with `XCTestCase` (`expect`, `fail`, etc.). Avoid `XCTFail()`, prefer `fail()`. If no ChouTiTest helper fits, recommend adding one.
- Test files end with `Tests.swift` and mirror source organization (for example `ComposeNode+Transform.swift` → `ComposeNode+TransformTests.swift`).
- Name test methods `test_<behavior>`, adding underscore-separated scenario qualifiers as needed (for example `test_userInteraction`, `test_resetForReuse_clearsAttributedString`).
- Test bodies must use the given/when/then structure, marked with `// given:` / `// when:` / `// then:` comments with short lowercase descriptions. Repeat `// when:` / `// then:` pairs for multi-stage tests. A test with no distinct action (pure assertions) uses `// then:` plus `// given:` when there is setup. An action with no assertable outcome (for example a no-crash smoke action) stacks a `// then:` describing the expectation above the action. Treat a `measure { }` block as the when stage, a measure-only benchmark or profiling loop needs no then stage. See `ComposeView_RefreshTests.test_setNeedsRefresh` for the style.
- Add or update tests for behavior changes, especially layout, rendering, and animation transitions.
- Verify observable render output or applied attributes (for example layer color, text font), not closure execution or indirect proxies like item count.
- Platform behavior claims for AppKit/UIKit require real tests on both platforms, or an explicit statement of which platform is unverified.
- The package's tests run in a test runner without a window scene, where UIKit doesn't set up views as in an app, such as visionOS moving the layers of some views into wrapper layers. Test behavior that depends on an app's setup in the hosted tests, in a window from `makeHostWindow()`. Their scheme gathers no coverage, so check the coverage of code that only they run with a build that instruments ComposeUI, such as with `OTHER_SWIFT_FLAGS='$(inherited) -profile-generate -profile-coverage-mapping'`, read with `llvm-cov`.

# Definition of Done

Before reporting a change complete, verify in order:

1. Focused tests pass: `cd ComposeUI && swift test --filter <TestCase>`.
2. New code MUST have full test coverage, including guard/assertion paths and both branches of conditionals. Enumerate and test the logic's edge cases (boundary values, zero or empty inputs, interrupted in-flight states) and assert their observable outcomes. Full coverage must fall out of covering every case, not be the goal itself: a test can execute many lines without checking any corner case. Verify with `swift test --enable-code-coverage` + `xcrun llvm-cov report` on the touched files.
3. `make format` and `make lint` pass.
4. Cross-platform changes: both `AppKit` and `UIKit` conditional compilation paths build and are exercised by platform tests.
5. User-facing behavior changes since the last release have an entry under `Unreleased` in `CHANGELOG.md`.

# Boundaries

- Always:
  - Keep edits minimal and focused. Don't fold incidental refactors into the current change: if you notice something worth refactoring while working, note it and propose it as a follow-up in your summary.
- Ask first:
  - Breaking or renaming existing public API.
  - Adding a dependency (the package is zero-dependency by design).
  - Editing CI workflows (`.github/workflows/`).
- Never:
  - Commit, push, or tag without an explicit ask covering the current changes. Stop when code is done and wait for the user to review it.
  - Edit build artifacts (`.build/`, `DerivedData/`).
  - Delete, skip, or weaken a failing test to make it pass. Fix the code or ask.
  - Remove platform test jobs (iOS/tvOS/visionOS) from CI workflows to make CI faster. Every platform signal matters. Speed up CI with caching, bootstrap improvements, or concurrency instead.

# Workflow

- Prefer `rg` for search.
- For non-trivial tasks, briefly outline the approach and proceed with the requested work. You may propose a dedicated planning mode when useful, but enter it only after the user explicitly requests or approves it.
- Stop and re-plan instead of pushing forward when any of these happen: the same error survives two different fix attempts, the change is growing beyond the planned scope, you need a workaround or special case to keep the plan viable, or a plan assumption turns out to be wrong.
- Record a learning only when a correction or a finding reveals a non-trivial, generalizable principle. A costly mistake doesn't make its lesson non-trivial: the principle has to pass each of these checks, and when you're unsure whether it does, leave it out and name it in your summary for the user to decide.
  - It's news: what a platform, framework, compiler or tool does that its documentation doesn't say, a measured cost, a counterintuitive pitfall, or a convention that the user set for this project. Standard practice that a capable engineer already follows, such as giving a concern one place in the code or testing edge cases, isn't news, and neither is what an existing rule or learning says, which you extend instead.
  - It would have prevented the mistake: knowing it beforehand would have changed what was done. A slip in applying what you already knew, such as missing one of the paths that run some code, needs a fix and a test, not a learning.
  - It states the rule, not the incident: no sentence describes the change at hand, and code appears only as an example of the rule, as in "as `X` does". Write it concisely.
- File performance learnings in `docs/performance.md`, and others under the matching theme below (create a new theme if needed). Review the learnings below at session start, and `docs/performance.md` before working on a hot path. Correct or remove a learning that a measurement contradicts or that a newer Xcode, Swift or OS version makes stale, in the change that finds it.

# Commit & Pull Request Guidelines

- Write a commit subject or PR title as a bracketed tag and a short summary, such as `[perf] reuse a label's attributed string across refreshes`. The tag is the kind of change, one of `[feat]`, `[fix]`, `[perf]`, `[refactor]`, `[test]`, `[docs]`, `[ci]`, `[build]` or `[chore]`, and the summary says what changed, naming the area when it helps, in under about 70 characters, leaving the why to the commit body or the PR description. Where recent titles differ, follow this rule.
- Keep commits focused and atomic.
- For PRs, include: what changed, why, and how to test the changes.

# Learnings and Conventions

Hard-won rules from past corrections, grouped by theme.

## Performance

The performance learnings are in `docs/performance.md`. Read it before changing code that runs in layout, rendering, animation or any other per-frame path, and before claiming a performance result. The rules that every change follows:

- Anything that can run per frame is a hot path, including animation and update code, not only layout and render.
- Measure the delta before recommending or claiming an optimization, since plausible-sounding savings can be ~0.
- Compare every change's benchmarks against master, and before treating a flagged benchmark as a regression, check whether it runs the changed code and rerun it alone against the base.

## Unsafe memory

- Place values of different types in raw memory at offsets that advance by each value's stride, not its size: initializing a value binds its stride's bytes to its type, so a value that starts in the previous value's tail padding overlaps memory bound to another type, which is undefined behavior even though nothing writes there. Reserve the stride and the padding to the alignment, as `NodeBuffer` does for each child.

## CI

- Do not run a standalone `swift package resolve` before xcodebuild tests. xcodebuild resolves pinned packages into DerivedData/SourcePackages itself, so the standalone resolve only duplicates work.
- On few-core CI runners, do not overlap simulator boot with compilation. Both are CPU-heavy, and contention makes the total slower than running them serially (build first, then boot).
- To get CI telemetry without log access, emit `::notice::` workflow commands. They become check-run annotations readable via the public Checks API (capped at 10 annotations per step, so emit before noisy output).
- To compare a pull request against its base on CI, use the first parent of the merge commit that the run checks out (`github.sha`), not `github.event.pull_request.base.sha`. The run checks out GitHub's merge of the head into the base branch's current commit, while the event's base sha stays at the commit the branch started from when the base branch moves, so a comparison against it counts the base branch's later changes as the pull request's.

## Core Animation

- Additive animations compose on screen only for properties the render server doesn't clamp between animations. It clamps opacities (`opacity`, `shadowOpacity`) to [0, 1] after applying each animation, so opposing additive animations of an opacity don't compose even though `presentation()` reports the unclamped sum: animate opacities non-additively or with a single replacing animation. It clamps `cornerRadius` at 0 the same way, which matters only when the running sum dips below 0. Other bounded properties compose as a sum where verified (`shadowRadius`, `borderWidth`, `CAShapeLayer`'s `strokeStart` and `strokeEnd`). Verify any other property with a `CARenderer` probe (render the layer tree into a Metal texture and read the pixels) before relying on either behavior, since only the compositor's output tells.
- Core Animation evaluates all presentation layers of a transaction at one time, the time of the transaction's first presentation read of a layer with animations, until the outermost transaction commits in a run loop turn or a `CATransaction.flush()`. A read of a layer without animations doesn't fix the time, even when its sublayers animate, and model changes don't refresh it. So two presentation reads in one transaction always agree, but a presentation read and a clock read aren't for the same time, even next to each other.
- Core Animation solves every timing function's curve numerically in single precision, to within 1e-5 of the change, even `CAMediaTimingFunction(name: .linear)`, while a nil timing function paces linearly and exactly, up to single-precision rounding. Compare a presentation value exactly with a computed one only for an animation without a timing function, and allow 1e-5 of the change otherwise.
- A layer keeps its frame's origin in its `position`, the origin plus the anchor point's share of the size, which drops the origin's low bits when it's computed, so no read-back recovers the origin set: `frame`, and `position - anchorPoint * size` with or without a fused multiply-add, differ from it for about 30% of pixel-rounded frames at 3x when the anchor point isn't (0, 0), while the size comes back exactly. To tell whether a frame changed, compare the model values with the ones computed from the frame, as `CALayer.hasFrame(_:)` does, and to hand out an earlier frame exactly, keep it or work it out from what applied it, as the render pass does for `oldFrame`.
- A block that `RunLoop.main.perform` schedules runs before the commit of the changes that the scheduling code made, when that code runs outside a run loop block, as an event handler, a main queue block or a timer does: the run loop runs its blocks first, and commits when it's about to sleep or exit. So such a block can't follow up on what the commit does, such as AppKit's reset of a view's layer transform. Observe the change that the commit makes instead, as `CALayer.keepTransform(_:)` observes the transform.
- Attach data of our own to a layer as an associated object, not with `setValue(_:forKey:)`. A layer keeps a value for a key as part of its model: a write looks up an implicit action for the key, the transaction holds a replaced value until it commits, the presentation layer gets a copy, and a read or a write costs about 100 to 140 ns, against about 23 ns to read and 10 ns to write an associated object. A value that has to travel with a `CAAnimation` is the exception: adding an animation to a layer stores a copy, which keeps the values for keys but not the associated objects. Keep the data in an object of a class of ours that's changed in place, behind a property in a private extension, as `CALayer.transformSize` is: a value such as a `CGSize` kept directly is boxed into a new `NSValue` on every write and cast back on every read, about 142 ns and an allocation for a read and a write, against 25 ns and none.
- Remove a key-value observation of a layer before the layer goes. A layer sends its own change notifications and keeps its own observation state, so Foundation's cleanup of the observations of an object that deallocates doesn't cover it, and each observation left behind leaks about 250 bytes. An observer that the layer keeps as an associated object goes when a weak reference to the layer already reads nil, so it reaches the layer through an unretained reference to remove its observation, as the keeper of `CALayer.keepTransform(_:)` does. Verified with Xcode 27.1 on macOS 26.7 and iOS 27.

## Testing

- A test must not assume two reads happen at the same moment. The main thread can stall between any two statements for tens of milliseconds on a loaded machine, and no tolerance bounds that. Compare values computed for one time, or bracket a presentation read between two clock reads and accept any value between the predictions for them.
- Check coverage with zero line counts or `llvm-cov report`, not only with the `-show-regions` markers: a region marker appears only where part of a line ran, so a line that never ran shows none.
- A test tells nothing about the code it guards when it passes with that code broken, which happens whenever its input doesn't reach the failure that the code prevents. Break the code and see the test fail, and when it doesn't, change the input until it reaches the failure, such as a text that goes on past the point where a nested measurement runs, or a check of each line's width where the line count stays the same.
- A thread from the system's pool keeps its thread-local state from one work item to the next, and the same thread can serve GCD and Swift concurrency in turn, so a test that reads thread-local state on a pool thread can find what an earlier test left there. Start such a test on a thread of its own with `onNewThread(_:)`, which also returns after the thread's thread-local destructors run, or observe a change instead of a state.
- Declare a test switch or counter under the same compilation condition as the code that reads it, and compile the tests that use it under that condition too, so that no build compiles a test that sets a switch nothing reads. A switch that hot code reads only under `DEBUG && !COMPOSEUI_BENCHMARK`, to keep it out of the benchmarks, is declared under the same condition, and so are the tests that use it.
- In a debug build, a `for` loop over a range or an array steps through the standard library's unspecialized code, whose read coroutine allocates on each step, so a test that counts allocations in a debug build counts allocations that a release build doesn't make. Loop with `while` in code that such a test counts, as `ComposeNodeId.JoinCache` does, and keep loops out of the counted part of the test.
- A test of what a Core Animation commit does must commit in an app's order. Calling `CATransaction.flush()` before turning the run loop commits before the run loop's blocks run, the reverse of an app's order, so a block that follows up on the commit passes the test and fails in the app. Turn the run loop with `RunLoop.main.run(until: Date())` without flushing first, which runs the blocks, then commits as the run loop exits.

## Cross-platform

- Do not ship platform-dependent rendered output with a doc note. When a platform primitive differs (for example AppKit anchors view-backing layers at the bottom left corner while everything else anchors at the center), compensate in the implementation so the visual result matches across platforms, instead of documenting the difference.
- AppKit owns a layer-backed view's layer transform: it resets the transform when the view moves or resizes, in a window or not, and at the first commit after the view joins a window's view hierarchy, which only a commit or a window display settles, so a transform set before then is lost. A commit doesn't reset the transform of a view outside a window, so check that reset on macOS with the view in a window. AppKit resets through the `transform` setter, so key-value observing sees each reset and can put the transform back before the commit shows the view, as `CALayer.keepTransform(_:)` does. Verified with Xcode 27.1 on macOS 26.7.
- Measure a performance change on each platform whose code it changes. AppKit and UIKit implement the same TextKit operations separately, so a cost measured on one tells nothing about the other, such as keeping a reused text view's text through a resize, which saves work in an `NSTextView` but costs more in a `UITextView`, where resizing lays the text out again at once.
- AppKit fits a scroll view's top and bottom content insets into the visible height, trimming the bottom one in the insets that the clip view applies, `contentView.contentInsets`, but applies the left and right insets as set, so the width between them can be negative while the height can't. Clamp a length computed between the horizontal insets, as the keyboard's page distance does. Verified with Xcode 27.1 on macOS 26.7.

## Scripts

- Write output that a script reads back from `swift test` in ASCII, to the standard error where XCTest writes its own lines. `swift test` passes a test's output on in 4096-byte chunks and drops any chunk that isn't valid UTF-8 by itself, so a multi-byte character split between two chunks silently loses both. It also passes the standard output and the standard error on in separate threads, so a chunk of one can land inside a line of the other. The output can stop being ASCII once [swift-package-manager#10636](https://github.com/swiftlang/swift-package-manager/issues/10636) is fixed in the Xcode that CI uses, but it stays on one stream.
- Create a git worktree next to the repository and run `make bootstrap` in it before formatting, linting or committing there, since the hook, lint and format scripts and the tools in `bin/` are gitignored, and only bootstrap installs them. Don't create it under `/tmp`, where lint also lints the `.build` directories, which fails the pre-commit hook. Verified with SwiftLint 0.65.1 on macOS 26.7.

## Docs

- Match content to the section's altitude: overview sections get a couple of high-level sentences, mechanics and specifics go in the section that owns them.
- A CHANGELOG entry is for a change users would notice or need to act on, in a sentence or two that name the feature or fix, with a link to the PR, which holds the details. Leave out how it works, its tuning and its edge cases, and internal details, such as an edge-case fix that makes one more code path follow a rule the API already documents.
- Judge CHANGELOG entries against the last release, not the previous commit. Users only see released behavior, so a change to behavior that's still unreleased gets no entry of its own: update the entry that introduced the behavior when what it describes changes, and add nothing when the change only corrects it. Otherwise entries pile up for intermediate states no user saw.
- A `//` comment right above a declaration reads as the declaration's documentation. Put a comment that explains how the code works inside the body, next to the code it explains, or where the code relies on it, such as the line that builds a value, and keep a declaration's documentation to what the declaration is.
- Verify a learning on every platform that it covers, instead of noting where it was checked. Name a platform only for a claim that's unverified on another platform, and a version only for behavior that a newer version can change, such as AppKit's reset of a view's layer transform.

## Design decisions

- Question the premise before designing around it: when an existing behavior drives a decision, first check whether that behavior is intentional (documented, tested for its own sake, or explained in history) or incidental. Incidental behavior is a candidate to change, not a constraint to satisfy.
- Surface rejected alternatives: when you consider an option and drop it for scope, cost, or risk, state it in one line with the reason. A silently dropped alternative takes the decision away from the reviewer.
- Treat API surface as a variable, not a constraint: when a fix adds compensating logic (invalidation, special cases, extra cache keys) only so that a public type or option stays safe to misuse, first find who can reach that misuse. If only callers outside the module can, propose removing or narrowing the API next to the compensating fix, with the cost of each, before implementing either. Compatibility kept by default is the option that hides its cost.
- Don't add complexity for unsupported input or misuse: handling rare incorrect input isn't the framework's job, even when a review finds a case. Call it out where it enters instead, with a debug assertion and a documented restriction, and recover only where that's simple and cheap, such as an entry point keeping its current value when a callback changes the settings an operation is applying. Tolerating the input takes retries, guards or extra state, and each correction tends to expose the next case, while the restriction removes the whole class.
- Enumerate a system's inputs before replacing its evaluation: when computed logic replaces what a system evaluates, list every kind of input the system honors, decide for each whether the logic models it or falls back, and test each decision. An input the logic silently misreads gives a wrong result where the replaced path gave a right one, and nothing flags it, such as a Core Animation group that a computed presentation value doesn't see.
- Check whether an input applies before requiring it to be supported: an input that has no effect, such as an animation that hasn't begun, shouldn't force a fallback or a failure only because the logic can't evaluate it.
- Before changing a heuristic for an input that it handles badly, list the kinds of input that it must handle, and check each change against all of them in one table test, as `PendingNodesTests` does with shapes of loop: a rule that fixes the reported input can break another kind, which a test of that input alone doesn't show. State the heuristic's worst case too, such as a few more growths and a copy for a buffer's size, so that an input that it handles within that bound is a documented trade-off instead of a bug, and the tuning stops.
- Keep the cause of a change from where it's known, instead of inferring it from the combined result: once changes are added up or merged, the result can't say which part came from where, and a guess goes wrong wherever causes overlap. When later logic treats parts differently by cause, record each part's cause when it's made, as a frame animation records whether it moves the origin or the size.
- Keep debug-only code out of release builds by construction: put its type inside `#if DEBUG` and wrap each call site, as the render pass does for `debug?.onEvent`, instead of calling a function whose body is empty in release. The optimizer may delete the empty call, but the source doesn't show it, and only a machine code comparison proves it.
- Code that a change leaves without callers isn't dead by default: before removing it, check whether it was designed as an entry point, such as a convenience factory with chosen defaults. Keep a designed entry point, and route the new code through it instead of around it, so the change extends the design rather than leaving it unused.
- Replacing an object per owner with one shared object turns every owner into a path back to it: a value in the shared object that keeps any owner, such as a closure that captures one, keeps the shared object alive in a cycle, where with separate objects only a value that keeps its own owner would. Instead of guarding each path back, give the owners no reference to the shared object: hand each owner a number for its place in it, and reach it through its holder only while it's in use, as the slots of `RenderableItemCache` and `ComposeView.LayoutCacheNode` do.
- A protocol that value types usually conform to can still have class conformers, since Swift can't restrict a protocol to value types, so a copy of a protocol-typed value can share an object with the original. A fix that relies on such a copy, such as capturing a value before it changes, must also hold when the copy and the original are the same object.
- An object that normalizes what's stored in it doesn't hold its input, so comparing it with the next input finds changes that aren't there, such as a text storage that gives a substitute font to the characters their font lacks. To skip work for an unchanged input, compare the input with a copy of the last input, as `BaseTextView` does, and compare with the object only when something else may have changed it, after applying the same normalization to the input.
- Give each component one job, so that it can change or be replaced without touching the others. The render engine, `ComposeView` and the core types, never names a specific node or its rules, such as a label's default font or its image cache. A node that needs state for a view, a refresh or a pass gets it through what the engine already gives every node, such as the layout context, the content evaluation or a render item's blocks, and keeps its own rules in its own types, as `LabelNode` reads the Bold Text setting once for each layout pass, which it tells by the layout context's pass id. When nothing carries the state yet, add a hook only as general as its uses need, since a registry or a plug-in API for one use is over-engineering, and measure the decoupled design against the coupled one, since it has to be as fast. Before calling a change done, check that no core type calls a specific node.
- Measure an alternative design's ceiling before building the checks that make it safe: leave them out, measure, and build them only when the ceiling beats the current design.

## Layout

- Measure a size from the parts' own extents, not from the union of their placed frames: the frames depend on the space the parts are placed in, such as lines aligned to opposite edges of a wider container, so their union spans more than the parts need. Text measurement takes the widest line for this reason.

## Text

- A UIKit text view that scrolls doesn't make its text container taller when the view gets taller: it changes the container's height only when scrolling turns on or off, or when the width changes. So a container made as tall as the frame cuts off the text once the view grows, such as when it's reused for a taller text. Give the container an unlimited height, as UIKit's own text views have and `BaseTextView` does. A text view that scrolls also has non-contiguous layout on, which breaks a line limit in that unlimited height, so turn it off while the text has a line limit. Verified with Xcode 27.1 on iOS 26.5 and 27, unverified on tvOS and visionOS.
- TextKit 1 takes a text container's line break mode as the way the last line ends, and gets character wrapping wrong there: without a line limit, the lines break between words, and with one, the paragraph at the limit goes on past it, also in a plain `UITextView` or `NSTextView`. TextKit 2 breaks between words. To break every line between characters and keep the limit, as `UILabel` does, keep the container at word wrapping and have the layout manager's delegate refuse each break between words, as `NSLayoutManager.setLineBreakMode(_:in:)` does. Verified with Xcode 27.1 on macOS 26.7 and iOS 27, unverified on tvOS and visionOS.
- A layout manager doesn't lay out its text again when only its delegate changes. Call `textContainerChangedGeometry(_:)`, as a change of the text container does, and `invalidateDisplay(forCharacterRange:)` before it, while the old layout still tells where the text is drawn: without it, an AppKit text view without background layout keeps its old lines on screen. Verified with Xcode 27.1 on macOS 26.7 and iOS 27, unverified on tvOS and visionOS.

## Result builders

- A generic type with a parameter pack needs the Swift 5.9 runtime, which macOS 14, iOS 17 and tvOS 17 have, while a function with a parameter pack runs on older systems. To take any number of components on older systems, take them as a pack in a function, as `ComposeContentBuilder.buildBlock` does, instead of returning a type that holds them.
- A `for` loop in a result builder can't collect iterations whose type involves an opaque result type: the compiler rejects the loop, since it can't infer the opaque type's underlying type. A builder that keeps its components' types erases them by the end of each loop iteration, so that a loop over rows returned as `some P` compiles.
- For an argument of a concrete type, a non-generic overload that takes an existential wins over a generic overload, and an existential argument opens into the generic parameter of an overload whose constraint its protocol satisfies, which wins over a disfavored overload. To keep concrete types on a generic overload and existentials on overloads of their own, mark the existential overloads `@_disfavoredOverload`, and don't add a generic overload that a refining protocol's existential opens into, as a generic overload for `ComposeContent` would take every `any ComposeNode`. Check each kind of argument with a small model whose overloads record which one runs.
- A result builder keeps each statement's value in a `var`. In a loop body, the array append that follows the block keeps the optimizer from moving that value into a `consuming` parameter, so it copies the value and destroys the original at the end of the iteration, which retains and releases each of its references, while the same calls with a `let` move it. `@_eagerMove` on the value's type doesn't change this. Count a loop body's copies in the optimized machine code before relying on a move.
- A result builder's calls for one body don't run as one synchronous unit. The compiler accepts an `async` builder function, which can suspend between statements and resume on another thread while other builds run on the first one, and a `throws` one, whose throw drops the values its earlier statements made. State that the calls share outside their values, such as a per-thread buffer that blocks write into, has to stay out of tasks and survive what a throw drops, as `PendingNodes` does. Check for a task at each call instead of once per build, since a task that `Task.immediate` starts runs until its first suspension inside the build that started it. Test such a design with an async builder function that awaits between rows in many tasks at once, on the main actor and off it, with a task started immediately in the middle of a build, and with a throw that a statement of another body catches.

## Linking

- A static link takes an object file from an archive only when another object references one of its symbols, so code that the runtime finds by scanning the binary disappears silently when nothing references its file. That includes Objective-C categories, which Swift makes for an extension's `@objc` members, and Swift conformances that only dynamic casts use. Keep such code in a file that's referenced anyway, such as overrides in the class body instead of an extension, or a conformance in the type's own file, instead of relying on the app's link flags. A debug build, or a module prelinked into one object as SwiftPM does, can hide the drop, so check with `nm -m` that another object of a release build references the file.
