---
name: expo-harness-design
description: "Phase A design — define the ui/designTokens.ts spec (colors, spacing, radius, typography), the visual/component concept (game: code-drawn Skia shapes / app: RN primitives), and the asset plan (icon+splash branding, contrast-safe accessibility). Advances pipeline state to contract."
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---

# expo-harness-design

Phase A, step 3 of the expo-harness pipeline. Reads the latest PRD and `config.md`, then produces
a design document that specifies the `ui/designTokens.ts` constants, the visual/component concept,
and the asset plan (including app icon and splash intent). Advances the pipeline state to
`contract`.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) and the phase transition table are
defined in `docs/harness-protocol.md` — refer to that document as the single source of truth (§2
for `state.md` schema; §7 for the `design → contract` transition). Do not redefine schemas here.

---

## Input

### 1. Read `docs/harness/config.md`

Extract:

| Key | Use |
|---|---|
| `kind` | `app` or `game` — drives which visual/component template and project-structure slot this skill fills |
| `engine` | `skia` or `rnge` — meaningful only when `kind: game`. Either way the design spec below is renderer-agnostic (shapes/primitives + tokens); `engine` only changes which library the generator uses to draw them |
| `app_name` | Used in the splash screen and app-icon badge intent |
| `app_slug` | Used for asset directory naming conventions |
| `default_language` | The user's conversation language; write the design doc's prose and copy samples in it |

If `config.md` does not exist, abort with:
`expo-harness-design: docs/harness/config.md not found — run the orchestrator to bootstrap first.`

### 2. Read the latest PRD

Find the most recent file matching `docs/harness/plans/*-prd.md` (sort descending by filename,
take the first). If no PRD exists, abort with:
`expo-harness-design: no PRD found in docs/harness/plans/ — run expo-harness-plan first.`

Extract from the PRD, branching on `kind`:

**`kind: game`** — §1 Genre & Concept (genre, tone, target age), §2 Core Loop, §6 Win/Lose
Conditions (what UI states need distinct visual treatment), §9 Project Structure.

**`kind: app`** — §1 Purpose & Users (tone, target users), §2 Primary Journeys (screens to design),
§5 States (loading/empty/error per screen), §6 Navigation Map, §9 Project Structure.

---

## Design tokens

Write a specification for `ui/designTokens.ts` that a generator-phase Claude can implement
verbatim as TypeScript `const` objects exported `as const`. Every UI color, spacing, and radius
value used anywhere in `app/`, `components/`, `game/`, or `ui/` must come from this file — no raw
hex strings or bare numeric literals in UI code. The spec must cover every sub-section below.

> For `kind: app`, `ui/designTokens.ts` is the one addition to the PRD §9 structure (which has no
> `ui/` directory) — a single shared tokens module imported by `components/`, not a broader `ui/`
> package. For `kind: game`, it lives alongside the `ui/` directory the PRD structure already
> defines (HUD widgets, overlays).

### Colour palette

Derive a palette from the PRD's genre/tone (game) or purpose/audience (app). Use the following
template — replace every `<...>` with a real hex colour and a one-line rationale:

```
primary       <#RRGGBB>  — main brand / call-to-action colour
primaryDark   <#RRGGBB>  — pressed / active-shadow state of primary
accent        <#RRGGBB>  — highlights, active state, score/emphasis text
background    <#RRGGBB>  — screen or canvas background
surface       <#RRGGBB>  — card, dialog, overlay background
onBackground  <#RRGGBB>  — text/icon colour on background
onSurface     <#RRGGBB>  — text/icon colour on surface
error         <#RRGGBB>  — error/validation states, damage-loss flash (game)
```

