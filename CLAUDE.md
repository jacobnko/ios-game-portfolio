# CLAUDE.md — iOS Casual Game Portfolio

This repository holds a **shared architecture plus a set of small casual/puzzle game apps** (10 planned).
Its reason to exist is simple: every game shipped should require less new code than the one before it.

---

## 0. First Principles

1. **Shared code lives in `CoreKit`. Game-specific code lives in `Apps/<Game>`.** If a piece of code would be useful in game #2, it belongs in `CoreKit`.
2. **DDD — Dopamine-Driven Development.** A raw mechanic without juice is not "done". Never report a feature as working before `JuiceManager` is wired into it.
3. **Every app must look deliberately different.** This is the structural mitigation for App Store Guideline 4.3 (template spam).
4. **Claude Code does not produce design assets.** Icons, illustrations, and visual UI are handed off to Claude Design (§6).

---

## 1. Code Style

- **ALL code comments must be in ENGLISH only.** No exceptions.
- Every new source file starts with a **one-line English comment stating its role**:
  ```swift
  // Manages the haptic + audio feedback pipeline shared by every game.
  ```
  > Decision: the global "Korean file header" rule is overridden here in favor of English,
  > because this repo is public portfolio code and must stay consistent with the English-only comment rule.
- Conversation and the working docs (`PLAN.md`, `checklist.md`, `context-notes.md`, design handoffs) are written in Korean. This file, code, identifiers, and commit subjects are English.
- Target **Swift 6 strict concurrency**. Default to `@MainActor` isolation; do not leave `Sendable` warnings behind.
- **Never hardcode display strings.** Use `String(localized:)` / `LocalizedStringKey` backed by `.xcstrings` from day one.

### SwiftUI view conventions
- Body frame width `380`, Preview frame `400 x 600`, `.preferredColorScheme(.light)`.
- Exception: full-screen gameplay views. These conventions apply to component and documentation views only.

---

## 2. How To Work (non-negotiable)

1. For any non-trivial task, produce **Plan → `checklist.md` → `context-notes.md`** before writing code.
2. **Work step by step.** At the end of each step:
   - present a **CHECKLIST** the user can verify personally,
   - **commit the step's work automatically** (see Commits below) — never hand the user git commands to run by hand,
   - **wait for the user's confirmation** before moving on.
3. **If code was touched, run `./scripts/verify.sh` before saying "done".**
   `swift test` alone is not enough: it builds for the host, so everything behind
   `#if canImport(UIKit)` is never compiled. The script adds real iOS builds.
4. **Anything a human must feel or see — haptics, audio, animation timing — is not verifiable from here.**
   Add it to `Tools/JuiceLab` and hand the user a concrete checklist of what to feel.
   Haptics never fire in the Simulator, so "it builds" is not "it works".
5. **At the end of every phase, run the audit** — `./scripts/audit.sh`, then the reading
   pass in `docs/AUDIT.md` §4. Phase 1 shipped 15 defects past a green build; four of
   them were invisible to reading and one was invisible to everything but running the app.
6. **A game's core-logic phase (Phase 3 for game #1, the equivalent phase for every game
   after it) does not end until the real Xcode app project exists.** Up through that
   phase the game is SPM packages only — `swift test` and Xcode Live Preview are the only
   verification available, and neither one can prove haptics, audio, real drag input, or
   CloudKit sync actually work. The closing step, every time, is:
   1. Follow `docs/architecture/new-game-setup.md` to generate `project.yml` +
      `Info.plist` + the app entry point (XcodeGen), wiring the game's one bespoke
      screen into the five shared `CoreKitUI` screens.
   2. Build for a real device destination (`xcodebuild ... -destination
      'generic/platform=iOS' build`) to confirm it compiles outside of SPM.
   3. Hand off to J with `docs/DEVICE-TEST.md`. **J does the on-device running and
      testing — Claude does not drive a real device, and a passing Simulator build
      is not a substitute.**
   Only after that handoff does the phase actually close and the release-pipeline phase begin.
