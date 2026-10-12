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

1. **The 96 GB card is gated to the top tier.** `G4` is a *Premium GPU*; it is
   unlocked by Google AI Ultra (and reachable via Colab Pro+), not by the
   cheaper Google AI Pro plan. Cheap-tier compute units cannot select it.
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
# One-shot ephemeral job: provision -> run local script -> collect output -> release
colab run --gpu G4 train.py --epochs 3

# Or manage the session explicitly
colab new --gpu G4
colab install -s <name> -r requirements.txt
colab exec -s <name> -f generate_data.py
colab download -s <name> /content/output.jsonl ./output.jsonl
colab stop -s <name>            # ALWAYS stop — the VM meters credits while alive
```

Supported accelerators: `T4`, `L4`, `G4` (RTX PRO 6000, 96 GB), `H100`, `A100`;
TPUs `v5e1`, `v6e1`. Availability depends on your subscription tier and live
capacity; `G4` is frequently unavailable.

See `skills/colab/SKILL.md` for the full contract: data transfer paths, the
eligibility and terms boundaries, and the known traps.
