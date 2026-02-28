#!/usr/bin/env bash
# test-update-pipeline.sh — automated validation for pr-ship-update cron pipeline
# Run: bash scripts/test-update-pipeline.sh [--live]
# --live: also runs the actual cron job at the end (optional)
set -uo pipefail

SKILL_DIR="/home/dev/.openclaw/skills/pr-ship"
OPENCLAW_DIR="/home/dev/openclaw"
PASS=0
FAIL=0
WARN=0

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

pass() { ((PASS++)); green "  ✔ $1"; }
fail() { ((FAIL++)); red   "  ✘ $1"; }
warn() { ((WARN++)); yellow "  ⚠ $1"; }

# ─── Pre-flight ───────────────────────────────────────────────
bold "═══ pr-ship update pipeline tests ═══"
echo ""

# ─── T1: Git repo health ─────────────────────────────────────
bold "T1: Git repo health"

if [ -d "$SKILL_DIR/.git" ]; then
  pass ".git directory exists"
else
  fail ".git directory missing — run 'git init' in $SKILL_DIR"
fi

REMOTE=$(cd "$SKILL_DIR" && git remote get-url origin 2>/dev/null || echo "none")
if [[ "$REMOTE" == *"Glucksberg/pr-ship"* ]]; then
  pass "Remote origin points to Glucksberg/pr-ship"
else
  fail "Remote origin is '$REMOTE' — expected Glucksberg/pr-ship"
fi

BRANCH=$(cd "$SKILL_DIR" && git branch --show-current 2>/dev/null || echo "none")
if [ "$BRANCH" = "main" ]; then
  pass "On branch main"
else
  fail "On branch '$BRANCH' — expected main"
fi

if cd "$SKILL_DIR" && git push --dry-run origin main &>/dev/null; then
  pass "Git push dry-run succeeds (auth OK)"
else
  fail "Git push dry-run failed — check SSH key / auth"
fi

echo ""

# ─── T2: Stray file leak prevention ──────────────────────────
bold "T2: Stray file leak prevention"

TRAP_FILE="$SKILL_DIR/.env.test-trap"
echo "SECRET_KEY=do-not-commit" > "$TRAP_FILE"

cd "$SKILL_DIR"
# Simulate the exact staging command from the cron job
git add references/CURRENT-CONTEXT.md package.json 2>/dev/null || true
STAGED=$(git diff --cached --name-only 2>/dev/null)

if echo "$STAGED" | grep -q ".env.test-trap"; then
  fail "Stray file .env.test-trap was staged! git add is too broad"
else
  pass "Stray file .env.test-trap NOT staged (explicit paths work)"
fi

# Also verify .gitignore blocks it
if git check-ignore -q "$TRAP_FILE" 2>/dev/null; then
  pass ".gitignore blocks .env files"
else
  warn ".gitignore does not explicitly block .env.test-trap (relies on explicit staging)"
fi

# Cleanup
rm -f "$TRAP_FILE"
git reset HEAD -- . &>/dev/null || true

# Test with a random unknown file too
RANDOM_FILE="$SKILL_DIR/random-debug-$(date +%s).txt"
echo "debug stuff" > "$RANDOM_FILE"
git add references/CURRENT-CONTEXT.md package.json 2>/dev/null || true
STAGED=$(git diff --cached --name-only 2>/dev/null)

if echo "$STAGED" | grep -q "random-debug"; then
  fail "Random file was staged — explicit add is broken"
else
  pass "Random file NOT staged"
fi

rm -f "$RANDOM_FILE"
git reset HEAD -- . &>/dev/null || true

echo ""

# ─── T3: Version bump logic ──────────────────────────────────
bold "T3: Version bump logic"

CURRENT_VER=$(jq -r .version "$SKILL_DIR/package.json")
EXPECTED_BUMP=$(node -e "const v='$CURRENT_VER'.split('.'); v[v.length-1]=+v[v.length-1]+1; console.log(v.join('.'))")

if [ -n "$EXPECTED_BUMP" ] && [ "$EXPECTED_BUMP" != "$CURRENT_VER" ]; then
  pass "Version bump: $CURRENT_VER → $EXPECTED_BUMP"
else
  fail "Version bump produced invalid result: '$EXPECTED_BUMP'"
fi

