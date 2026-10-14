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
  on Colab. This is against the terms and the runtime will be reclaimed. A
  loopback process for one measurement in this session is not hosting. Do not
  open a tunnel, and do not leave that process running after you
  download.
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

- **Eligibility.** `G4` (RTX PRO 6000, 96 GB) is a **Premium GPU**. Google's
  Ultra benefits page states premium GPU access for Google AI Ultra members,
  and states the Colab constraints in that same section: 18 or older, Google
  One family plan manager, not a Google One trial, and only the listed regions.
  https://support.google.com/googleone/answer/16286513
  That Colab sentence is general. It does not say only the 20x plan can use a
  premium GPU. Do not require an upgrade from 5x to 20x to request `G4`. A
  different CCU allotment is not a shape switch. Do not invent a narrower gate
  than that page states. Do not read the page as saying Colab Pro+ cannot
  request `G4`: a 2026-08-10 comment on
  https://github.com/googlecolab/colabtools/issues/6076 said G4 was available
  to Colab Pro+ at that time. That note is dated, not a tier matrix, and not
  an allocation guarantee. Do not promise `G4` from either citation alone.
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
   job. `G4` when 96 GB / large-model work is required. Prefer omitting
   `--high-mem` for `G4`. The default shape can already have a large host RAM.
   `HIGH_RAM` is the shape `--high-mem` requests. It is not a required
   performance switch. Omitting the flag does not prove the default shape is
   available and does not guarantee allocation. On CLI 0.7.4 the flag is
   ignored only for L4 and the TPU variants. For `G4` it is sent.
2. **Run the job.** One-shot, when a notebook cell is enough: `colab run --gpu G4
   --timeout <seconds> script.py`. Managed: `colab new -s example --gpu G4`, then
   `colab install` / `colab exec`. Pass an explicit `--timeout`. On CLI 0.7.4 the
   default is 30 seconds, and a timeout is not a finished job.
3. **Move data.** Stream large datasets on the VM (HF, `git clone`, `wget`) or
   stage on Drive/GCS. `colab upload` and `colab exec` are already the write
   path; do not reimplement the CLI. Create the remote parent before upload.
4. **Collect the artifact** to a durable location *before* releasing. Also
   download the request, response, tool calls, test stdout, and pins you will
   cite. Raw must not contain a proxy URL or token.
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

After allocation, print and keep
`nvidia-smi --query-gpu=name,compute_cap,memory.total`. A successful
accelerator request is not that line. `colab status` repeats the request and
also prints a runtime endpoint; record the probed line only, not the endpoint
or any URL. On 0.7.4 an unrecognized `--gpu` value is sent as A100, not
rejected.

If the job imports Torch, print `torch.cuda.get_device_capability()` after
that install. If the job compiles, print `nvcc --version`. When the compute
capability changes, rebuild. Do not run an `sm_80` binary on `sm_120`.

A missing `nvcc`, an old `nvcc`, or one handwritten assembly failure does not
prove a format such as NVFP4 is unsupported. Check the library or backend you
will call, and keep what that check printed.

MIG and a product-page size are not the allocation. Use `memory.total` from
the probe. If the GPU is partitioned, the queried slice is the memory you
have.

HTTP status is a class, not a proven cause. `403` is not proof of an identity
or scope failure; `colab whoami` is a check, not a diagnosis. `503` /
`Service Unavailable` is not proof of a capacity failure. A capacity retry
(once, then fall back) is a suggestion and does not guarantee allocation.
`400` is a separate class with an unknown cause. On CLI 0.7.4, `session.new`
— and the same branch in `colab run` — turns any accelerator `400` into one
message and does not read the response body. The words "quota or entitlement"
in that message are the CLI's guess. The same `400` can be a rejected
parameter or shape. Do not say every `400` is really a permission denial, and
do not say a `400` proves the failure is not capacity.

For `G4`, prefer not to pass `--high-mem`. If `G4` plus `--high-mem` returns
`400`, dropping that flag is one single-variable control, not proof the
default shape is available and not a guarantee of allocation. A `400` on the
high-RAM shape does not diagnose that the plan has no entitlement. Do not
loop on the unchanged request. A fallback must record the probed GPU, not
the flag you asked for.