7. **Read the actual error output before fixing.** Do not pattern-match a "common fix" from the error keyword.
8. **Surgical changes only.** No improving adjacent code, no unrequested refactors, no reformatting. Report dead code; do not delete it.
9. Korean sentences end with `.`, `?`, or `!` — never a trailing `:`.

### Commits
- **Claude commits automatically.** Staging and committing is part of finishing a step, not a task handed back to the user.
- **Never add an AI attribution trailer.** No `Co-Authored-By`, no "Generated with" footer, no emoji sign-off. The commit message is the subject line and, when useful, a short body — nothing else.
- Commit one logical change at a time, describable in a single sentence.
- Good: `feat(corekit): add haptic feedback pipeline`
- Bad: a commit mixing juice, ads, and a bug fix — split it into three.
- Use Conventional Commit prefixes: `feat` / `fix` / `refactor` / `docs` / `chore` / `test`. Scope with the module when it helps: `feat(corekit): ...`
- **Push automatically too.** J has authorized push for this repository, so `git push` follows the commit as part of finishing a step.
- **This repository is public.** Before any push, verify no secret, real Ad Unit ID, or service config entered the diff — a pushed secret must be revoked, not just deleted.

---

## 3. Repository Layout

```
00_Games/
├─ CLAUDE.md            # this file — working rules
├─ PLAN.md              # full roadmap — GITIGNORED, private
├─ checklist.md         # progress checkboxes, updated at the end of each step
├─ context-notes.md     # decisions and their rationale, append-only
├─ docs/
│  ├─ concepts/         # game concepts and brand names — GITIGNORED, private
│  ├─ design/           # Claude Design handoff documents (§6)
│  ├─ architecture/     # CoreKit module design notes
│  └─ decisions/        # ADRs, for hard-to-reverse decisions only
├─ Tools/
│  └─ JuiceLab/         # harness app — feel CoreKit's feedback on a real device
├─ Packages/
│  └─ CoreKit/          # local SPM package imported by every game
└─ Apps/
   ├─ JuicyFlow/        # Game #1
   └─ .../              # Games #2–10
```

- Each game is its own standalone Xcode project. `CoreKit` is attached as a **local package reference** (`../../Packages/CoreKit`).
- Games never depend on each other. All sharing goes through `CoreKit`.

---

## 4. Tech Stack Selection Rule

| Genre | Stack | Criterion |
|---|---|---|
| Grid / state-based logic puzzle | **SwiftUI only** | No physics required |
| Physics, collision, or motion as the core mechanic | **SpriteKit** via `SpriteView` | Physics *is* the game |

The decision axis is **"physics-driven vs. state-driven"**, not "UIKit vs. SwiftUI".

---

## 5. Hard Rules (accident prevention)

- **Use Google's official test Ad Unit IDs for the entire development cycle.** Swap in production IDs only immediately before release. Repeatedly viewing your own live ads counts as invalid traffic and risks account suspension.
- **The AdMob banner must reuse a single `GADBannerView` instance held by the `Coordinator`.** Creating it inside `updateUIView` causes the banner to reload and flicker on every parent state change.
- **`Transaction.currentEntitlements` is the only source of truth for ad removal.** Never trust a local cache or a CloudKit-synced flag. Query it asynchronously on every launch.
- **Every `@Model` property synced via CloudKit must be optional or have a default value,** and `@Attribute(.unique)` is unsupported.
- **"Restore Purchases" must actually work.** It is a guaranteed rejection point otherwise.
- **Failure animations stay slapstick — cartoonish and bloodless.** Realistic violence raises the age rating and can restrict ad category eligibility.
- **Never override the `AppleLanguages` UserDefaults key.** Send the user to the system Settings app for per-app language changes.

---

## 6. Design Handoff (Claude Design)

