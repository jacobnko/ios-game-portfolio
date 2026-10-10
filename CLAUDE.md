# CLAUDE.md — iOS Casual Game Portfolio

This repository holds a **shared architecture (`CoreKit`) plus small casual/puzzle game apps**, built one at a time.
Its reason to exist: every game shipped should require less new code than the one before it.

- **Game #1 — Chordline**: shipped.
- **Game #2**: in progress. Its codename, concept, and plan live only in the private documents (§9).
- The original 10-game roadmap was cancelled on 2026-10-11 (`context-notes.md` D-113). Games are now added one at a time.

---

## 0. First Principles

1. **Shared code lives in `CoreKit`. Game-specific code lives in `Apps/<Game>`.** If a piece of code would be useful in the next game, it belongs in `CoreKit`.
2. **DDD — Dopamine-Driven Development.** A raw mechanic without juice is not "done". Never report a feature as working before `CoreKitJuice` is wired into it.
3. **Every app must look deliberately different.** This is the structural mitigation for App Store Guideline 4.3 (template spam). The private palette ledger (§9) is checked before any palette is locked.
4. **Two tracks: design and code.** J designs in Claude Design (web) and may run it first; Claude Code writes the briefs, specs and code and finishes the look in code (SwiftUI shaders, particles). Only CC0 / OFL third-party assets are imported. Claude Code never generates raster artwork (§7).
5. **Reuse before writing.** Haptics, synthesized audio, VFX, progress storage, purchases, review prompts, notifications, sharing, localization, and the shared screens already exist. Consume them. If a game finds itself re-implementing one of those, the fix goes into `CoreKit`, not the game.

---

## 1. Code Style

- **ALL code comments must be in ENGLISH only.** No exceptions.
- Every new source file starts with a **one-line English comment stating its role**:
  ```swift
  // Manages the haptic + audio feedback pipeline shared by every game.
  ```
  > Decision: the global "Korean file header" rule is overridden here in favor of English,
  > because this repo is public portfolio code and must stay consistent with the English-only comment rule.
