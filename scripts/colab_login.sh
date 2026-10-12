#!/usr/bin/env bash
#
# colab_login.sh — guide the Colab CLI OAuth copy-paste flow and OPEN the
# authorization URL in your default browser so you never copy the URL by hand.
#
# The CLI prints an authorization URL and then blocks on stdin for the code you
# get after approving. This script extracts that URL, opens it, reads the code
# you paste, and feeds it back to the waiting process.
#
# The paste-back step is intentionally interactive: it is the point of the
# consent flow and cannot be automated away.

set -euo pipefail

COLAB_BIN="${COLAB_BIN:-colab}"
TOKEN_FILE="${COLAB_TOKEN_FILE:-$HOME/.config/colab-cli/token.json}"

if ! command -v "$COLAB_BIN" >/dev/null 2>&1; then
  echo "google-colab-cli not found on PATH." >&2
  echo "Install it with: uv tool install google-colab-cli" >&2
  exit 1
fi

if [ -f "$TOKEN_FILE" ]; then
  echo "A cached Colab token already exists at: $TOKEN_FILE"
  echo "Checking identity (colab whoami):"
  "$COLAB_BIN" whoami || true
  echo
  echo "If this is the wrong account, delete the token file and re-run this script."
  exit 0
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/colab-login.XXXXXX")"
fifo="$tmp/in"
mkfifo "$fifo"
out="$tmp/out"
err="$tmp/err"

cleanup() {
  exec 3>&- 2>/dev/null || true
  kill "${pid:-}" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

# Trigger the OAuth flow (any backend call does). It prints the URL on stderr
# and then blocks reading stdin.
"$COLAB_BIN" sessions < "$fifo" > "$out" 2> "$err" &
pid=$!

# Hold the FIFO's write end open so the reader does not see EOF before we write
# the code.
exec 3> "$fifo"

url=""
for _ in $(seq 1 120); do
  url="$(grep -oE 'https://accounts\.google\.com[^[:space:]]+' "$err" 2>/dev/null | head -n1 || true)"
  [ -n "$url" ] && break
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 0.5
done

if [ -z "$url" ]; then
  echo "Could not capture the authorization URL. CLI output was:" >&2
  cat "$err" "$out" >&2
  exit 1
fi

echo "Opening the authorization URL in your browser..."
if command -v open >/dev/null 2>&1; then
  open "$url" || echo "Could not auto-open. Open manually: $url"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$url" || echo "Could not auto-open. Open manually: $url"
else
  echo "No browser opener found. Open this URL manually:"
  echo "$url"
fi

echo
printf 'Approve access, then paste the authorization code here: '
read -r code
code="$(printf '%s' "$code" | tr -d '[:space:]')"
printf '%s\n' "$code" >&3

wait "$pid" || true

echo
cat "$out"
if [ -f "$TOKEN_FILE" ]; then
  echo "Login succeeded. Token cached at: $TOKEN_FILE"
else
  echo "Login did not complete. CLI output was:" >&2
  cat "$err" >&2
  exit 1
fi
