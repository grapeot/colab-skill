# Colab Skill

A public agent skill for **running Google Colab headlessly** — create GPU/TPU
runtimes, execute local scripts on them, move data in and out, and tear them
down — using Google's official `google-colab-cli`. No browser, no notebook GUI.

It is written for coding agents (Claude Code, Codex, Cursor, OpenCode, …) and
for humans who automate from the terminal.

## Why this exists

Google AI subscriptions now bundle Colab compute units, and Colab offers a full
NVIDIA RTX PRO 6000 Blackwell (96 GB) as its `G4` accelerator. That makes Colab
a zero-setup way to get a large-VRAM card by the hour for **batch data
generation and fine-tuning**. But three things trip people up, and this skill
encodes all three:

1. **Premium GPU is a published benefit, not a 400 diagnosis.** `G4` is a
   *Premium GPU*. Google's Ultra benefits page states premium GPU access for
   Ultra members, and limits that Colab feature to 18+, the family plan
   manager, non-trial memberships, and the listed regions:
   https://support.google.com/googleone/answer/16286513
   That sentence is not 20x-only. Do not require an upgrade from 5x to 20x to
   request `G4`. Do not read the page as excluding Colab Pro+: a 2026-08-10
   comment on https://github.com/googlecolab/colabtools/issues/6076 said G4
   was available to Colab Pro+ at that time. That note is dated and does not
   guarantee allocation. Prefer omitting `--high-mem` for `G4`. Omitting it
   does not guarantee allocation. A 400 on that flag is not proof the plan
   lacks entitlement.
2. **Credits are a budget, not a reservation.** They meter by the hour the VM is
   alive and expire. A `colab new` session burns credits until you `colab stop`.
3. **It is built for interactive compute, not hosting.** There is no scale-out,
   sessions are capped, `/content` is ephemeral, and the terms forbid running a
   standing service.

This skill is the generic technical contract for driving the CLI safely. Your
own workspace keeps its private account choice, default GPU, and any decision
rules in a **local overlay**, not here.

## Install

This repo is a loose Markdown skill, not a vendor-locked package. Hand the URL
to your coding agent:

```text
Install this public skill repo into my workspace:
https://github.com/grapeot/colab-skill

Start from my workspace AGENTS.md or CLAUDE.md. Follow any WORKSPACE.md or
skills/INDEX.md routing rules. Clone or vendor the repo under an appropriate
project directory. Expose exactly one root skill (`skills/colab/SKILL.md`) to my
global skill index. Keep private aliases, account names, paths, and defaults in a
local overlay, not in the public repo.
```

Then install the underlying tool:

```bash
uv tool install google-colab-cli   # or: pip install google-colab-cli
colab version
```

## First-time login

The CLI authenticates as a Google account (the one that holds your Colab
entitlement) via an OAuth copy-paste flow: it prints an authorization URL, you
approve in a browser, and you paste back the code. The refresh token is cached
in `~/.config/colab-cli/token.json`.

`scripts/colab_login.sh` wraps that flow and **opens the URL in your default
browser for you**, so you only approve and paste the code:

```bash
./scripts/colab_login.sh
```

Confirm who you are and how many compute units you have:

```bash
colab whoami
colab usage
```

## Usage

```bash
# One-shot cell. --timeout defaults to 30s. A timeout is not a completed job.
colab run --gpu G4 --timeout 3600 train.py --epochs 3

# Managed cell. Name the session. Collect, then stop, even when exec fails.
name=example
rc=0
colab new -s "$name" --gpu G4 || exit 1
colab install -s "$name" -r requirements.txt || rc=$?
if [ "$rc" -eq 0 ]; then
  colab exec -s "$name" --timeout 3600 -f generate_data.py || rc=$?
fi
colab download -s "$name" /content/output.jsonl ./output.jsonl || rc=$?
colab stop -s "$name" || rc=$?
# stop exit 0 is not proof of release. Do not print session lines.
list="$(mktemp)"
list_rc=0
colab sessions >"$list" || list_rc=$?
if [ "$list_rc" -ne 0 ]; then
  printf 'could not list sessions: exit %s\n' "$list_rc" >&2
  rc=1
elif grep -F "[${name}] " "$list" >/dev/null; then
  printf 'session still listed: %s\n' "$name" >&2
  rc=1
fi
rm -f "$list"
if [ "$rc" -ne 0 ]; then
  printf 'not complete: exit %s\n' "$rc" >&2
  exit "$rc"
fi
```

`colab exec -f` reads the local file and runs that source as a notebook cell.
It does not set `__file__` and does not place a file on the VM. The download
above is a path that cell must have written. The real-file sequence (create the
parent, `colab upload`, subprocess the uploaded path), the GPU probe, and the
finally / external deadline contract are in `skills/colab/SKILL.md`. This repo
does not reimplement `upload` or `exec`.

Supported accelerators: `T4`, `L4`, `G4` (RTX PRO 6000, 96 GB), `H100`, `A100`;
TPUs `v5e1`, `v6e1`. For `G4`, prefer omitting `--high-mem`. That omission
does not guarantee allocation. The default shape can already have a large host
RAM. `HIGH_RAM` is a requested shape, not a required performance switch.
`Service Unavailable` (HTTP 503) is a class, not a proven capacity cause. A
retry once, then a fallback, is a suggestion and does not guarantee
allocation. An accelerator HTTP 400 has an unknown cause. On CLI 0.7.4 the
"quota or entitlement" text is a guess; the CLI does not read the response
body. Do not treat that 400 as a missing-plan diagnosis.

See `skills/colab/SKILL.md` for the full contract: data transfer paths, the
eligibility and terms boundaries, and the known traps.
