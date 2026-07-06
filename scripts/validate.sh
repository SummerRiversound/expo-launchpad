#!/usr/bin/env bash
# Test harness for the expo-harness plugin. Run: bash scripts/validate.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
fail=0; err(){ echo "FAIL: $*"; fail=1; }; ok(){ echo "ok:   $*"; }

# 1. Manifests: valid JSON + required keys
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  if [ -f "$f" ]; then jq empty "$f" 2>/dev/null && ok "$f valid JSON" || err "$f invalid JSON"; else err "$f missing"; fi
done
jq -e '.name and .version and .description' .claude-plugin/plugin.json >/dev/null 2>&1 \
  || err "plugin.json missing name/version/description"

# 2. Skills: frontmatter with name + description + argument-hint + allowed-tools
EXPECTED_SKILLS="expo-harness expo-harness-research expo-harness-plan expo-harness-design expo-harness-contract expo-harness-generator expo-harness-evaluator expo-harness-resume expo-harness-status"
for name in $EXPECTED_SKILLS; do
  s="skills/$name/SKILL.md"
  if [ ! -f "$s" ]; then err "$s missing"; continue; fi
  head -1 "$s" | grep -q '^---$' || { err "$s: no frontmatter"; continue; }
  for key in name description argument-hint allowed-tools; do
    awk -v k="$key" 'NR>1&&/^---$/{exit} $0 ~ "^"k":"{f=1} END{exit !f}' "$s" \
      || err "$s: frontmatter missing '$key'"
  done
  ok "$s frontmatter"
done

# 3. Grep-cleanliness: no leftover Flutter/Flame/Dart tokens in skills + the two harness docs
#    (scope docs to the harness docs only — docs/superpowers/{specs,plans} legitimately cite the reference)
BAD='flutter|flame|\bdart\b|pubspec|sharedpreferences|widgetsbinding|\.arb\b|game_config\.dart|cupertino'
if grep -rniE "$BAD" skills docs/harness-protocol.md docs/app-gotchas.md 2>/dev/null | grep -viE 'migrat|ported from|formerly'; then
  err "leftover Flutter/Flame/Dart token(s) above"
else ok "no Flutter/Flame/Dart tokens"; fi

# 4. Plugin-doc cross-references resolve. Ignore docs/harness/* (runtime paths inside the GENERATED
#    project, not files in this repo) and docs/superpowers/* (spec/plan).
miss=0
while read -r ref; do
  [ -z "$ref" ] && continue
  case "$ref" in docs/harness/*|docs/superpowers/*) continue;; esac
  [ -f "$ref" ] || { echo "FAIL: dangling ref $ref"; miss=1; }
done < <(grep -rhoE 'docs/[A-Za-z0-9_./-]+\.md' skills 2>/dev/null | sort -u)
[ "$miss" -eq 0 ] && ok "plugin-doc cross-references resolve" || err "dangling docs cross-reference(s)"

# 5. Orchestrator dispatches every phase role
if [ -f skills/expo-harness/SKILL.md ]; then
  for role in research plan design contract generator evaluator; do
    grep -q "expo-harness-$role" skills/expo-harness/SKILL.md || err "orchestrator missing dispatch: $role"
  done
  ok "orchestrator dispatch table"
fi

# 6. Required docs exist with key sections
for pair in "docs/harness-protocol.md:## 7. Phase Transition Table" "docs/app-gotchas.md:## Performance"; do
  f="${pair%%:*}"; sec="${pair#*:}"
  [ -f "$f" ] || { err "$f missing"; continue; }
  grep -qF "$sec" "$f" || err "$f missing section '$sec'"
done

echo "----"
[ "$fail" -eq 0 ] && echo "ALL CHECKS PASSED" || { echo "VALIDATION FAILED"; exit 1; }