```bash
# Synthetic names. 30s is the CLI default, not a budget.
# Normal path only. name must be the session this job created.
# Do not cancel an external deadline in this snippet.
name=example
rc=0
printf '%s\n' 'import shutil,subprocess; exe=shutil.which("nvidia-smi"); print(subprocess.check_output([exe,"--query-gpu=name,compute_cap,memory.total","--format=csv,noheader"],text=True).strip() if exe else "CPU")' \
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

## Disk, measurement, and switches

Size the peak before the first large download: the download, the pack or
unpack, and scratch, occupied at once. A source checkout and a Hugging Face
cache of the same weights are two copies. Keep one unless the job needs both.

If the remote disk cannot hold that peak, back up results you cannot recompute,
then delete only this run's remote model files that you can download again. Do
not delete user data, files this run did not create, another session's files,
or files on the local machine.

Record `prompt_tokens` and `cache_n` from the response, or the server's
equivalent fields. A context-length flag is not the input length. Decode time
and aggregate wall time are different numbers; do not merge them. Warmup
and a prompt-cache hit are not the measured run. Two generated tokens are not
a throughput result.

The context value in the app config must be at least the actual input plus
the actual output. If you change max context, write a separate config and a
separate repro note. Do not treat that run as the same setup.

Download those records before `colab stop`: the full request, response, and
tool calls you will cite, test stdout, and pins (package versions, the probed
GPU line, the config that ran). Raw must not contain a runtime proxy URL or
token. Redact first, or do not download that file. Download, then stop.

Before setting a flag or env var, find that name in the pinned source this
VM is running. A newer doc or tag does not count. An unknown env var can be
silently ignored. Prove it took effect with a log line or a behavior you can
point at. Silence is not proof.

Output quality and an approximation that skips experts are separate results.
The same split applies to any cut that drops part of the model. If you turned
part of the model off to go faster, do not label the output as that model.

### Checklist

- Probed `compute_cap` and `memory.total`, not only `--gpu`.
- Binary matches that capability. Rebuilt if the architecture changed.
- Format support came from the library or backend, not from `nvcc` alone.
- Disk peak sized. No accidental second copy of the weights.
- Cited lengths are response fields such as `prompt_tokens` / `cache_n`, or equivalents, not a context flag.
- Decode time is separate from aggregate wall time. Warmup and cache hits are not the measured run. Two tokens are not throughput.
- Context config covers input + output. A max-context change is a new config.
- Request, response, tool calls, stdout, and pins downloaded. No proxy or token in raw.
- No tunnel was opened. Download, then stop.
- Each switch is in the pinned source and shows in a log or behavior.

## Acceptance (self-checkable)

- The job's artifact exists at a durable path (Drive/GCS/local) and is non-empty.
- The job note records the probed GPU name, `compute_cap`, and `memory.total`,
  not only the requested `--gpu` flag.
- If a binary was built for another compute capability, it was rebuilt. An
  `sm_80` binary was not used on `sm_120`.
- If a numeric format was called unsupported, the note shows a library or
  backend check, not only an `nvcc` version or one assembly failure.
- Disk peak was sized before the large download. A second copy of the same
  weights was not kept by accident. Any deletion was this run's re-downloadable
  remote model files, after a results backup, and not user data, local files,
  or another session's files.
- If a length or throughput is cited, it comes from response fields such as
  `prompt_tokens` and `cache_n`, or equivalent response fields, with warmup
  separate from the measured run. Decode time was not merged into aggregate
  wall time. Two generated tokens are not that number. A context flag is not
  the input length. A max-context change has its own config note.
- The files you will cite (request, response, tool calls, test stdout, pins)
  were downloaded before stop. Saved raw has no runtime proxy URL or token.
- No tunnel was opened. A loopback process was not left up after download.
- Each switch you report exists in the pinned source and shows in a log or
  behavior. If part of the model was disabled for speed, the result is not
  labeled as the unmodified model.
- A timeout was not reported as a completed run.
- `colab sessions` shows **no** leftover session you created.
- Published text contains no runtime proxy URL.
- If a 403 appeared, `colab whoami` was used as a check, not as proof of the
  cause.
- A 400 was not reported as a proven missing entitlement, and was not reported
  as proof that the failure was not capacity.

## Known traps

- **Forgetting `colab stop`.** The single most expensive mistake: a `colab new`
  VM keeps metering units until stopped. Default to `colab run`.
- **G4 shape, then HTTP class.** Prefer omitting `--high-mem` for `G4`.
  `HIGH_RAM` is a requested shape, not a required performance switch.
  Dropping the flag is a single-variable control; it does not guarantee
  allocation. `400` has an unknown cause: on CLI 0.7.4 the accelerator 400
  text does not read the response body. `403` and `503` / `Service
  Unavailable` are HTTP classes, not proven causes. A capacity retry does
  not guarantee allocation. Record the probed GPU either way.
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
  account. A 403 is not proof of that. `colab whoami` is a check, not a
  diagnosis.
- **Unpublished rates.** Read `colab usage` for the live rate; never hard-code a
  units-per-hour figure.
- **Assigned GPU is not the binary.** Probe `compute_cap` and `memory.total`.
  Rebuild when the architecture changes. An `sm_80` binary is not an `sm_120`
  binary. `nvcc` or one assembly failure does not prove NVFP4 unsupported.
- **Disk peak, not the checkpoint size.** Count download, pack or unpack, and
  scratch together. Do not keep two copies of the same weights. To free space,
  back up results, then delete only this run's remote model files you can
  download again. Do not touch user data or the local machine. Query memory;
  do not use the product page.
- **A flag is not a measurement.** Use `prompt_tokens` and `cache_n`, or the
  server's equivalent fields. Keep decode time separate from aggregate wall
  time. Two generated tokens are not a throughput result. A max-context change
  is a new config.
- **Download the evidence, then stop.** Request, response, tool calls, stdout,
  and pins. Redact proxy URLs and tokens in raw. Loopback for one measurement
  is not hosting. Do not open a tunnel.
- **Unknown switches may be ignored.** Find the name in the pinned source. An unknown
  env var can be silently ignored. Prove effect. A run that skips experts or
  drops model work is not that model.

## Private overlay

Workspace-specific details are intentionally **not** here. Which Google account
to use, a default accelerator, and how Colab compares to other GPU options
(owned hardware, other clouds, leased GPUs) belong in the consumer's local
`rules/skills/` overlay.
