---
name: exhaustive-unit-tests
description: Generate thorough Swift unit tests (XCTest) for a target source file by identifying behaviors, branches, edge cases, and failure paths, then implementing and validating tests. For ViewModels, reuses an existing test class when present or adds a dedicated test file and wires it to the test target. Use when the user asks to add unit tests, improve test coverage, or create all likely unit test cases for a Swift file.
disable-model-invocation: true
---

# Exhaustive Unit Tests

## Goal

Create practical, high-confidence **Swift** unit tests for one target file. "All possible" means all meaningful behaviors and branches that can be verified with unit tests in the current codebase. Use **XCTest** and project test targets (e.g. `*Tests`).

## Inputs To Collect

Before writing tests, gather:

1. Target file path.
2. Expected behavior (from code and adjacent docs/tests).
3. Project conventions: test target name, test file location, naming style, and any existing mock helpers.
4. Any constraints (mocking style, `@MainActor` / concurrency rules, forbidden integration calls).

If target behavior is ambiguous, ask focused clarification questions before implementation.

## Workflow

Copy this checklist and execute it end-to-end:

```text
Unit Test Progress
- [ ] Step 1: Read target file and dependencies used at runtime
- [ ] Step 2: Build a test case matrix for all branches/paths
- [ ] Step 3: Locate or create the test file — for ViewModels / a single focal type, follow "ViewModels: test file placement"; otherwise follow the repo's pattern for that module
- [ ] Step 4: Implement or extend tests (XCTest)
- [ ] Step 5: Run tests and fix failures
- [ ] Step 6: Report coverage gaps, assumptions, and next tests
```

## Step 1: Analyze Behavior Surface

Identify:

- Public types, methods, and properties.
- Conditional branches and guard clauses.
- Error paths (`throws`, `Result`, `nil` handling, invalid inputs).
- State transitions and side effects (writes, `Task`/`async`, callbacks, `Timer`, Combine).
- Boundary conditions (empty input, min/max values, time/random edges).

Prefer a behavior inventory rather than line-by-line mirroring implementation details.

## Step 2: Build a Test Case Matrix

Create test cases grouped by behavior:

1. Happy path outcomes.
2. Branch-specific outcomes for each conditional path.
3. Validation and invalid-input behavior.
4. Error handling and exception propagation.
5. Edge/boundary values.
6. Interaction tests for collaborators (mocks, spies, protocol fakes).
7. Determinism tests (idempotence, ordering, stable output) where relevant.

Use table-driven tests or `XCTParameterize` (or explicit loops) when many inputs map to one assertion pattern.

## ViewModels: test file placement

When the target is a **ViewModel** (or any single type like `ObservableObject` / `*ViewModel`):

1. **Search for an existing test class** for that type before writing code:
   - Grep the repo's unit test targets (`*Tests`, `Tests/` folders) for the type name (e.g. `ContentViewModel`).
   - Look for `XCTestCase` subclasses whose names match `*ViewModelTests` / `<TypeName>Tests`, or that `@testable import` the app module and construct that ViewModel type.

2. **If a matching test class exists**: **Update** it — add or revise test methods to cover the matrix. Do **not** create a duplicate second test class for the same ViewModel unless the project already uses that split.

3. **If none exists**: **Create a new test file** dedicated to that ViewModel (e.g. `ContentViewModelTests.swift`) with a single `XCTestCase` subclass. Use `@testable import <AppModule>` as the project does elsewhere.

4. **Wire the file into the unit test target**: ensure the new file is a member of the correct Xcode test target (`project.pbxproj`) or SwiftPM `testTarget` sources. Without this, tests will not compile or run.

5. In the final report, state explicitly whether tests were **extended** in place or **new file added**.

## Step 4: Implement Tests (XCTest)

Implementation rules:

- Keep tests focused: one behavior per test.
- Use descriptive names; match repository style (`test_whenFoo_thenBar` or similar).
- Respect Swift concurrency: `@MainActor` on test classes when testing `@MainActor` code; avoid crossing actors incorrectly.
- Mock or stub external systems (network, filesystem, time, randomness) where needed.
- Assert both return values and observable side effects.
- Avoid brittle assertions tied to private implementation unless necessary.

When practical, include both:

- Positive assertions (expected result).
- Negative assertions ("does not call X", `XCTAssertThrows` for invalid input).

## Step 5: Validate By Running Tests

Run the smallest relevant test command first (often `xcodebuild test` for one scheme or one test class), then broader suite if needed.

If tests fail:

1. Determine whether failure is in new tests or production code.
2. Fix test reliability first (main-thread timing, bad mocks, flaky `Timer`/`async` waits).
3. Adjust assertions to match intended behavior, not incidental implementation.
4. Re-run until stable.

If CoreSimulator errors appear when targeting iOS simulators, use a fixed destination UDID, `-parallel-testing-enabled NO`, or run unit tests on `platform=macOS` when the scheme supports it.

## Step 6: Final Output Format

After changes, report:

- What test file(s) were added/updated.
- Behavior categories now covered.
- Any meaningful coverage gaps that remain and why.
- Assumptions made where behavior was ambiguous.

## Quality Bar

A strong result should:

- Cover all identifiable branches and error paths in the target file.
- Include edge cases for each input domain.
- Verify collaborator interactions where behavior depends on them.
- Be deterministic and non-flaky.
- Match existing project and XCTest conventions.

## Quick Invocation Examples

- "Use `exhaustive-unit-tests` for `Features/Auth/LoginViewModel.swift`."
- "Apply `exhaustive-unit-tests` to `test_app/ContentViewModel.swift`."
- "Run `exhaustive-unit-tests` on `PackageSources/MyLib/Parser.swift`."
