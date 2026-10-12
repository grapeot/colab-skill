---
name: colab
description: Run Google Colab jobs headlessly from the terminal or an agent using the official `google-colab-cli`, including GPU/TPU runtimes up to a full 96 GB RTX PRO 6000 (G4). Use when asked to run a data-generation, fine-tuning, evaluation, or heavy compute script on Colab, to provision a Colab GPU/TPU, to authenticate the Colab CLI, or to move files/data to and from a Colab runtime. Not for hosting a service on Colab or for cluster-scale jobs.
---

# Skill: Colab Headless Jobs

Run batch jobs on Google Colab accelerators by the hour, with no notebook GUI,
by driving the official `google-colab-cli`. The product of any use of this skill
is **an artifact that landed somewhere durable, and a released runtime**.

## When to use

- An agent or user needs a GPU/TPU for a bounded job: synthetic **data
  generation**, **fine-tuning**, evaluation, or a heavy script, especially when a
  large-VRAM card (up to `G4` = RTX PRO 6000, 96 GB) is the point.
- Moving data or code onto / off a Colab runtime.

## When NOT to use

- **Hosting.** Do not stand up a long-running service, API, or file/media server
  on Colab. This is against the terms and the runtime will be reclaimed.
- **Cluster scale-out.** Colab is one VM per session. For many nodes, use GCP
  (G4 VMs / Vertex AI / GKE) or Colab Enterprise.
- **Long unattended training** that exceeds the session cap and cannot
  checkpoint. Prefer a provider with persistent instances.

## Prerequisites

```bash
uv tool install google-colab-cli   # or: pip install google-colab-cli
colab version
```

Authenticate as the Google account that holds the Colab entitlement. The CLI
uses an OAuth copy-paste flow; on macOS/Linux, open the printed URL in a browser,
approve, and paste the code back. If your workspace vendors this repo, use
`scripts/colab_login.sh`, which opens the URL for you:

```bash
./scripts/colab_login.sh
colab whoami        # confirm identity + scopes
colab usage         # live compute-unit rate and balance
```

## Boundaries (do not cross)

- **Eligibility.** `G4` (RTX PRO 6000, 96 GB) is a **Premium GPU**, unlocked by
  Google AI Ultra and reachable via Colab Pro+. Cheaper plans get priority access
  to *faster* accelerators (T4/L4/A100), not the Premium GPU. Never promise a
  96 GB card to a cheaper tier.
- **Cost.** Compute units meter by **wall-clock VM lifetime**, not compute time,
  and expire. Every path must end with the runtime released: prefer `colab run`
  (self-releasing) for one-shot jobs; with `colab new`, you **must** `colab stop`.
- **Durability.** `/content` is ephemeral; the VM is deleted when idle. Land
  artifacts on Drive (`colab drivemount`), GCS (`colab auth`), or locally
  (`colab download`) *before* the session ends. Long jobs must checkpoint.
- **Terms.** No file/media hosting, standing services, mining, reselling, or
  account sharing. Batch data generation and training scripts are interactive
  compute and are allowed.
- **Secrets.** Authentication lives in the CLI's own token cache
  (`~/.config/colab-cli/token.json`). Never echo, copy, or commit it.

## Method (result-oriented, order not fixed)

1. **Pick the accelerator and job shape.** Accelerators: `T4`, `L4`, `G4`,
   `H100`, `A100`; TPUs `v5e1`, `v6e1`. Choose the smallest card that fits the
   job. `G4` when 96 GB / large-model work is required.
2. **Run the job.** One-shot: `colab run --gpu G4 script.py --args`. Managed:
   `colab new --gpu G4` then `colab install` / `colab exec -f script.py`.
   `colab exec -f file` transmits the local file, so no manual upload is needed.
3. **Move data.** Stream large datasets on the VM (HF, `git clone`, `wget`) or
   stage on Drive/GCS; use `colab upload` / `colab download` for specific files.
4. **Collect the artifact** to a durable location *before* releasing.
5. **Release.** `colab stop` (managed) or rely on `colab run`'s teardown. Verify
   with `colab sessions` that nothing is left running.

Command details are the vendor's: read `colab skill` or `colab <command> --help`
rather than memorizing flags. This skill captures only the boundaries above.

## Acceptance (self-checkable)

- The job's artifact exists at a durable path (Drive/GCS/local) and is non-empty.
- `colab sessions` shows **no** leftover session after the job.
- If a 403 appeared, `colab whoami` was used to confirm identity/scopes rather
  than guessing.

## Known traps

- **Forgetting `colab stop`.** The single most expensive mistake: a `colab new`
  VM keeps metering units until stopped. Default to `colab run`.
- **G4 unavailable is normal.** The card is often greyed out, and allocation can
  return `Service Unavailable`. Treat it as recoverable (retry once, or fall
  back to a smaller accelerator) — do not promise the 96 GB card is available.
- **Ephemeral disk.** Anything left in `/content` is lost when the VM is
  reclaimed. Checkpoint early.
- **Remote paths inside the script** (e.g. `/proc/meminfo`, datasets) must exist
  on the VM; `colab exec` transmits the *file*, not its data dependencies.
- **Wrong identity.** A service account has no Colab entitlement; use a user
  account. Debug 403s with `colab whoami`.
- **Unpublished rates.** Read `colab usage` for the live rate; never hard-code a
  units-per-hour figure.

## Private overlay

Workspace-specific details are intentionally **not** here. Which Google account
to use, a default accelerator, and how Colab compares to other GPU options
(owned hardware, other clouds, leased GPUs) belong in the consumer's local
`rules/skills/` overlay.
