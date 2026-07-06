---
name: expo-harness-plan
description: "Phase A plan — assign app identity (app_name/app_slug/bundle_id/orientation) into config.md, then write the PRD in default_language with a kind-branched structure (game: core loop/mechanics/content metrics/progression/win-lose; app: purpose/journeys/features/data model/navigation), plus a project structure map, and advance the pipeline to design."
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---

# expo-harness-plan

Phase A, step 2 of the expo-harness pipeline. Reads the research spec and `config.md`, decides the
app identity, writes a comprehensive PRD in the project's `default_language` (branching structure
on `kind`), maps the project directory structure, and advances the pipeline state to `design`.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) are defined in
`docs/harness-protocol.md` — refer to that document as the single source of truth. Do not redefine
schemas here.

---

## Input

### 1. Read `docs/harness/config.md`

Extract:

| Key | Use |
|---|---|
| `app_idea` | Refined concept tagline written by the research phase |
| `app_name` | Display name (blank — this skill sets it) |
| `app_slug` | Kebab-case identifier (blank — this skill sets it) |
| `bundle_id` | App bundle ID (blank — this skill sets it) |
| `kind` | `game` or `app` — drives which PRD structure and structure map is written |
| `engine` | `skia` — the only supported Phase A value, meaningful only when `kind: game`; cited in the PRD's mechanics/structure sections |
| `default_language` | The user's conversation language; the PRD and all copy are written in it |
| `orientation` | Currently `portrait` (bootstrap default) — this skill may revise it |

If `config.md` does not exist, abort with:
`expo-harness-plan: docs/harness/config.md not found — run the orchestrator to bootstrap first.`

### 2. Read the latest research spec

Find the most recent file matching `docs/harness/specs/*-research.md` (sort by filename descending,
take the first). If no spec file exists, abort with:
`expo-harness-plan: no research spec found in docs/harness/specs/ — run expo-harness-research first.`

Extract from the spec:

- **Chosen Concept** — title, tagline, core mechanic / primary journey, differentiator
- **Monetization hook** — one-line note only; the mechanism and any SDK/config are deferred to
  Phase B (never design monetization implementation here)
- **Clone-Avoidance Check** — must read `SAFE` or `CLONE (resolved)`. If it reads anything else
  (missing, unresolved `CLONE`, or malformed), do not proceed — see Error handling.

---

## Identity assignment

Decide the app identity **before** writing the PRD so the PRD can reference the final values. These
are computed here; the actual write to `config.md` happens in Output step 2.

### app_name

Use the working title from the research spec as the display name. Capitalize each word. Example:
`"space hop"` → `"Space Hop"`.

### app_slug

A **kebab-case** identifier derived from `app_name`:

1. Lowercase the display name.
2. Replace spaces and special characters with hyphens.
3. Strip leading/trailing hyphens and collapse consecutive hyphens to one.
4. Example: `"Space Hop!"` → `"space-hop"`.

Used as the last segment of the bundle ID and as a directory/CI path segment. Kebab-case only — no
underscores.

### bundle_id

Reverse-DNS format **`com.<company>.<id>`**:

- `<id>` = `app_slug` with **all hyphens/underscores removed, lowercase** (must be `[a-z0-9]+` —
  hyphens/underscores/uppercase break iOS/Android signing). Example: `app_slug: space-hop` → `<id>:
  spacehop` (NOT `space-hop`).
- `<company>` — Phase A collects no developer/store identity (`credentials_dir` is a placeholder
  only, per `docs/harness-protocol.md` §1; the orchestrator never hard-codes a company name at
  bootstrap). This skill therefore uses the generic placeholder segment **`example`** (the same
  convention as default Android/iOS project templates) — never a real or invented company name. A
  future Phase B step swaps this segment for the developer's real reverse-DNS domain once store
  credentials are collected.

So `bundle_id` = `com.example.<id>`. State the chosen `bundle_id` explicitly in the PRD identity
block, and note there that the `example` segment is a placeholder pending Phase B. It must be
byte-identical on iOS and Android (`docs/harness-protocol.md` §1) — the generator writes this same
string to both `app.json` `ios.bundleIdentifier` and `android.package`.

### orientation

Decide the **single** locked orientation from the concept and record it in the PRD: `portrait`
(default — most one-hand games and general-purpose apps) or `landscape` (inherently wide content:
side-scroll platformers, twin-stick shooters, landscape racers; or, for `kind: app`, media/video-
first or landscape-only tools). The generated project ships locked to this one orientation (the
generator removes the other natively — no rotate-on-launch).

---

## PRD content

Write the PRD **entirely in `default_language`** (the language the user is conversing in). The
templates below show English headings — translate every heading and body to `default_language`
when `default_language` is not English. The only exceptions:

- Code identifiers, file paths, class/type names, and technical terms with no local equivalent.
- A heading may include the English technical term in parentheses after the localized heading.

