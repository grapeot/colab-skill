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
  (`~/.config/colab-cli/token.json`). Never echo, copy, or commit it. Error text
  can also embed a runtime proxy URL that carries an auth token, including the
  `colab-runtime-proxy-token` query parameter and assignment error bodies.
  Redact that URL before the text leaves the terminal. Do not paste it into
  chat, issues, public logs, or this repo.

## Method (result-oriented)

1. **Pick the accelerator and job shape.** Accelerators: `T4`, `L4`, `G4`,
   `H100`, `A100`; TPUs `v5e1`, `v6e1`. Choose the smallest card that fits the
   job. `G4` when 96 GB / large-model work is required.
2. **Run the job.** One-shot, when a notebook cell is enough: `colab run --gpu G4
   --timeout <seconds> script.py`. Managed: `colab new -s example --gpu G4`, then
   `colab install` / `colab exec`. Pass an explicit `--timeout`. On CLI 0.7.4 the
   default is 30 seconds, and a timeout is not a finished job.
3. **Move data.** Stream large datasets on the VM (HF, `git clone`, `wget`) or
   stage on Drive/GCS. `colab upload` and `colab exec` are already the write
   path; do not reimplement the CLI. Create the remote parent before upload.
4. **Collect the artifact** to a durable location *before* releasing.
5. **Release.** `colab stop -s` the session you created, or rely on `colab run`
   without `--keep`. Confirm that name is gone. Do not stop any other session.

Command details are the vendor's: read `colab <command> --help` rather than
memorizing flags. Re-check when the CLI moves past 0.7.4. This skill captures
only the boundaries above.

## Real path, probed GPU, external deadline

Use the commands that already exist. Do not add a transfer helper.

`colab exec -f` reads the local file and runs that text as a notebook cell.
There is no `__file__`, and the source is not a file on the VM. `colab run`
sets `__name__` and `sys.argv` and also does not set `__file__`. That is enough
when cell semantics are enough. When the job needs a real path, create the
parent, `colab upload`, then `subprocess` that path. `colab upload` has no
mkdir flag. A missing parent fails the contents PUT (seen as HTTP 500; a 404
becomes `FileNotFoundError`). Do not reimplement `upload` or `exec`.

`colab new` has no deadline. A managed session meters until `colab stop -s` on
the name you created. A stop inside the cell that is executing never runs if
that cell hangs, and `colab exec --timeout` only drops the client wait. The VM
stays assigned. `colab stop` with a missing local name prints "not found" and
returns success; that is not a release. Confirm the name is absent from
`colab sessions`. That listing includes every assignment on the account. Stop
only the session you created. Do not stop another session, including a `[?]`
row, even when HTTP 412 says to free a slot.

Two obligations, not one snippet:

1. **Normal path.** Use a `finally` shape: collect, then `colab stop -s` the
   name you created, including when `exec` or `run` times out or returns
   non-zero. A timeout is not a completed job. `colab run` without `--keep`
   attempts teardown after a timeout; that attempt is still not a successful
   artifact. If the caller is killed from outside, that teardown may not run.
   The leak is not a finished job, and it is not a reason to stop someone
   else's session.
2. **External deadline.** If the caller can die before that `finally` runs, the
   deadline is a separate process, started outside this process group, whose
   only stop target is the name this job created. Leave it armed until
   `colab stop -s` of that name has succeeded. Cancelling it first, then
   failing stop, leaks the VM. Killing the parent bash of `sleep N; colab stop`
   does not reliably kill `sleep`, so that construction is neither a deadline
   nor a cancellation. Do not discard the deadline's stderr. Keep a one-line
   failure note: command, exit status, HTTP status. Redact any runtime proxy
   URL or `colab-runtime-proxy-token` before the note leaves the terminal.

