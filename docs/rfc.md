# RFC — Colab Skill

## Summary

A thin skill layer over Google's official `google-colab-cli`. The repo ships one
root skill (`skills/colab/SKILL.md`), one OAuth helper (`scripts/colab_login.sh`),
and documentation. It deliberately contains no runtime logic that the official
CLI already provides.

## Architecture

```text
caller (agent / human)
  -> skills/colab/SKILL.md          decides WHAT to do, within boundaries
  -> google-colab-cli (`colab`)      the engine: provision, exec, transfer, stop
  -> Colab backend                   the actual VM + accelerator
```

The wrapper does exactly one thing the CLI does not: `scripts/colab_login.sh`
opens the OAuth URL in the browser so the human never copies it by hand.

## Key decisions

### 1. Do not fork or vendor the CLI

The vendor already documents itself (`colab <cmd> --help`) and ships its own
agent skill (`colab skill`). Re-encoding its command reference here would
duplicate a moving target and consume agent context. This repo captures only the
**non-obvious boundaries** (eligibility, cost model, durability, terms) and the
**workspace routing** that the vendor cannot know.

### 2. Two layers: public contract + private overlay

The public repo holds the generic technical contract. Per-workspace specifics —
which Google account, default accelerator, and how Colab compares to other GPU
options — stay in the consumer's own `rules/skills/` overlay. This mirrors the
rest of the skill ecosystem and keeps private handles out of the public repo.

### 3. Authentication stays in the CLI's token cache

The CLI writes its refresh token to `~/.config/colab-cli/token.json`. The repo
never sees it. `scripts/colab_login.sh` only orchestrates the copy-paste flow;
it does not store or transmit the code.

### 4. The login helper must `open` the URL

Verified failure: an earlier manual flow made the user copy the URL out of the
terminal. The helper now extracts the URL the CLI prints and calls `open` (macOS)
/ `xdg-open` (Linux) so the browser opens automatically. The paste-back step is
unavoidable and stays interactive.

## Boundaries

- **Eligibility**: `G4` (RTX PRO 6000, 96 GB) is a Premium GPU. It is unlocked
  by Google AI Ultra and reachable via Colab Pro+. Cheaper plans get priority
  access to *faster* accelerators (T4/L4/A100), not the Premium GPU. Do not
  promise a 96 GB card to a user on a cheaper tier.
- **Cost**: compute units meter by wall-clock VM lifetime, not compute time, and
  expire (90 days for Colab-native units). Every flow must end in `colab stop`
  (or `colab run`, which self-releases).
- **Durability**: `/content` is ephemeral; the VM is deleted when idle. Artifacts
  must land in Google Drive (`colab drivemount`), GCS (`colab auth`), or the
  local machine (`colab download`) before the session ends.
- **Terms**: no file/media hosting, no standing services, no mining, no
  reselling or account sharing. Batch data generation and training scripts are
  interactive compute and are allowed.

## Data paths

| Direction | Mechanism |
|---|---|
| In (code) | `colab exec -f local.py` reads the file locally and transmits it |
| In (data, large) | stream from Hugging Face / `git clone` / `wget` on the VM; or stage on Drive/GCS |
| In (files) | `colab upload LOCAL REMOTE` |
| Out | `colab download REMOTE LOCAL`; or write to Drive/GCS |
| Persist | `colab drivemount` (Drive), `colab auth` (GCP/GCS) |

## Migration / evolution

- If Google changes CLI flags, re-verify against `colab --help` and update the
  skill; do not guess from memory.
- If a stable compute-unit rate table ever ships officially, prefer citing it
  over `colab usage`.
- If Colab gains a native scale-out API, revisit the "not a cluster" boundary.
