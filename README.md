# Frame Police

**A design-system linter for creative exports.** A rule engine checks
designs and frames against a design system — spacing, type, colour,
radius, component usage, and (for video exports) subtitle safe area,
aspect ratio, audio peak/silence, black frames, and brand checks —
reports violations with severity, and runs in CI with exit codes.
**The exit code is the verdict.**

> **v0.1 — started, not finished.** The rule engine is real and tested
> end-to-end (see [Verification](#verification)): 14 versioned rules,
> deterministic inspections, one-tap auto-fix with before/after
> previews, waivers with reasons, four report formats, and the full CI
> exit-code contract. All 30 screens exist as functional routes (mobile
> + web layouts from one codebase). The native media probe (decoding
> real video frames and audio), the GitHub Action, and backend sync are
> phase-2 items, listed in [Roadmap](#roadmap).

## What it does

1. **Inspect** — pick an export. Fourteen checks run on-device: 11
   defect checks that decide the exit code, 3 suggestions that never do.
   Nothing uploads.
2. **Verdict** — the report: exit code, score, marker tracks, and every
   finding with its evidence (timecode, measured value, limit). Score is
   illustrative; the exit code is the verdict.
3. **Fix** — one-tap auto-fix for every defect, previewed before/after
   inline. A fix is not real until re-inspection confirms it: the exit
   code stays 1 until then.
4. **Waive** — override a defect with a reason (minimum 20 characters).
   The reason stays in the report. Waiving never deletes the finding.
5. **Ship** — re-inspect. Exit 0, score 100, the waiver still on
   record, the PR unblocked. Export the report as HTML, JSON, Markdown,
   or TTY.

## The rules

Registry **v2.4.1** — 14 versioned rules. A report records the registry
version that ran it; same input + same rules = same report. Editing a
rule's limit creates a new rule version — history is never rewritten.

| Code | Rule | Kind | Limit |
|---|---|---|---|
| SUB-SAFE-01 | Subtitle safe area | Defect | 90% margin |
| AUD-PEAK-02 | Audio peak / silence | Defect | −1.0 dBFS · 1.5 s |
| ASP-RATIO-01 | Aspect ratio | Defect | Project aspect |
| BLACK-FR-01 | Black frames | Defect | 0 black frames |
| TXT-OVER-01 | Text overflow | Defect | No overflow |
| BRAND-LOGO-01 | Brand mark present | Defect | Mark present |
| BRAND-COL-01 | Brand colour usage | Defect | Palette only |
| CAP-SYNC-01 | Caption sync | Defect | ±120 ms |
| TITLE-SAFE-01 | Title safe area | Defect | 85% margin |
| FRAMERATE-01 | Frame rate | Defect | 24 fps |
| RES-MIN-01 | Minimum resolution | Defect | ≥ 1080 px short edge |
| SUG-LOUD-01 | Loudness target | Suggestion | −14.0 LUFS |
| SUG-OPEN-01 | Opening frame brightness | Suggestion | < 50% dark |
| SUG-CAP-01 | Captions file attached | Suggestion | .srt attached |

Defects and suggestions are **separate universes**: suggestions never
affect the exit code, the score, or anything CI reads. The moment an
opinion blocks CI, the product has lied.

## CI exit-code contract

CI reads **only** the exit code. This contract is enforced by the
inspector (`lib/engine/exit_codes.dart`), shown on the CI setup screen,
and tested (`test/exit_codes_test.dart`, `test/inspector_test.dart`).

| Exit code | Meaning | CI behaviour |
|---|---|---|
| `0` | Clean — no open defects | Check passes. The PR may merge. |
| `1` | Defects — one or more open defects | Check fails. The PR is blocked until the check passes. |
| `2` | Inspection error (unreadable file, probe failure, registry mismatch) | Check fails (error, not a defect). Re-run the inspection. |

Rules of the contract:

- **Open** defects yield 1. **Fixed-but-unconfirmed** defects also
  yield 1 — a fix is not real until re-inspection confirms it.
- **Waived** defects yield 0 (the waiver + reason stay in the report).
- **Confirmed** fixes yield 0.
- **Suggestions** never affect the exit code — by design, not by setting.
- Exit 2 is distinct from exit 1: an error is not a defect, and CI
  should say so.

### GitHub Action (proposed integration)

The workflow is eleven lines — see the CI setup screen in the app, or
the [appendix](#appendix-github-action-workflow) for the YAML to add
via the GitHub web UI. The Action (`frame-police/action@v2`) is a
proposed integration in this Build Specification; the app ships the
contract, the workflow text, and the seeded demo CI runs, not the
Action itself.

## Screens

30 routes, each responsive: below 720 px the mobile layout (single
column, bottom tab bar), at or above 720 px the web layout (side
navigation, two-column content). That covers all 60 screens of the V7
inventory (30 mobile + 30 web) from one codebase.

| # | Route | Screen |
|---|---|---|
| 01 | `/home` | Home — latest report, quality chart, totals |
| 02 | `/inspect` | Pick an export |
| 03 | `/pre-inspection` | File facts, pinned registry, checks queued |
| 04 | `/inspecting` | Live run — progress, probes, cancel |
| 05 | `/report` | Verdict — exit code, marker tracks, defects |
| 06–07 | `/defect` | Defect detail — before/after, evidence, fix / waive |
| 08 | `/autofix` | Fixed in one tap — fix list, re-inspect |
| 09 | `/suggestions` | Suggestions, never blocking |
| 10 | `/waiver` | Waiver sheet — reason required, stays on record |
| 11 | `/report-waived` | Report, waived — exit 1 until re-inspection |
| 12 | `/registry` | Rule registry — search, filter, enable/disable |
| 13 | `/rule` | Rule detail — editable limit, version history |
| 14 | `/history` | Quality history — chart, averages, inspections |
| 15 | `/ci` | CI runs — totals, recent runs, contract |
| 16 | `/pr` | PR comment — the bot's check, merge block |
| 17 | `/ci-setup` | CI setup — workflow YAML, connect Action |
| 18 | `/export` | Export report — HTML / JSON / Markdown / TTY |
| 19 | `/settings` | Checks, CI, account, about |
| 20 | `/payoff` | Exit 0 — ship it |
| 21 | `/welcome` | Welcome — guest-first, no account needed |
| 22 | `/guest` | Guest mode, explained |
| 23 | `/sign-in` | Sign in — join the team registry |
| 24 | `/create-account` | Create account — move guest data in |
| 25 | `/verify` | Verify — magic link or 6-digit code |
| 26 | `/upgrade` | CI needs an account — the PR it would unblock |
| 27 | `/migrate` | Migration — nothing lost, verified item by item |
| 28 | `/account` | Account home — synced counts, registry, devices |
| 29 | `/connected` | Connected accounts — CI, registry, devices |
| 30 | `/data` | Data controls — export everything, sign out, delete |

## Honest limits

Read this before quoting any number from the demo:

- **The demo numbers are a story, not measurements.** Launch Teaser
  v3 (00:47, 1,128 frames, score 82, exit 1), PR #142, 248 CI runs, 47
  defects caught — these are seeded demo content from the V7 design,
  labelled DEMO wherever they show. They are never presented as
  measured usage, and no dates, user counts, or shipped claims are
  invented anywhere in the app.
- **v0.1 does not decode media.** The rule engine evaluates probe data
  (subtitle positions, peak levels, frame counts). Seeded demo exports
  carry measured probe values; user-picked files get a deterministic
  demo probe derived from the file's name and size — labelled DEMO in
  the report. The native media probe (frame/audio decode) is the phase-2
  milestone; the engine, scoring, waivers, and exit-code mapping it
  feeds on are complete and tested.
- **Auto-fix operates on probe data and metadata**, not media bytes:
  the working copy's probe values are adjusted to their post-fix
  values and re-inspection confirms them. Real media rewriting (moving
  a subtitle in the file, applying a limiter to the audio) is phase 2.
- **Auth is local-only in v0.1.** There is no backend: sign-in creates
  a local profile, verification accepts any 6-digit code (the screen
  says so), and "sync" is a local migration of guest data. The session
  token lives in secure storage. Real backend sync is phase 2.
- **CI runs are seeded demo data** until the Action is connected, and
  the Action itself is a proposed integration (see the appendix).
- **Themes are phase 2.** v0.1 ships the single V7 theme (near-black +
  amber). `lib/core/theme.dart` is structured for the dark/light swap:
  the palette lives in `FpPalette` and `AppTheme` builds from it —
  phase 2 adds a second palette and a mode switch, no screen changes.
- **Persistence is `shared_preferences` + JSON**, not Drift/SQLite:
  the v0.1 data model (reports, rules, waivers, settings) is small
  document data, and JSON keeps web working with zero native setup.
  Drift is the phase-2 move if the model goes relational.

## Verification

Flutter/Dart is not installed on the build VM, so the Dart test suite
is **authored, not yet run** — run `flutter test` on a machine with
Flutter to execute it. What was verified on the build VM instead:

- Every screen route exists in `lib/app.dart` (30/30) and every
  `pushNamed` target in the screens resolves to a registered route.
- Every import resolves to a file in the repo (checked by name).
- No TODO/stub/placeholder in core flows (checked by text search).
- The demo verdict was hand-verified against the engine: Launch Teaser
  v3 inspects to exactly 2 defects (SUB-SAFE-01 at 1,066 px vs the
  1,052 px limit; AUD-PEAK-02 at −0.8 dBFS vs the −1.0 dBFS limit),
  3 suggestions, score 82, exit 1 — the V7 canon.

The test suite (`test/`, run with `flutter test`):

- `exit_codes_test.dart` — exit-code mapping, labels, CI behaviour.
- `inspector_test.dart` — the demo verdict, clean/defect exports,
  suggestions-never-block, scoring, fix + re-inspection (exit 0),
  waiver carry-forward, fix-that-does-not-hold re-opens, demo-probe
  determinism, fingerprint stability, subtitle-limit geometry.
- `registry_test.dart` — 14 rules (11 + 3), unique codes, versioning
  (edits bump the version, history preserved), JSON round-trip.
- `autofix_test.dart` — every defect rule has a fix, suggestions have
  none, fixes adjust probe values, original export untouched.
- `reporter_test.dart` — all four formats carry the verdict, registry,
  and waiver reason; HTML escaping; workflow YAML pins the registry.

## Run the app

```sh
flutter pub get
flutter run            # mobile / desktop
flutter run -d chrome  # web
flutter test           # Dart test suite
flutter analyze        # lints
```

## Layout

```
lib/
  main.dart                  Entry point
  app.dart                   App shell + 30 routes
  core/
    constants.dart           Registry version, exit codes, demo fixture
    format.dart              Timecode / duration / dB / bytes formatting
    theme.dart               V7 palette (single theme, phase-2-ready)
    responsive.dart          Breakpoints, adaptive columns / grids
  engine/                    The linter (pure Dart, no Flutter dependency)
    models.dart              Exports, probes, rules, findings, waivers,
                             reports, CI runs, account, settings
    registry.dart            The 14 versioned rules (v2.4.1)
    inspector.dart           Rule engine, scoring, re-inspection, demo probe
    exit_codes.dart          The CI exit-code contract
    autofix.dart             One-tap fix definitions per defect rule
    reporter.dart            HTML / JSON / Markdown / TTY + workflow YAML
    demo_data.dart           Seeded demo exports, history, CI runs
  services/
    store.dart               Local-first persistence (shared_preferences)
    secure_session.dart      Session token (flutter_secure_storage)
    file_picker_service.dart Pick exports to inspect
    report_export.dart       Save reports + full .zip data export
  state/
    app_controller.dart      ChangeNotifier: everything screens read
  widgets/
    app_shell.dart           Adaptive scaffold (tab bar / side nav)
    fp_widgets.dart          Glass cards, tags, buttons, rows
    logo.dart                SVG logo widgets (icon, lockups, app icon)
    score_bars.dart          Quality-history chart
    waveform.dart            Waveform + marker-track painters
    frame_mock.dart          Before/after frame mock
  screens/                   30 functional routes (see Screens)
test/                        Dart test suite (flutter test)
assets/logos/                SVG logos (icon, icon-small, horizontal,
                             stacked, app-icon)
web/                         Web entry (index.html, manifest.json)
```

## Roadmap (v0.2)

1. **Native media probe** — decode real video frames and audio
   (subtitle positions, peak levels, black frames) so user-picked
   files get measured probes instead of demo probes.
2. **Real media auto-fix** — apply fixes to media bytes (move the
   subtitle, limit the audio) instead of probe data.
3. **GitHub Action** — ship `frame-police/action@v2` and wire live CI
   runs; replace seeded demo runs with real run data.
4. **Backend sync** — real accounts, team registry, shared waivers,
   and email verification (replacing local-only auth).
5. **Dual themes** — light theme alongside the V7 dark theme, via the
   `FpPalette` swap point in `theme.dart`.
6. **Drift/SQLite** — relational store if the model outgrows JSON.
7. **Design-system checks** — extend the rule engine beyond video
   exports to Figma frames: spacing, type scale, colour tokens, radius,
   and component usage against a design-system file.

## Appendix: GitHub Action workflow

Add this file via the GitHub web UI at
`.github/workflows/frame-police.yml` (the repo intentionally ships no
`.github/workflows/` directory — see the CI setup screen in the app):

```yaml
name: Frame Police
on: [pull_request]
jobs:
  inspect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: frame-police/action@v2
        with:
          registry: v2.4.1
          paths: exports/**/*.mp4
```

## Deploy note

Run #5's Pages deploy failed on GitHub's side (artifact fetch error),
and re-running the failed job failed again (duplicate artifact). This
commit re-triggers a fresh workflow run.
