---
name: expo-harness-research
description: Phase A research — kind-aware market/genre (game) or category/competitor (app) discovery, concept proposal via AskUserQuestion, a store clone-avoidance check (App Store 4.3 / Google Play impersonation), and the research spec write-up.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, WebSearch, WebFetch, AskUserQuestion]
---

# expo-harness-research

Phase A, step 1 of the expo-harness pipeline. Reads the user's raw idea from `config.md`, performs
kind-aware market research if needed, proposes 2-3 concrete concepts, queries the user via
AskUserQuestion to pick one, runs a store clone-avoidance check on the choice, then writes the
research spec and advances the pipeline state.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) are defined in
`docs/harness-protocol.md` — refer to that document as the single source of truth. Do not redefine
schemas here.

---

## Input

Read `docs/harness/config.md` and extract:

- `app_idea` — the raw one-line pitch supplied by the user (may be blank, in which case Discovery
  and "Propose & query" generate concepts from scratch).
- `kind` — `game` or `app`. Drives which Discovery/Propose branch runs (see below).
- `skip_research` — boolean. If `true`, treat `app_idea` as the chosen concept verbatim and
  **skip Discovery and "Propose & query" entirely**. Jump directly to Clone avoidance, then Output.
  Even when skipping discovery you must still write the research spec.
- `auto_idea` — boolean (default `false`). When `true`, "Propose & query" and "Clone avoidance"
  auto-decide instead of calling AskUserQuestion: the skill scores its own generated concepts,
  selects the best, and auto-revises any clone — running fully hands-off. Under
  `skip_research: true`, `auto_idea` has no effect on concept *selection* (the idea is taken
  verbatim — there is nothing to score or select), but it still governs Clone avoidance: it
  determines whether a detected clone is auto-revised or surfaced to the user via
  AskUserQuestion, exactly as it would with Discovery enabled.
- `default_language` — the concepts, spec prose, and every section of the research spec produced
  in Output are written in this language. This SKILL.md's own prose stays English; only the
  generated project artifacts follow `default_language`.

If `config.md` does not exist, abort with:
`expo-harness-research: docs/harness/config.md not found — run the orchestrator to bootstrap first.`

---

## Discovery

> Skip this section when `skip_research: true`.

Goal: ground the proposals in real market data. Branch on `kind`.

Before running any WebSearch query below, get the current year via `date +%Y` (Bash) and
substitute it for `<current-year>` — never hardcode a year, or the queries go stale.

### 1. Category / chart leaders

- **`kind: game`** — use WebSearch/WebFetch to fetch current top-grossing and top-free mobile game
  charts (App Store, Google Play). Queries: `"Google Play" top grossing mobile games <current-year>`,
  `"App Store" top free games <current-year>`. Extract at least 10 titles with genre/mechanic (idle
  clicker, hyper-casual runner, match-3, tower defense, merge, etc.).
- **`kind: app`** — identify the app category closest to `app_idea` (or, if blank, a small set of
  candidate categories) and fetch the current top-ranked apps in that category on both stores.
  Queries: `"App Store" top apps <category> <current-year>`, `"Google Play" top apps <category>
  <current-year>`. Extract at least 10 titles with their core feature set.

### 2. Competitor mapping

For the genre/category most aligned with `app_idea` (or the top matches by chart frequency), fetch
3-5 representative store pages via WebFetch. Record for each:

- Title, genre/category, core mechanic (game) or core feature set (app)
- Differentiating feature (what makes it stand out)
- Approximate rating and download tier (if visible on the page)

### 3. Trend signals

- **`kind: game`** — WebSearch `"mobile game genre trends <current-year>"` and `"hypercasual game
  trends <current-year>"`. Extract 2-3 specific signals (e.g. "merge mechanics growing 40% YoY").
- **`kind: app`** — WebSearch `"<category> app trends <current-year>"` and `"mobile app category
  growth <current-year>"`. Extract 2-3 specific signals (e.g. "on-device habit trackers rising").

---

## Propose & query

> Skip this section when `skip_research: true`.

Use the field set for the active `kind` below, then branch on whether `app_idea` is blank.

### `kind: game`