After allocation, print and keep the GPU name. `colab status` repeats the
request and also prints a runtime endpoint; record the probed name only, not
the endpoint or any URL. On 0.7.4 an unrecognized `--gpu` value is sent as
A100, not rejected. HTTP 400 with the CLI text "quota or entitlement" is not
capacity. Retrying it does not fix an entitlement rejection; confirm the
account with `colab whoami` instead of treating the 400 as capacity. The CLI
does not expose a reason that proves every quota will never clear, so do not
claim that, and do not loop on the 400. `Service Unavailable` is capacity:
retry once, then fall back. A fallback must record the probed GPU, not the
flag you asked for.

```bash
# Synthetic names. 30s is the CLI default, not a budget.
# Normal path only. name must be the session this job created.
# Do not cancel an external deadline in this snippet.
name=example
rc=0
printf '%s\n' 'import shutil,subprocess; exe=shutil.which("nvidia-smi"); print(subprocess.check_output([exe,"--query-gpu=name","--format=csv,noheader"],text=True).strip() if exe else "CPU")' \
  | colab exec -s "$name" --timeout 60 || rc=$?
printf '%s\n' 'import os; os.makedirs("/content/example", exist_ok=True)' \
  | colab exec -s "$name" --timeout 60 || rc=$?
colab upload -s "$name" ./job.py /content/example/job.py || rc=$?
if [ "$rc" -eq 0 ]; then
  printf '%s\n' 'import subprocess,sys; raise SystemExit(subprocess.call([sys.executable, "/content/example/job.py"]))' \
    | colab exec -s "$name" --timeout 3600 || rc=$?
fi
# The uploaded script writes this path. Collect before stop.
colab download -s "$name" /content/example/output.jsonl ./output.jsonl || rc=$?
# A zero exit from stop is not proof of release. Do not print session lines;
# they include endpoints. Leave stderr visible so a list failure is not lost.
if ! colab stop -s "$name"; then
  printf 'stop failed: %s\n' "$name" >&2
  rc=1
fi
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

`3600` is an example ceiling for one job, not a budget framework. If `colab exec`
or `colab run` times out, the business code did not finish.

## Acceptance (self-checkable)

- The job's artifact exists at a durable path (Drive/GCS/local) and is non-empty.
- The job note records the probed GPU name, not only the requested `--gpu` flag.
- A timeout was not reported as a completed run.
- `colab sessions` shows **no** leftover session you created.
- Published text contains no runtime proxy URL.
- If a 403 appeared, `colab whoami` was used to confirm identity/scopes rather
  than guessing.

## Known traps

- **Forgetting `colab stop`.** The single most expensive mistake: a `colab new`
  VM keeps metering units until stopped. Default to `colab run`.
- **Two G4 failures.** `Service Unavailable` is capacity (retry once, then fall
  back). HTTP 400 "quota or entitlement" is not capacity. Retrying it does not
  fix an entitlement rejection; confirm the account. Do not claim every quota
  never clears. Record the probed GPU either way.
- **`colab new` has no deadline.** The normal path is collect, then stop, in a
  `finally` shape. An external deadline stays armed until `colab stop -s` of
  the name you created succeeds. Do not cancel it first. Do not stop a session
  you did not create. A same-group sleep watchdog is not that deadline.
- **Timeout is not completion.** `exec` and `run` default `--timeout` to 30
  seconds. A timed-out cell can still be running on the VM.
- **Ephemeral disk.** Anything left in `/content` is lost when the VM is
  reclaimed. Checkpoint early.
- **`exec -f` is a cell.** No `__file__`. Remote paths inside the script must
  already exist on the VM. Missing upload parents fail with HTTP 500.
- **Error text leaks URLs.** A runtime proxy URL in an error body is a secret.
  Redact it. Do not copy `colab url` output into chat or logs either.
- **Wrong identity.** A service account has no Colab entitlement; use a user
  account. Debug 403s with `colab whoami`.
- **Unpublished rates.** Read `colab usage` for the live rate; never hard-code a
  units-per-hour figure.

## Private overlay

Workspace-specific details are intentionally **not** here. Which Google account
to use, a default accelerator, and how Colab compares to other GPU options
(owned hardware, other clouds, leased GPUs) belong in the consumer's local
`rules/skills/` overlay.
