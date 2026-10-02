---
description: Guided code change — behaviour, state, logic, data or services (tests first, MVVM, on-device).
argument-hint: [feature or area — what should change]
---

You are making a production code change to FamilyFood, a native iOS (SwiftUI) app. Favour small,
well-tested, idiomatic changes that respect the MVVM, feature-based structure.

**What should change:** $ARGUMENTS

If that is empty or unclear, ask for the feature or area, the new behaviour, and — for a bug —
what happens now versus what is expected. Ask one question at a time.

## 1. Orient

1. Read `CLAUDE.md`, and `docs/ARCHITECTURE.md` for the area you will touch. For anything
   user-facing, read `docs/DESIGN-SYSTEM.md` too.
2. Find where the behaviour lives: View (`FamilyFood/Features/<Feature>/Views/`), ViewModel
   (`…/ViewModels/`), Service (`FamilyFood/Services/`), Model (`FamilyFood/Models/`).
3. Read the existing tests for that code in `FamilyFoodTests/`. They are the current contract.
4. Trace state and persistence to its single source of truth before changing anything, and
   check what else reads it.

## 2. Propose

State the plan before editing:

- which layer changes, the source of truth you will edit, and what else reads it;
- what happens to data already stored on a device by an earlier build (there is no server to
  reconcile against);
- the edge cases (empty week, no recipes, week boundaries, no kindergarten plan, first launch);
- the tests you will add or change.

For a bug, reproduce it with a failing test before proposing a fix.

## 3. Implement

- Tests first for view models, services and models: write the failing test, watch it fail for
  the right reason, then write the minimal code to pass.
- Keep shared logic in `Services/` and `Models/`. Use `AppTheme` tokens, never literal values.
- No network calls for core data, no new dependencies, no credentials in code or tests.
- If `project.yml` changed, run `xcodegen generate`. Never edit the `.xcodeproj` by hand.

## 4. Verify

- Run `scripts/test.sh` and report the real result — pass and fail counts.
- Show the new behaviour, not only that it compiles. For first-launch or default-state changes,
  check from a clean install.
- Say what was verified and what still needs a manual or device check.

## 5. Hand over

Summarise the change for a pull request: what changed and why, how it was tested, screenshots
for UI changes, and that an AI assistant was used.