| Field | Description |
|---|---|
| Title | Working title |
| Tagline | One sentence (≤ 15 words) describing the core loop |
| Core mechanic | What the player does every 10–30 seconds |
| Differentiator | One thing that makes it distinct from existing top charts |
| Monetization hook | One-line note on how monetization could plausibly fit (ads / IAP moment) — mechanism and config deferred to Phase B |

### `kind: app`

| Field | Description |
|---|---|
| Title | Working title |
| Tagline | One sentence (≤ 15 words) describing the core value proposition |
| Primary journey | The main user flow (e.g. onboarding → core task → outcome) |
| Differentiator | One thing that makes it distinct from comparable apps |
| Monetization hook | One-line note on how monetization could plausibly fit (subscription / freemium moment) — mechanism and config deferred to Phase B |

### If `app_idea` is non-blank — refine the single idea

Refine `app_idea` into exactly **one** concrete concept using the field set above — do not invent
alternatives. There is no proposal list and no selection step here. Proceed directly to Clone
avoidance with this concept.

### If `app_idea` is blank — generate & recommend 2-3 concepts

Synthesise Discovery findings into exactly **2-3 concrete concept proposals** using the field set
above. Present the proposals in a numbered list that is easy to read.

Then branch on `auto_idea`:

#### If `auto_idea: false` (default) — ask the user

Use **AskUserQuestion**:

```
Which concept would you like to build?
Reply with the number (1, 2, or 3), or describe a variation.
If you are happy with one as-is, just type its number.
```

Wait for the user's response. If they type a number, that proposal is chosen. If they describe a
variation, merge their input with the closest base proposal and confirm with a follow-up
AskUserQuestion:

```
Got it. I'll build: <merged concept summary>.
Is this correct? (yes / describe further)
```

Repeat until the user confirms.

#### If `auto_idea: true` — auto-score and select (no user input)

Do **not** call AskUserQuestion. Score each proposal against these weighted criteria and present a
scoring table:

| Criterion | Weight |
|---|---|
| Market fit | 35% |
| Differentiation / clone-safety | 30% |
| Feasibility within Expo/RN scope | 20% |
| MVP scope feasibility | 15% |

Score each criterion 0–10, multiply by its weight, sum to a weighted total per proposal. Render the
table (one row per proposal, one column per criterion, plus a Total column), then **select the
proposal with the highest total** as the chosen concept. Print the choice and a one-line rationale,
e.g. `Auto-selected: <title> (total 8.4/10) — strongest market fit with a clone-safe twist.` Then
proceed to Clone avoidance. Do not query the user.

---

## Clone avoidance

**Always runs** — even when `skip_research: true` — on the chosen concept (or, under
`skip_research`, on `app_idea` accepted verbatim). Two store policies apply:

- **App Store Guideline 4.3** (Spam/clone rule): rejects apps that are copies or lightly-templated
  variants of an existing app with no meaningfully added value.
- **Google Play Impersonation / Minimum Functionality policy**: rejects apps that mimic another
  app's name, icon, or overall UX without sufficient distinct functionality.

### Check procedure

1. Extract the core mechanic (game) or core value proposition (app) from the chosen concept.
2. Use WebSearch to find the 3 most similar existing apps/games (get the current year via
   `date +%Y`, as in Discovery, and substitute it for `<current-year>`):
   - `kind: game` — `"<core mechanic>" mobile game App Store <current-year> OR <previous-year>`
   - `kind: app` — `"<core value proposition>" app App Store OR Google Play <current-year> OR
     <previous-year>`
3. For each similar app/game, note: title, mechanic/value proposition, distinctive features.
4. Apply the clone test: a concept is a **clone** if it shares the same mechanic/value proposition
   AND the same theme/domain AND offers no original feature. A concept is **safe** if it has at
   least one of:
   - A novel mechanic/flow twist not present in the top-3 matches
   - A distinct setting/domain/art direction not present in the top-3 matches
   - A mode/feature absent from the top-3 matches (e.g. co-op play, offline-first, a workflow the
     competitors lack)