Rules:
- **Text contrast ≥ 4.5:1** for any text colour against the background/surface it sits on (per
  `docs/app-gotchas.md`'s Accessibility & safety section — "Text contrast ≥4.5:1 against its
  background"). Compute and state the ratio for `onBackground`-on-`background` and
  `onSurface`-on-`surface` explicitly in the design doc; do not eyeball it.
- `background` and `primary` share the same temperature (both warm or both cool).
- `accent` differs from `primary` by at least 60° of hue for visual pop.
- Dark-themed concepts (sci-fi, focused productivity tools) keep `background` ≤ `#333333`; bright,
  friendly concepts keep `background` ≥ `#E0E0E0`.

### Typography scale

Specify font family, weight, and size (RN `fontSize`/`lineHeight` are plain numbers, not `sp` — RN
respects the OS accessibility text-size setting automatically as long as `allowFontScaling` is left
at its default `true`; do not disable it). Name a font from `expo-font`/Google Fonts, or default to
the OS system font.

```
display   family: <FontName or System>  weight: '800'  size: 40  lineHeight: 48  — hero/title text
heading1  family: <FontName or System>  weight: '700'  size: 28  lineHeight: 34  — screen headings
heading2  family: <FontName or System>  weight: '700'  size: 22  lineHeight: 28  — section headings
body      family: <FontName or System>  weight: '400'  size: 16  lineHeight: 22  — general UI text
caption   family: <FontName or System>  weight: '400'  size: 12  lineHeight: 16  — labels, hints
button    family: <FontName or System>  weight: '600'  size: 17  lineHeight: 22  — button labels
hud       family: <FontName or System>  weight: '700'  size: 20  lineHeight: 24  — game HUD counters (kind: game only)
```

### Spacing scale

Define a base unit and derive the full spacing scale. Typical base is 4:

```
xs:   4   — tight padding (icon labels)
sm:   8   — inner card padding
md:  16   — standard screen margin
lg:  24   — section gap
xl:  32   — screen top/bottom padding
xxl: 48   — hero area padding
```

All layout constants in `designTokens.ts` use these named values — no raw numbers in UI code.

Also define `minTapTarget = 44` — every interactive control (button, icon button, list row action)
must be at least this size, per `docs/app-gotchas.md`'s Accessibility & safety section ("Tap
targets ≥44pt").

### Radius scale

```
sm:    4   — chip, small badge
md:    8   — card, dialog
lg:   16   — bottom sheet, hero card
full: 999  — pill buttons
```

### `ui/designTokens.ts` file template

The generator must emit a file with this exact structure:

```ts
// ui/designTokens.ts
// AUTO-GENERATED by expo-harness-design — do not edit manually.
// See docs/harness/plans/<date>-design.md for rationale.

export const Colors = {
  primary: '#______',
  primaryDark: '#______',
  accent: '#______',
  background: '#______',
  surface: '#______',
  onBackground: '#______',
  onSurface: '#______',
  error: '#______',
} as const;

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
  minTapTarget: 44,
} as const;

export const Radius = {
  sm: 4,
  md: 8,
  lg: 16,
  full: 999,
} as const;

export const Typography = {
  display: { fontFamily: '______', fontWeight: '800', fontSize: 40, lineHeight: 48 },
  heading1: { fontFamily: '______', fontWeight: '700', fontSize: 28, lineHeight: 34 },
  heading2: { fontFamily: '______', fontWeight: '700', fontSize: 22, lineHeight: 28 },
  body: { fontFamily: '______', fontWeight: '400', fontSize: 16, lineHeight: 22 },
  caption: { fontFamily: '______', fontWeight: '400', fontSize: 12, lineHeight: 16 },
  button: { fontFamily: '______', fontWeight: '600', fontSize: 17, lineHeight: 22 },
  hud: { fontFamily: '______', fontWeight: '700', fontSize: 20, lineHeight: 24 },
} as const;
```

Fill every `______` from the palette and typography spec written above.

---

## Visual/component spec

### Art direction

Describe the overall visual style in 3–5 sentences covering:

1. **Style** — flat vector / geometric shapes / minimal iconography (the code-drawn default) — or
   the sourced-art style if sprites/images are used instead
2. **Colour mood** — how the palette reinforces the concept's emotional tone
3. **Layout language** — card-based, full-bleed canvas, list-first, etc.
4. **Motion feel** (`kind: game`) or **interaction feel** (`kind: app`) — snappy/arcade vs.
   calm/deliberate
5. **Chrome style** — whether overlays/screens feel like HUD panels, plain native screens, cards,
   bottom sheets, etc.

The description must be concrete enough that a generator-phase Claude can implement it in code with
no further guessing.

### `kind: game` — entity/shape inventory (MVP)

Every game entity is drawn as a code primitive by default — no sprite sheets required. List every
entity needed for the MVP core loop:

| Entity | Primitive | Dimensions (dp) | Token colours used | Notes |
|---|---|---|---|---|
| Player | <circle/rect/roundedRect/path> | <W×H> | `Colors.primary` fill, `Colors.primaryDark` stroke | <idle/animated state> |
| Enemy A | <primitive> | <W×H> | `Colors.error` fill | <behaviour hint> |
| Background | rect (solid or gradient) | screen width × height | `Colors.background`→`Colors.surface` | static, drawn once |
| ... | ... | ... | ... | ... |

Dimensions are logical dp; the renderer (Skia `Canvas`/`useFrameCallback`, or the RN Game Engine
loop when `engine: rnge`) scales to device pixel ratio automatically — the shape spec above does
not change with `engine`.

### `kind: game` — overlay/HUD layout

Describe the layout of each screen/overlay (each maps to an Expo Router route under `app/`, or a
shared widget under `ui/`):

- **Main menu** — visible elements and rough positions
- **In-game HUD** — score, lives/health, pause button placement
- **Pause overlay** — resume, restart, settings
- **Game-over screen** — final score, best score, restart, main-menu button
- **Settings screen** — SFX toggle, language toggle

### `kind: app` — screen/component inventory (MVP)

Pull the screen list from the PRD's §2 Primary Journeys, and the loading/empty/error requirements
from §5 States:

| Screen | Route (from PRD §6) | Key components (RN primitives / `components/`) | Loading state | Empty state | Error state |
|---|---|---|---|---|---|
| <screen name> | <route path> | `View`/`Text`/`Pressable`/`FlatList`/... | <e.g. skeleton> | <e.g. "no items yet" + CTA> | <e.g. retry banner> |
| ... | ... | ... | ... | ... | ... |

Every RN primitive is styled exclusively via `Colors`/`Spacing`/`Radius`/`Typography` from
`ui/designTokens.ts` — no inline hex/number literals in `components/` or `app/`.

---

## Asset plan

> **Default the generator can always satisfy with no sourcing:** visuals are **code-drawn** — Skia
> shapes (`kind: game`, from the entity/shape inventory above) or RN primitives styled by tokens
> (`kind: app`). Specify sprite/image assets below only if the art direction needs them; the harness
> never depends on art that isn't sourced, so a project can ship fully code-drawn.

### Sprite and image assets (optional)

State for each visual asset, if any are needed beyond code-drawn primitives, whether it will be:

| Strategy | When to use |
|---|---|
| **Free pack** (itch.io / OpenGameArt / Kenney.nl) | Generic shapes, hyper-casual games |
| **AI-generated** (prompt-based) | Custom style with a specific prompt given below |
| **Custom drawn** | Unique brand-critical characters/logos |

For every free pack named, give the pack URL and its license (CC0, CC-BY, etc.). For AI-generated
assets, write the exact prompt template (substituting `<style>`/`<subject>` from the art direction
above). Store sourced assets under `assets/images/` (lowercase file names — Android is
case-sensitive) and reference them only from code paths that exist; a dangling asset reference is a
runtime error.

### App icon and splash screen

The icon and splash **must be custom** — never the default Expo template art (a default icon/splash
reads as an unfinished app to reviewers; see `docs/app-gotchas.md`'s Store rejections section).

Specify the intent so the generator can configure `app.json`:

```json
{
  "expo": {
    "icon": "./assets/images/icon.png",
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/images/adaptive-icon.png",
        "backgroundColor": "<Colors.primary hex>"
      }
    },
    "plugins": [
      [
        "expo-splash-screen",
        {
          "image": "./assets/images/splash-icon.png",
          "imageWidth": 200,
          "resizeMode": "contain",
          "backgroundColor": "<Colors.background hex>"
        }
      ]
    ]
  }
}
```

The icon must:
- Be 1024×1024 pixels, PNG, **opaque — no alpha channel** (a transparent iOS icon is rejected).
- Follow the art direction (logo, main character, or monogram on the `Colors.primary` background).
- Android adaptive icon: foreground layer uses the logo/character; background uses `Colors.primary`.

The splash image must:
- Be a centred logo/character mark on a transparent or `Colors.background`-matching field, sized to
  read clearly at ~200dp wide.
- Feel consistent with the main menu's (game) or first screen's (app) visual style.

---

## Output

### 1. Write the design document

Create `docs/harness/plans/<YYYY-MM-DD>-design.md` (use today's UTC date, via
`date -u +%Y-%m-%d`). Create `docs/harness/plans/` first if it does not yet exist. Write the full
document in `default_language` (translate headings and prose; keep code identifiers, file paths,
and hex values as-is).

The document must include all of the following top-level sections (downstream skills grep for
these headings):

- `## Design tokens` — palette table (with computed contrast ratios), typography scale, spacing
  scale, radius scale, and the filled `ui/designTokens.ts` template
- `## Visual/component spec` — art direction, the `kind`-appropriate inventory table
  (entity/shape for `game`, screen/component for `app`), and the overlay/HUD or screen layout
- `## Asset plan` — sprite/image sourcing table (or an explicit "fully code-drawn" note), the app
  icon spec, and the splash screen spec

Fill every section from the PRD and `config.md`; do not leave placeholder text.

### 2. Update `state.md`

Update `docs/harness/state.md` per `docs/harness-protocol.md` §2 and the transition rule in §7
(`design` → `contract`). Per §7 rule 2, a skill that completes successfully and advances the
pipeline sets `status: running` together with `current_phase` and `next_role` in the same atomic
write:

```yaml
status: running
current_phase: design
next_role: contract
updated_at: "<ISO-8601 UTC now>"
```

Leave all other keys unchanged. Use `Edit` for a targeted update.

### 3. Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | design | complete | contract |
```

---

## Error handling

- If the PRD is missing or empty, abort with a clear message and set `state.md` to
  `status: paused`, `pause_reason: manual_action`.
- If `config.md` cannot be read, abort immediately (do not write partial output).
- If the tone/mood cannot be determined from the PRD, choose a neutral palette (dark background
  `#1A1A2E`, bright accent `#E94560`, verified ≥4.5:1 contrast) and note the assumption in the
  design document under a `## Assumptions` heading.
