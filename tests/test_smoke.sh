#!/usr/bin/env bash
#
# Offline smoke test: structure, helper syntax, boundary coverage, and
# public-hygiene scan. No network, no Colab account, no credits spent.
#
# Run from the repo root:  bash tests/test_smoke.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
pass=0
ok()   { printf '  ok  %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf 'FAIL  %s\n' "$1"; fail=$((fail+1)); }

echo "== required files =="
for f in README.md AGENTS.md .env.example .gitignore \
         docs/prd.md docs/rfc.md docs/test.md docs/working.md \
         skills/colab/SKILL.md scripts/colab_login.sh; do
  if [ -f "$f" ]; then ok "$f"; else bad "missing $f"; fi
done

echo "== login helper =="
if bash -n scripts/colab_login.sh 2>/dev/null; then ok "colab_login.sh syntax"; else bad "colab_login.sh syntax"; fi
if [ -x scripts/colab_login.sh ]; then ok "colab_login.sh executable"; else bad "colab_login.sh not executable"; fi
if grep -q 'open ' scripts/colab_login.sh && grep -q 'xdg-open' scripts/colab_login.sh; then
  ok "login helper opens the URL (open/xdg-open)"
else
  bad "login helper does not open the URL in a browser"
fi

echo "== skill boundary coverage =="
skill=skills/colab/SKILL.md
check_phrase() { if grep -qi "$2" "$skill"; then ok "$1"; else bad "$1"; fi; }
check_phrase "stop-the-VM rule"        "colab stop"
check_phrase "ephemeral disk rule"     "ephemeral"
check_phrase "eligibility (Premium)"   "Premium GPU"
check_phrase "no hosting / terms"      "hosting"
check_phrase "G4 unavailable handling" "Service Unavailable"
check_phrase "quota is not a retry loop" "quota or entitlement"
check_phrase "upload missing parent" "HTTP 500"
check_phrase "exec -f has no __file__" "__file__"
check_phrase "external deadline stays armed" "external deadline"
check_phrase "same-group sleep is not a deadline" "watchdog"
check_phrase "timeout is not completion" "not complete"
check_phrase "collect before stop" "colab download"
check_phrase "redact runtime proxy URLs" "runtime proxy"
if grep -q 'nohup' "$skill"; then bad "skill still ships a nohup watchdog"; else ok "no nohup watchdog"; fi
if grep -q '>/dev/null 2>&1' "$skill"; then bad "skill discards command stderr"; else ok "stderr not discarded"; fi

echo "== documented shell syntax =="
tmpd="$(mktemp -d)"
while IFS= read -r f; do
  awk -v dir="$tmpd" -v base="$(basename "$f")" '
    /^```bash$/ { p=1; n++; fn=sprintf("%s/%s.%d.sh", dir, base, n); next }
    /^```$/ && p { p=0; close(fn); next }
    p { print > fn }
  ' "$f"
done <<'FILES'
README.md
docs/test.md
skills/colab/SKILL.md
FILES
found=0
for s in "$tmpd"/*.sh; do
  [ -f "$s" ] || continue
  found=1
  if bash -n "$s"; then ok "syntax $(basename "$s")"; else bad "syntax $(basename "$s")"; fi
done
rm -rf "$tmpd"
[ "$found" -eq 1 ] || bad "no documented bash fences extracted"

echo "== public hygiene =="
# Generic patterns only; this scanner must not itself contain real secrets, and
# it excludes itself so its own pattern literals are not counted as findings.
EXCL=(--exclude-dir=.git --exclude=test_smoke.sh)

if grep -rEn 'op://' . "${EXCL[@]}" >/dev/null 2>&1; then
  bad "found op:// vault reference"
else ok "no op:// references"; fi

if grep -rEn 'BEGIN [A-Z ]*PRIVATE KEY' . "${EXCL[@]}" >/dev/null 2>&1; then
  bad "found private key block"
else ok "no private key blocks"; fi

# Emails must be example.com/.net/.org placeholders only.
bad_emails="$(grep -rEho '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' . "${EXCL[@]}" 2>/dev/null \
  | grep -viE '@example\.(com|net|org)$' | sort -u || true)"
if [ -n "$bad_emails" ]; then
  bad "non-placeholder email(s): $bad_emails"
else ok "no non-placeholder emails"; fi

# No machine-specific absolute home paths (like /Users/<someone>/ or /home/<someone>/).
if grep -rEn '/(Users|home)/[A-Za-z0-9._-]+/' . "${EXCL[@]}" >/dev/null 2>&1; then
  bad "found absolute home path"
else ok "no absolute home paths"; fi

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