5. If the concept is a clone, do not proceed. Branch on `auto_idea`:

   **If `auto_idea: false` (default)** — AskUserQuestion:
   ```
   The chosen concept is too similar to <similar app> on the App Store / Google Play, which may
   trigger App Store guideline 4.3 or Google Play's impersonation policy.
   Please describe how you want to differentiate it, or pick a different concept.
   ```
   Then re-run the clone check on the revised concept.

   **If `auto_idea: true`** — do **not** call AskUserQuestion. Auto-revise by applying one
   differentiator from the "safe" list above, then re-run the clone check. Retry up to 2 attempts.
   If still a clone:
   - **If a proposal list exists** (i.e. `skip_research` was not `true` — Propose & query ran),
     fall back to the next-highest-scored proposal from that list and run the clone check on it.
   - **If no proposal list exists** (`skip_research: true` — Propose & query never ran, so there
     is nothing to fall back to), ask the user for a new direction via AskUserQuestion despite
     `auto_idea: true` — a persistent clone on a single skip-research idea cannot be resolved
     hands-off:
     ```
     The provided idea remains too similar to <similar app> on the App Store / Google Play after
     automatic revision attempts, which may trigger App Store guideline 4.3 or Google Play's
     impersonation policy. Please describe how you want to differentiate it, or provide a
     different idea.
     ```
     If the run is truly non-interactive (no user available to ask), instead set `state.md` to
     `status: paused`, `pause_reason: manual_action`, append a note to `pipeline-log.md` explaining
     that the skip-research idea could not be made clone-safe automatically, and stop — do not
     write the research spec.
   Record the outcome (which differentiator was applied, that a fallback proposal was used, or
   that the run was escalated/paused).
6. Record the clone-check result in the research spec (see Output) as `SAFE` or `CLONE (resolved)`.

---

## Output

Note: step 2 below intentionally overwrites `config.md`'s `app_idea` with the confirmed concept's
tagline — this is a deliberate side effect, not silent drift, since the plan phase reads the
refined idea from `config.md` rather than the raw pitch.

### 1. Write the research spec

Create `docs/harness/specs/<YYYY-MM-DD>-research.md` (today's UTC date; get it via
`date -u +%Y-%m-%d`). Create `docs/harness/specs/` first if it does not yet exist. Write the entire
spec — headers, labels, and prose — in `default_language`:

```markdown
# Research Spec — <app_name>

## Chosen Concept

**Title:** <working title>
**Tagline:** <one sentence>
**Core mechanic / primary journey:** <game: what the player does every 10–30s | app: the main user flow>
**Differentiator:** <unique hook>
**Monetization hook:** <one-line note — mechanism and config deferred to Phase B>
**Selection:** <user-selected | auto-selected (auto_idea) — with the weighted total if auto-selected>

## Market Rationale

<2-4 sentences summarising the chart/trend data that supports this choice. Reference the top
competitors and the trend signals discovered. Omit or note as skipped when skip_research applied.>

## Competitor Summary

| Title | Core mechanic / value proposition | Differentiator |
|---|---|---|
| <title> | <mechanic/value prop> | <differentiator> |

## Clone-Avoidance Check (App Store 4.3 / Google Play Impersonation)

**Result:** SAFE / CLONE (resolved)
**Similar apps/games checked:** <title 1>, <title 2>, <title 3>
**Differentiating features:** <list the features that prevent a rejection under either policy>

## Skip-Research Note

<!-- If skip_research was true, write: "Discovery skipped — app_idea accepted verbatim." -->
<!-- Otherwise delete this section. -->
```

### 2. Update `config.md`

Set `app_idea` to the final confirmed concept tagline (overwrite the original raw idea) so
downstream skills (plan, design, contract) read the refined concept, not the raw prompt. Use `Edit`
for a targeted update — do not rewrite the entire file.

### 3. Update `state.md`

Update `docs/harness/state.md` per the schema in `docs/harness-protocol.md` §2:

```yaml
status: running
current_phase: research
next_role: plan
updated_at: "<ISO-8601 UTC now>"
```

Leave all other keys unchanged. Use `Edit` for a targeted update. This follows the `research →
complete → plan` row of the transition table in `docs/harness-protocol.md` §7.

### 4. Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | research | complete | plan |
```

---

## Error handling

- If WebSearch or WebFetch fails during Discovery, log a warning and proceed with whatever data was
  retrieved. Do not abort — partial market data is better than none.
- If the user declines all proposals and provides no viable alternative after 3 rounds of
  AskUserQuestion, set `state.md` to `status: paused`, `pause_reason: manual_action`, and write a
  note to `pipeline-log.md` explaining that the user could not settle on a concept.
- If `docs/harness/specs/` does not exist, create it before writing the spec file.