- When work on a game's structure **begins**, create its handoff folder at `docs/design/<NN-game-name>/` first.
- Claude Design is token-expensive, so **never hand it the whole game in one prompt.** Copy the **D1–D6 step cards** defined in `docs/design/README.md` into separate sessions, one at a time.
- Claude Code writes **only the handoff documents** (specs and prompt cards). It does not generate artwork.
- Delivered assets land in `Apps/<Game>/Resources/`, and the corresponding item in `checklist.md` is ticked on arrival.

### The screen-building gate (non-negotiable)

**No screen is implemented from a guess.** A game's core-logic phase splits into
two kinds of work, and they are not allowed to run in the same order Chordline's
did:

- **Logic work** — board/state model, solver, gesture mechanics, save/ad/juice
  wiring. This has no visual layout of its own and may start as soon as the
  phase does, in parallel with the design track.
- **Screen work** — Home, Stage Select, Settings, Result, and the game's own
  bespoke gameplay chrome (HUD, board rendering, controls). **This does not
  start until D3 (gameplay screen) and D4 (supporting screens) are delivered
  and reviewed.** A screen built before its mockup exists gets built *again*
  once the mockup arrives — Chordline built five screens once from logic alone,
  then rebuilt every one of them against D3/D4/D5 after the fact. That is not
  iteration, it is the same work twice, and the first pass is pure loss.

If a step needs a screen and the mockup is not ready yet, the step waits or
Claude Design is prompted for that card next — it does not proceed on a
placeholder that "looks reasonable." A component that only ever shows numbers
or state during logic testing (a debug list, a plain `Text`) is not a screen
and is exempt; the moment it is dressed up to look like the real thing, it
counts as screen work and the gate applies.

Checklist and `PLAN.md` steps for every game after Chordline are written to
this order explicitly — see `PLAN.md`'s Phase 5 cycle.

---

## 7. Model Usage Strategy

Every switch below is a **concrete, checkable trigger** — Claude states in chat
that the trigger was hit and which direction it is proposing, rather than
switching silently or waiting to be asked. J still makes the call; Claude
raises it.

### Opus 5, effort high

- **Phase 1, always.** `CoreKit` + `JuiceManager` skeleton, StoreKit 2 manager,
  SwiftData/CloudKit schema, AdMob wrapper — the decisions every later game
  inherits without re-deriving them.
- **Any time a game's Phase 3-equivalent needs a new `CoreKit` capability
  designed from scratch**, not just consumed. Extending an existing pattern
  (a new `ThemeColor`, a new `JuiceStep` weight) is not this; inventing a new
  one (a new persistence shape, a new cross-cutting service) is.
- **Any defect whose root cause is a `CoreKit`-level decision**, not a
  game-local bug — the kind `docs/AUDIT.md` catalogues, where the fix changes
  behaviour every game inherits.
- Whenever J asks for it directly.

### Sonnet 5, effort medium

- **Everything else** — routine implementation, including screen work built
  against an already-delivered design mockup (§6). Reading a design spec's
  exact values and translating them faithfully into SwiftUI is not, on its
  own, a reason to escalate: this session's D3/D4/D5 rebuild ran on Sonnet
  without trouble once the mockups existed. The failure mode that actually
  hit Chordline's UI (screens built once with no mockup, then rebuilt once
  the mockup existed) was a **sequencing bug — the screen-building gate in
  §6 — not a model-capability problem.** Do not treat "the UI needs polish"
  as a reason to escalate; treat a missing design brief as a reason to stop
  and wait for one.

### The switch point, concretely

The proactive Opus → Sonnet switch happens once a game's core loop first runs
end-to-end **on the host** — win/lose state reachable, at least one juice
moment wired and feelable in `Tools/JuiceLab` — which is the "게임 로직 구현"
step in the Phase 5 cycle (`PLAN.md`) for every game after Chordline, matching
what closed out as S3.9 for Chordline itself. Claude names the step, states
the trigger explicitly, and proposes the switch there — it does not wait for
the phase to fully close (§2 item 6) first.

---

## 8. Nicknames

| Nickname | Refers to |
|---|---|
| **J** | the user (jacobko) |
| **C** | Claude |