Use the structure for the active `kind` below verbatim (section order and headings). A fresh Claude
must be able to fill every section from the research spec and the Identity assignment above alone —
no guessing required. If any required section cannot be filled from the spec, write a clearly
marked placeholder (`<!-- TODO: needs input -->`) rather than omitting the section — downstream
skills grep for section headings.

Both templates share this header block:

```markdown
# PRD — <app_name>

> **Version:** 1.0
> **Date:** <YYYY-MM-DD>
> **Author:** expo-harness-plan
> **Kind:** game | app
> **Bundle ID:** com.example.<id> (`example` is a Phase A placeholder — see Identity assignment)
> **Orientation:** portrait | landscape
```

### `kind: game` template

```markdown
## 1. Genre & Concept

- **Genre:** <e.g. hyper-casual runner / tower defense / puzzle>
- **One-line pitch:** <tagline from research spec>
- **Core differentiator:** <differentiator from research spec>
- **Target age group:** <target age band>

---

## 2. Core Loop

The core action the player repeats every 10–30 seconds, step by step.

1. <step 1>
2. <step 2>
3. <step 3>

---

## 3. Mechanics

### 3.1 Controls

| Platform | Input | Result |
|---|---|---|
| iOS/Android | <tap / swipe / hold / drag> | <action> |

### 3.2 Core Mechanic

<2-4 sentences describing the primary mechanic>

### 3.3 Secondary Mechanics

<Bullet list of 2-4 secondary mechanics>

---

## 4. Content Metrics

| Item | Target |
|---|---|
| Number of levels | <number> |
| Enemy/obstacle types | <number> |
| Waves per level | <number> |
| Stage themes | <number> |
| Item/power-up types | <number> |

Content metrics are MVP targets; later updates may expand them.

---

## 5. Progression & Economy

### 5.1 Progression structure

<Linear, world-map, infinite, etc. — how levels/stages unlock>

### 5.2 Score & rewards

- Base score unit: <e.g. coins, stars, points>
- Level-clear reward: <description>
- Reward-ad bonus: <description — mechanism/SDK deferred to Phase B>

### 5.3 Save & persistence

- Local save: `expo-secure-store` + `AsyncStorage` mirror via a `saveRepository.ts` (see
  `docs/app-gotchas.md` R9) — score, best record, settings.
- Cloud save: not included (out of scope — see Scope Guard).

---

## 6. Win / Lose Conditions

### 6.1 Win condition

<What the player must achieve to win a level/session>

### 6.2 Lose condition

<What causes a game-over state>

### 6.3 Game-over screen

The game-over screen shows:
- Final score
- Best record (with a new-record indicator)
- Restart button
- Main-menu button
- Optional revive-via-reward-ad option (mechanism deferred to Phase B)

---

## 7. App Store / Google Play Compliance

| Item | Status |
|---|---|
| App Store 4.3 clone-avoidance | SAFE (per research spec) |
| Google Play impersonation/minimum-functionality | SAFE (per research spec) |
| Privacy policy URL | Deferred to Phase B (store credentials not collected in Phase A) |
| Age rating suitability | <target age band> |
| Ad labeling (if monetization hook is later implemented) | Deferred to Phase B — Phase A ships no ad SDK |
| In-app purchases | Out of scope (MVP) |
| Location data | Not used |
| Camera/microphone | Not used |

---

## 8. Scope Guard

The following are **out of MVP scope**. Do not implement them during plan, design, or generator
phases. If scope must expand, revise this PRD first.

**Out of scope:**

- Online multiplayer / social features
- Cloud save / account systems (Game Center, Google Play Games Services)
- In-app purchases (IAP) and premium content
- Push notifications
- Custom character/skin systems
- Map editor or user-generated content
- Locales beyond `default_language`
- Tablet-specific layout
- Backend server / API

---

## 9. Project Structure

The design and generator phases follow this structure exactly.

\`\`\`
app/                         # Expo Router routes — entry screens only (menu, game, settings, gameOver)
game/                        # game logic — never imported by app/ routes except to mount the canvas
├── scene/                   # Skia <Canvas> + useFrameCallback loop, camera/world setup
├── entities/                # player/enemy/obstacle/pickup entity classes
└── systems/                 # spawn/collision/score/difficulty systems
config/
└── gameConfig.ts            # all tuning constants — no magic numbers in game/ or app/
data/                        # level data, enemy stats, content catalogs (data, not hardcoded)
i18n/                        # expo-localization + i18next resources, one file per locale
ui/                          # HUD widgets, overlays (menu/pause/gameOver/settings), shared components
\`\`\`

> **Rule:** game logic lives only under `game/`. Screens/overlays live under `app/` (routes) or
> `ui/` (shared widgets). Magic numbers are centralized in `config/gameConfig.ts` (Hard Gate 4,
> `docs/harness-protocol.md` §3).
```

### `kind: app` template

