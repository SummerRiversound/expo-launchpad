#!/usr/bin/env bash
# Test harness for the expo-launchpad plugin. Run: bash scripts/validate.sh
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
EXPECTED_SKILLS="expo-launchpad expo-launchpad-research expo-launchpad-plan expo-launchpad-design expo-launchpad-contract expo-launchpad-generator expo-launchpad-evaluator expo-launchpad-resume expo-launchpad-status"
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

# 2b. Skills: frontmatter parses as real YAML (catches unquoted ": " inside scalar values
#     that the awk substring check above cannot detect)
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  for s in skills/*/SKILL.md; do
    [ -f "$s" ] || continue
    python3 - "$s" <<'PY'
import sys,yaml
f=sys.argv[1]; parts=open(f).read().split('---',2)
if len(parts)<3: print("FMERR",f,"no frontmatter"); sys.exit(3)
try: yaml.safe_load(parts[1])
except Exception as e: print("FMERR",f,str(e).splitlines()[0]); sys.exit(3)
PY
    if [ $? -ne 0 ]; then err "invalid YAML frontmatter: $s"; else ok "$s frontmatter parses"; fi
  done
else
  echo "skip: python3/PyYAML unavailable — YAML frontmatter parse check skipped"
fi

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
if [ -f skills/expo-launchpad/SKILL.md ]; then
  for role in research plan design contract generator evaluator; do
    grep -q "expo-launchpad-$role" skills/expo-launchpad/SKILL.md || err "orchestrator missing dispatch: $role"
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