- Conversation and the working docs (`PLAN.md`, `checklist.md`, `context-notes.md`, design briefs) are written in Korean. This file, code, identifiers, and commit subjects are English.
- Target **Swift 6 strict concurrency**. Default to `@MainActor` isolation; do not leave `Sendable` warnings behind.
- **Never hardcode display strings.** Use `String(localized:)` / `LocalizedStringKey` backed by `.xcstrings` from day one. Fill every language the game ships at the moment the key is written (the game's `PLAN.md` lists them: game #1 ships 7, game #2 ships English only).
- Deterministic procedural content uses `CoreKit`'s own seeded generator and its own shuffle. Never `Hasher`, `hashValue`, or `SystemRandomNumberGenerator` for anything that must reproduce from a seed.

### SwiftUI view conventions
- Body frame width `380`, Preview frame `400 x 600`, `.preferredColorScheme(.light)`.
- Exception: full-screen gameplay views. These conventions apply to component and documentation views only.
- **Layouts are derived from the container size, never from a device model or a hardcoded 393×852.** Screens of a game that ships on iPad adapt by size class and available size (`GeometryReader` / `horizontalSizeClass`), in both orientations, and keep their state across rotation.

### Device targets
- **iPhone-only is the default.** A game ships on iPad only when its `PLAN.md` says so.
- **Never declare iPad (`TARGETED_DEVICE_FAMILY` containing `2`) without having laid it out and run it.** Chordline once declared it as an overclaim and had to pull it back (`Apps/Chordline/project.yml`).
- **Reference iPad is the iPad mini (8.3-inch, 744×1133pt portrait)** — it is the device J owns, so it is both the Simulator destination (`iPad mini (A17 Pro)`) and the on-device test. Larger iPads must still not break (layouts are size-derived), but they are verified by Simulator only, if at all.

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
   pass in `docs/AUDIT.md` §4. Phase 1 of Chordline shipped 15 defects past a green build.
6. **A game's core-logic phase does not end until the real Xcode app project exists.** Up through that
   phase the game is SPM packages only — `swift test` and Xcode Live Preview cannot prove haptics,
   audio, real drag input, purchases, or CloudKit sync. The closing step, every time, is:
   1. Follow `docs/architecture/new-game-setup.md` to generate `project.yml` + `Info.plist` + the app entry point (XcodeGen).
   2. Build for a real device destination (`xcodebuild ... -destination 'generic/platform=iOS' build`).
   3. Hand off to J with `docs/DEVICE-TEST.md`. **J does the on-device testing — a passing Simulator build is not a substitute.** For a game that ships on iPad, the handoff covers the iPad mini as well as the iPhone.
7. **Read the actual error output before fixing.** Do not pattern-match a "common fix" from the error keyword.
8. **Surgical changes only.** No improving adjacent code, no unrequested refactors, no reformatting. Report dead code; do not delete it.
9. Korean sentences end with `.`, `?`, or `!` — never a trailing `:`.

### Token discipline
- **One model per session.** When the step's model tag changes (§8), the next step starts in a new session.
- A new session reads `CLAUDE.md`, the current step in `PLAN.md`, and the game's `checklist.md` — nothing else up front.
- **Never read `context-notes.md` whole.** `grep` for the D-number or keyword and read that block only.
- Do not survey `CoreKit` sources. `PLAN.md`'s reuse map already says which type to use; open only the one file whose signature you need.

### Commits
- **Claude commits automatically.** Staging and committing is part of finishing a step, not a task handed back to the user.
- **Never add an AI attribution trailer.** No `Co-Authored-By`, no "Generated with" footer, no emoji sign-off. Subject line and, when useful, a short body — nothing else.
- Commit one logical change at a time, describable in a single sentence. Conventional Commit prefixes: `feat` / `fix` / `refactor` / `docs` / `chore` / `test`, scoped when it helps: `feat(corekit): ...`
- **Push automatically too.** J has authorized push for this repository and the game repositories.
- **This repository is public.** Before any push, verify the diff carries no secret (API keys, real Ad Unit IDs, service configs) and no unreleased brand name or mechanic (§9). A pushed secret must be revoked, not just deleted.

---

## 3. The Two Tracks

```
Track B · Design (J, web + session)   brief → palette (G1) → icon (G3) → gameplay screen → supporting screens → juice spec ══ G2 ══╗
                                                                                                                                  ▼
Track A · Code (Claude Code)          rules ───────────────────────────────────────────────────── CoreKit gaps → core logic → screens → integration → Xcode app → release
```

- **Graphics-first is allowed and is the default when J wants it.** J runs Track B ahead of Track A so the UI and assets are settled before code starts; that avoids rework. Only the rules-confirmation step (what the game *is*) must precede the screen cards, because the screens depend on it.
- Track A's **screen** work never starts before gate G2 (§7). Logic work may start earlier when J chooses to spend tokens that way.
- Each game's `PLAN.md` lists the gates (G1–G5) and which step each one unblocks.
- A design delivery is a **picture plus numbers**. Before screen work, Claude writes a layout spec in points from the delivered screens, and J approves it. When picture and spec disagree, the spec wins.

---

## 4. Repository Layout

```
00_Games/
├─ CLAUDE.md            # this file — working rules (public)
├─ PLAN.md              # current game's roadmap — GITIGNORED, private
├─ checklist.md         # portfolio/CoreKit-level progress
├─ context-notes.md     # portfolio/CoreKit-level decisions, append-only
├─ docs/
│  ├─ concepts/         # game concepts, rules, palette ledger — GITIGNORED, private
│  ├─ design/           # README (public) + per-game briefs and raw assets (GITIGNORED)
│  ├─ architecture/     # CoreKit and process notes
│  └─ decisions/        # ADRs, for hard-to-reverse decisions only
├─ Tools/JuiceLab/      # harness app — feel CoreKit's feedback on a real device
├─ Packages/
│  ├─ CoreKit/          # local SPM package imported by every game
│  └─ CoreKitFirebase/  # optional analytics adapter (only games that use Firebase)
└─ Apps/                # each game is its own git repository (docs/architecture/repo-strategy.md)
   ├─ Chordline/        # Game #1
   └─ <Game>/           # Game #2 — its own checklist.md and context-notes.md
```

- Each game is its own standalone Xcode project with `CoreKit` as a **local package reference** (`../../Packages/CoreKit`).
- Games never depend on each other. All sharing goes through `CoreKit`.
- A game imports only the `CoreKit` products it needs. A game without ads does not import `CoreKitAdsGoogle` and skips every ad, ATT, UMP, and SKAdNetwork step.

---

## 5. Tech Stack Selection Rule

| Genre | Stack | Criterion |
|---|---|---|
| Grid / state-based logic puzzle | **SwiftUI only** | No physics required |
| Physics, collision, or motion as the core mechanic | **SpriteKit** via `SpriteView` | Physics *is* the game |

The decision axis is **"physics-driven vs. state-driven"**, not "UIKit vs. SwiftUI".

---

## 6. Hard Rules (accident prevention)

**Purchases and data**
- **`Transaction.currentEntitlements` is the only source of truth for any purchased entitlement** (ad removal, full-game unlock). Never trust a local cache, a Keychain flag, or a CloudKit-synced flag. Query it asynchronously on every launch. StoreKit 2 already serves it offline from the device.
- **"Restore Purchases" must actually work.** It is a guaranteed rejection point otherwise.
- **Every `@Model` property synced via CloudKit must be optional or have a default value,** and `@Attribute(.unique)` is unsupported.
- Store copy claims only what the code verifiably does (`next-game-handoff.md` §6.3).

**Ads (only games that ship ads)**
- **Use Google's official test Ad Unit IDs for the entire development cycle.** Swap in production IDs only immediately before release.
- **The AdMob banner must reuse a single `GADBannerView` instance held by the `Coordinator`.** Creating it inside `updateUIView` makes the banner reload and flicker on every parent state change.

**Content and platform**
- **Failure animations stay slapstick — cartoonish and bloodless.** Realistic violence raises the age rating.
- **Never override the `AppleLanguages` UserDefaults key.** Send the user to the system Settings app for per-app language changes.

**Third-party and generated assets**
- **Every imported asset is recorded in the game's `ASSETS.md`** (source URL, license, date). Only CC0 and OFL-class licenses are shipped; each license is verified on the original page, not an aggregator.
- **No AI-image-generator output ships** unless the vendor's current terms confirm that the plan used gives the user ownership and private generation. Leonardo.ai's free plan failed this test (public by default, ownership unclear) — D-114.
- **SF Symbols are never used in the app icon or any logo** (Apple's terms). In-app buttons only.
- **No readable text baked into raster art.** Anything readable is drawn in code so it scales and localizes.

---

## 7. Design Handoff (Claude Design)

- When work on a game **begins**, copy `docs/design/_template/` to `docs/design/<NN-game>/` and fill `00-brief.md` and the D1–D6 cards for that game (`docs/design/README.md`).
- **One Claude Design session = one card.** After a card, only its **text tokens** (hex, fonts, keywords) go into the next card — never the previous deliverable.
- **Web Claude Design is where J explores and chooses the look; this session's Claude is where it becomes specs and code.** Claude Code writes the briefs, the layout specs, and the import step. It does not generate artwork.
- Deliveries land in `docs/design/<NN-game>/assets/` (gitignored); accepted app assets are copied to `Apps/<Game>/Resources/` and the matching item in the game's `checklist.md` is ticked.
- Anything fancy that is not a picture — glass refraction, glow, chromatic aberration, shatter, particles — is built in code (SwiftUI `colorEffect` / `layerEffect` / `distortionEffect`, `CoreKitJuice`), and the delivered D5 numbers are its spec.

### Starting a new game
Read `docs/architecture/next-game-handoff.md` first — the mine map of every trap Chordline hit.
`docs/architecture/new-game-setup.md` is the mechanical procedure.

### The screen-building gate (non-negotiable)

**No screen is implemented from a guess.**

- **Logic work** — board/state model, generator/solver, gesture mechanics, save/purchase/juice wiring — has no visual layout of its own and starts as soon as the phase does, in parallel with Track B.
- **Screen work** — Home, Stage Select, Settings, Result, paywall, and the game's own gameplay chrome — **does not start until the gameplay and supporting-screen designs (D3, D4) are delivered AND the layout specs written from them are approved** (gate G2). Chordline built five screens from logic alone, then rebuilt every one of them once the mockups arrived (D-104). That first pass was pure loss.

If a step needs a screen and G2 is not open, the step waits or J runs the missing card next. A debug `Text` or plain list that only shows state is not a screen and is exempt; the moment it is dressed up to look like the real thing, the gate applies.

---

## 8. Model Usage Strategy — Opus ↔ Sonnet alternation

Every step in a game's `PLAN.md` carries a tag. **Claude announces every tag change before starting the next step** — never switches silently, never waits to be asked. J makes the call.

| Tag | Model · effort | Triggers |
|---|---|---|
| `[OPUS]` | Opus 5.5 · high | A **new** `CoreKit` capability designed from scratch (a new persistence shape, a new cross-cutting service, a generalized API that every game inherits) · an algorithm whose correctness must be proven (stage generator, solvability guarantee) · a phase-end audit · a defect whose root cause is a `CoreKit`-level decision · J asks |
| `[SONNET]` | Sonnet 5.5 · medium | Everything else — implementing settled rules, building screens against an approved layout spec, wiring existing `CoreKit` services, localization, docs |

Extending an existing pattern (a new `GameTheme`, a new juice recipe) is `[SONNET]`. "The UI needs polish" is not a reason to escalate — a missing design brief is a reason to stop and wait (§7). Chordline's UI rework was a sequencing bug, not a model-capability problem.

**Announcement format**
```
🔁 Model switch proposed — <step> [OPUS] done → next <step> is [SONNET]
   Why: <one line>
   Switch to Sonnet 5.5 · medium in the app's model picker, then start a new session with "<step> 시작".
```

**The formal switch point.** A game's core loop first runs end-to-end on the host — win/lose reachable, at least one juice moment feelable in `Tools/JuiceLab`. After that point, only audits and `CoreKit`-rooted defects return to `[OPUS]`.

---

## 9. Private Material (public-repo leak prevention)

This repository is public. **An unreleased game's codename, concept, rules, and art direction never appear in a tracked file or a commit message.** They live only in:

- `PLAN.md`
- `docs/concepts/` (concept, rules, palette ledger)
- `docs/design/[0-9]*/` (brief, D-cards, layout specs, `ASSETS.md`, raw deliveries)
- the game's own repository under `Apps/<Game>/`

Tracked files refer to the in-progress game as "game #2". `CoreKit` changes made for it are described by what they do, not by the game they were made for.

---

## 10. Nicknames

| Nickname | Refers to |
|---|---|
| **J** | the user (jacobko) |
| **C** | Claude |