# Test edge cases
for TEST_VER in "1.0.0" "1.0.99" "2.5.3" "0.0.1"; do
  RESULT=$(node -e "const v='$TEST_VER'.split('.'); v[v.length-1]=+v[v.length-1]+1; console.log(v.join('.'))")
  EXPECTED_LAST=$((${TEST_VER##*.} + 1))
  if [[ "$RESULT" == *".$EXPECTED_LAST" ]]; then
    pass "Bump $TEST_VER → $RESULT"
  else
    fail "Bump $TEST_VER → $RESULT (unexpected)"
  fi
done

echo ""

# ─── T4: sed metadata update ─────────────────────────────────
bold "T4: sed metadata update (dry-run on copy)"

TMPFILE=$(mktemp)
cp "$SKILL_DIR/references/CURRENT-CONTEXT.md" "$TMPFILE"

TEST_DATE="2099-01-01T00:00 UTC"
sed -i "s|_Auto-updated by.*|_Auto-updated by pr-ship-update cron. Last updated: ${TEST_DATE} (upstream sync)_|" "$TMPFILE"

if grep -q "pr-ship-update cron" "$TMPFILE"; then
  pass "Timestamp sed pattern matches and updates"
else
  fail "Timestamp sed pattern did NOT match — CURRENT-CONTEXT.md format may have changed"
fi

if grep -q "$TEST_DATE" "$TMPFILE"; then
  pass "Date injection works correctly"
else
  fail "Date was not injected into timestamp line"
fi

# Test version update
sed -i "s|## Active Version:.*|## Active Version: 9999.99.99 (Released)|" "$TMPFILE"
if grep -q "## Active Version: 9999.99.99" "$TMPFILE"; then
  pass "Version sed pattern matches and updates"
else
  fail "Version sed pattern did NOT match — check CURRENT-CONTEXT.md header format"
fi

rm -f "$TMPFILE"

echo ""

# ─── T5: CHANGELOG detection ─────────────────────────────────
bold "T5: CHANGELOG change detection"

cd "$OPENCLAW_DIR"
git fetch upstream --quiet 2>/dev/null || true
LOCAL_SHA=$(git rev-parse main:CHANGELOG.md 2>/dev/null || echo none)
UPSTREAM_SHA=$(git rev-parse upstream/main:CHANGELOG.md 2>/dev/null || echo none)

if [ "$LOCAL_SHA" != "none" ] && [ "$UPSTREAM_SHA" != "none" ]; then
  pass "Can read CHANGELOG SHA (local=$LOCAL_SHA upstream=$UPSTREAM_SHA)"
  if [ "$LOCAL_SHA" = "$UPSTREAM_SHA" ]; then
    pass "CHANGELOGs match (cron would skip — this is normal)"
  else
    warn "CHANGELOGs differ (cron would trigger an update)"
  fi
else
  fail "Cannot read CHANGELOG SHAs — git refs broken"
fi

# Version extraction
VER=$(git show upstream/main:CHANGELOG.md 2>/dev/null | grep -oP '^## \K[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
if [ -n "$VER" ]; then
  pass "Version extraction from CHANGELOG works: $VER"
else
  warn "Could not extract version from upstream CHANGELOG (may be empty or format changed)"
fi

echo ""

# ─── T6: Provenance verification ─────────────────────────────
bold "T6: Provenance verification"

cd "$SKILL_DIR"
LOCAL_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
REMOTE_SHA=$(git ls-remote origin HEAD 2>/dev/null | cut -c1-7 || echo "none")

if [ "$LOCAL_SHA" != "none" ] && [ "$REMOTE_SHA" != "none" ]; then
  pass "Can query both local and remote HEAD"
  if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
    pass "Provenance verified: local ($LOCAL_SHA) == remote ($REMOTE_SHA)"
  else
    warn "Provenance mismatch: local=$LOCAL_SHA remote=$REMOTE_SHA (may need push)"
  fi
else
  fail "Cannot query HEAD SHAs for provenance check"
fi

echo ""

# ─── T7: ClawHub CLI availability ────────────────────────────
bold "T7: ClawHub CLI"

if command -v clawhub &>/dev/null; then
  pass "clawhub CLI found: $(which clawhub)"
else
  fail "clawhub CLI not found in PATH"
fi

if clawhub whoami &>/dev/null; then
  pass "clawhub auth valid"
else
  fail "clawhub auth failed — run 'clawhub login'"
fi

echo ""

# ─── T8: Cron job config validation ──────────────────────────
bold "T8: Cron job config"

JOBS_FILE="$HOME/.openclaw/cron/jobs.json"
if [ -f "$JOBS_FILE" ]; then
  JOB_MSG=$(python3 -c "
import json
jobs=json.load(open('$JOBS_FILE'))['jobs']
j=[x for x in jobs if x['id']=='492d067a-5cb1-47c5-92bc-fd8985c64a1f']
if j: print(j[0]['payload']['message'])
else: print('NOT_FOUND')
" 2>/dev/null || echo "PARSE_ERROR")

  if [ "$JOB_MSG" = "NOT_FOUND" ]; then
    fail "Cron job 492d067a not found in jobs.json"
  elif [ "$JOB_MSG" = "PARSE_ERROR" ]; then
    fail "Could not parse jobs.json"
  else
    pass "Cron job 492d067a found"

    # Check for dangerous patterns
    # Count actual git add commands (in code blocks, not in instructional text)
    # The instruction says "Never use git add -A" but actual command should be explicit
    ACTUAL_ADD=$(echo "$JOB_MSG" | grep -c "^git add " || true)
    SAFE_ADD=$(echo "$JOB_MSG" | grep -c "git add references/CURRENT-CONTEXT.md package.json" || true)
    if [ "$SAFE_ADD" -ge 1 ]; then
      pass "Uses explicit git add (references/CURRENT-CONTEXT.md package.json)"
    else
      fail "Missing explicit git add command"
    fi

    if echo "$JOB_MSG" | grep -q "GIT_OK"; then
      pass "Has GIT_OK guard for push failure"
    else
      fail "Missing GIT_OK guard — clawhub publish not gated on push success"
    fi

    if echo "$JOB_MSG" | grep -q "SKIP_CLAWHUB"; then
      pass "Has SKIP_CLAWHUB guard"
    else
      fail "Missing SKIP_CLAWHUB guard"
    fi

    if echo "$JOB_MSG" | grep -q "git ls-remote"; then
      pass "Has real provenance check (git ls-remote)"
    else
      warn "No git ls-remote provenance check"
    fi

    TIMEOUT=$(python3 -c "
import json
jobs=json.load(open('$JOBS_FILE'))['jobs']
j=[x for x in jobs if x['id']=='492d067a-5cb1-47c5-92bc-fd8985c64a1f'][0]
print(j['payload']['timeoutSeconds'])
" 2>/dev/null || echo "0")
    if [ "$TIMEOUT" -ge 180 ]; then
      pass "Timeout is ${TIMEOUT}s (>= 180s)"
    else
      fail "Timeout is ${TIMEOUT}s — should be >= 180s for git+clawhub steps"
    fi
  fi
else
  fail "jobs.json not found at $JOBS_FILE"
fi

echo ""

# ─── T9: File integrity ──────────────────────────────────────
bold "T9: Skill file integrity"

cd "$SKILL_DIR"

# package.json
if jq -e .homepage package.json &>/dev/null; then
  HP=$(jq -r .homepage package.json)
  if [[ "$HP" == *"github.com/Glucksberg/pr-ship"* ]]; then
    pass "package.json homepage present and correct"
  else
    fail "package.json homepage is '$HP' — expected Glucksberg/pr-ship URL"
  fi
else
  fail "package.json missing homepage field"
fi

if jq -e .bugs.url package.json &>/dev/null; then
  pass "package.json bugs.url present"
else
  fail "package.json missing bugs.url field"
fi

# SKILL.md
if grep -q "## Provenance" SKILL.md; then
  pass "SKILL.md has Provenance section"
else
  fail "SKILL.md missing Provenance section"
fi

if grep -q "## Security Notice" SKILL.md; then
  pass "SKILL.md has Security Notice section"
else
  fail "SKILL.md missing Security Notice section"
fi

# README.md
if [ -f README.md ]; then
  pass "README.md exists"
else
  fail "README.md missing"
fi

# .gitignore
if [ -f .gitignore ]; then
  if grep -q "DEVELOPER-REFERENCE.md.archive" .gitignore; then
    pass ".gitignore excludes archive"
  else
    fail ".gitignore missing archive exclusion"
  fi
  if grep -q ".env" .gitignore; then
    pass ".gitignore excludes .env files"
  else
    warn ".gitignore missing .env exclusion"
  fi
else
  fail ".gitignore missing"
fi

echo ""

# ─── T10: GitHub repo state ──────────────────────────────────
bold "T10: GitHub repo state"

if gh repo view Glucksberg/pr-ship &>/dev/null; then
  pass "GitHub repo Glucksberg/pr-ship exists"
else
  fail "GitHub repo Glucksberg/pr-ship not accessible"
fi

GH_FILES=$(gh api repos/Glucksberg/pr-ship/contents/ --jq '.[].name' 2>/dev/null | tr '\n' ' ')
for EXPECTED in .gitignore README.md SKILL.md package.json references; do
  if echo "$GH_FILES" | grep -q "$EXPECTED"; then
    pass "GitHub has $EXPECTED"
  else
    fail "GitHub missing $EXPECTED"
  fi
done

echo ""

# ─── Summary ─────────────────────────────────────────────────
bold "═══ Results ═══"
echo ""
green "  Passed:   $PASS"
if [ "$WARN" -gt 0 ]; then
  yellow "  Warnings: $WARN"
fi
if [ "$FAIL" -gt 0 ]; then
  red "  Failed:   $FAIL"
fi
echo ""

if [ "$FAIL" -gt 0 ]; then
  red "RESULT: $FAIL test(s) failed — fix before next cron run"
  EXIT_CODE=1
else
  if [ "$WARN" -gt 0 ]; then
    yellow "RESULT: All passed with $WARN warning(s)"
  else
    green "RESULT: All tests passed ✔"
  fi
  EXIT_CODE=0
fi

# ─── Optional: live cron trigger ──────────────────────────────
if [[ "${1:-}" == "--live" ]]; then
  echo ""
  bold "═══ Live cron trigger ═══"
  echo "Triggering pr-ship-update cron job..."
  pnpm --dir "$OPENCLAW_DIR" openclaw cron run 492d067a-5cb1-47c5-92bc-fd8985c64a1f 2>&1 || true
  echo ""
  echo "Check Telegram for the report. Verify with:"
  echo "  cd $SKILL_DIR && git log --oneline -3"
  echo "  gh api repos/Glucksberg/pr-ship/commits/main --jq '.sha[:7]'"
fi

exit $EXIT_CODE