```markdown
## 1. Purpose & Users

- **Purpose:** <what problem this app solves, one paragraph>
- **Target users:** <primary user segment>
- **Primary value proposition:** <tagline from research spec>
- **Core differentiator:** <differentiator from research spec>

---

## 2. Primary Journeys

Screen-by-screen walk-through of the main user flow(s), from the research spec's primary journey.

### Journey: <name, e.g. Onboarding → Core Task → Outcome>

1. **<Screen name>** — <what the user sees/does>
2. **<Screen name>** — <what the user sees/does>
3. **<Screen name>** — <what the user sees/does>

<Repeat for each additional journey the concept requires.>

---

## 3. Feature List

| Feature | Description | Priority |
|---|---|---|
| <feature> | <one-line description> | MVP / Post-MVP |

Post-MVP features must also appear in Scope Guard (§8) — do not implement them.

---

## 4. Data Model

| Entity | Fields | Notes |
|---|---|---|
| <entity> | <field: type, field: type, ...> | <relationships/constraints> |

Entities are implemented as typed models under `data/` (§9) — no untyped `any` payloads.

---

## 5. States

Loading/empty/error handling per screen — every screen in §2 must define all three.

| Screen | Loading state | Empty state | Error state |
|---|---|---|---|
| <screen> | <e.g. skeleton/spinner> | <e.g. "no items yet" + CTA> | <e.g. retry banner> |

---

## 6. Navigation Map

| Route | Screen | Navigates to |
|---|---|---|
| <route path> | <screen name> | <route(s) reachable from here> |

---

## 7. App Store / Google Play Compliance

| Item | Status |
|---|---|
| App Store 4.3 clone-avoidance | SAFE (per research spec) |
| Google Play impersonation/minimum-functionality | SAFE (per research spec) |
| Privacy policy URL | Deferred to Phase B (store credentials not collected in Phase A) |
| Age rating suitability | <target age band> |
| In-app purchases / subscriptions | Out of scope (MVP) |
| Location data | <used / not used — state which> |
| Camera/microphone | <used / not used — state which> |

---

## 8. Scope Guard

The following are **out of MVP scope**. Do not implement them during plan, design, or generator
phases. If scope must expand, revise this PRD first.

**Out of scope:**

- Online multiplayer / real-time collaboration
- Account system / social login (unless a §3 Feature List item explicitly requires it)
- In-app purchases / subscriptions
- Push notifications (unless a §3 Feature List item explicitly requires them)
- White-label/theming system
- Admin/CMS panel
- Locales beyond `default_language`
- Tablet-specific/responsive-web layout
- Any backend beyond the minimal API the §3 Feature List requires

---

## 9. Project Structure

The design and generator phases follow this structure exactly.

\`\`\`
app/                         # Expo Router routes — file-based navigation, one route per screen (§6)
components/                  # shared UI components (buttons, cards, lists, form fields)
config/
└── appConfig.ts             # all tuning constants — no magic numbers in app/ or components/
data/                        # typed data models (§4)
services/                    # API/data-fetching layer (mock or real, per §4/§3)
state/                       # app state layer (Context/Zustand)
i18n/                        # expo-localization + i18next resources, one file per locale
\`\`\`

> **Rule:** feature logic lives under `services/`/`state/`, never inline in `app/` routes. Magic
> numbers are centralized in `config/appConfig.ts` (Hard Gate 4, `docs/harness-protocol.md` §3).
```

---

## Output

### 1. Write the PRD

Create `docs/harness/plans/<YYYY-MM-DD>-prd.md` (today's UTC date, via `date -u +%Y-%m-%d`). Create
`docs/harness/plans/` first if it does not yet exist. Write the full PRD in `default_language`
using the template for the active `kind` from **PRD content** above, filling every section from the
research spec and the Identity assignment decisions.

### 2. Update `config.md`

Apply the identity keys via `Edit` (targeted — do not rewrite the whole file):

```yaml
app_name: "<display name>"
app_slug: "<kebab-case-slug>"
bundle_id: "com.example.<id>"    # <id> = app_slug with hyphens/underscores removed
orientation: portrait            # or "landscape"
```

### 3. Update `state.md`

Update `docs/harness/state.md` per the schema in `docs/harness-protocol.md` §2:

```yaml
status: running
current_phase: plan
next_role: design
updated_at: "<ISO-8601 UTC now>"
```

Leave all other keys unchanged. Use `Edit` for a targeted update. This follows the `plan → complete
→ design` row of the transition table in `docs/harness-protocol.md` §7.

### 4. Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | plan | complete | design |
```

---

## Error handling

- If the research spec's Clone-Avoidance Check is missing or reads anything other than `SAFE` or
  `CLONE (resolved)`, do not write the PRD. Set `state.md` to `status: paused`, `pause_reason:
  manual_action`, and append a `pipeline-log.md` note explaining that the concept was never cleared
  by clone avoidance.
- If `config.md` cannot be read, abort immediately (do not write partial output).
- If any required PRD section cannot be filled from the spec, write a clearly marked placeholder
  (`<!-- TODO: needs input -->`) rather than omitting the section — downstream validators grep for
  section headings.
- If `docs/harness/plans/` does not exist, create it before writing the PRD.
