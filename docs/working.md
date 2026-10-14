# Working Notes — Colab Skill

## Changelog

### 2026-10-14
- Added run checks in `skills/colab/SKILL.md` from jobs that already ran. No
  measured speed, account, balance, host, session id, private path, or model
  baseline was copied. Probe `compute_cap`, Torch device capability when Torch
  is imported, and `nvcc --version` when compiling. Rebuild when the
  architecture changes. An `sm_80` binary is not an `sm_120` binary. An `nvcc`
  version or one handwritten assembly failure does not prove NVFP4 unsupported;
  check the library or backend. Size disk peak as download + pack/unpack +
  scratch, and do not keep a source checkout plus a Hugging Face cache of the
  same weights. To free space, back up results, then delete only this run's
  remote model files that can be downloaded again. Do not touch user data,
  local files, or another session's files.
  Query `memory.total`; MIG and a product page are not the allocation. Cite
  `prompt_tokens` and `cache_n`, or equivalent response fields, not a context
  flag. Keep decode time separate from aggregate wall time. Warmup and
  prompt-cache hits are not the measured run. Two generated tokens are not
  throughput. App context must cover actual input + output. A max-context
  change is a separate config and repro. Download request, response, tool
  calls, test stdout, and pins before stop. Raw must not contain a proxy URL
  or token. A loopback process for one measurement is not hosting. Do not open
  a tunnel. A flag or env
  var must exist in the pinned source; an unknown env var can be silently
  ignored. Prove effect. Output quality and an approximation that skips experts
  are separate. The existing `__file__` rule was not repeated.
- Corrected the HTTP 400 reading in `skills/colab/SKILL.md`, `README.md`, and
  this file. CLI 0.7.4 `session.new` (same branch in `colab run`) maps any
  accelerator 400 to one "quota or entitlement" message and does not read the
  response body, so that text is a guess. The same 400 can be parameter or
  shape. Do not treat every 400 as a permission denial, and do not treat it as
  proof the failure is not capacity. Classify 403, 400, and 503 as HTTP
  classes, not proven causes. A 503 capacity retry is a suggestion and does
  not guarantee allocation. For G4, omitting `--high-mem` is one
  single-variable control. It does not prove the default shape is available
  and does not guarantee allocation. The default shape can already have a large
  host RAM. `HIGH_RAM` is a requested shape, not a required performance switch.
  Cited https://support.google.com/googleone/answer/16286513 for premium GPU,
  18+, family plan manager, no trial, and listed regions. That page's Colab
  sentence is general for Ultra members. Do not say only the 20x plan
  qualifies, and do not require an upgrade from 5x to 20x. A 2026-08-10
  comment on https://github.com/googlecolab/colabtools/issues/6076 said G4 was
  available to Colab Pro+ at that time; do not read the Ultra page as excluding
  Pro+. That note is dated and is not an allocation guarantee. No runtime was
  allocated for this correction.
- Documented live CLI 0.7.4 behavior in `skills/colab/SKILL.md`: missing upload
  parent, `exec -f` / `run` file semantics, assignment HTTP classes, no deadline
  on `colab new`, and runtime proxy URLs in error text. No new runtime was
  allocated to write this; flags were checked with `colab <command> --help`.
- Pointed `README.md` at that section. Extended the offline phrase checks.
- Corrected the managed-session example. A same-group `sleep` under `bash` is
  not an external deadline: killing that bash does not reliably kill `sleep`,
  and cancelling the deadline before a successful `colab stop -s` drops the
  fallback. The normal path is collect, then stop. Failure notes keep exit
  status and HTTP status, and redact proxy URLs.

### 2026-10-12
- Scaffolded the project: `docs/`, `skills/colab/`, `scripts/`, `tests/`.
- Wrote `docs/prd.md`, `docs/rfc.md`, `docs/test.md`.
- Wrote the root skill `skills/colab/SKILL.md`.
- Added `scripts/colab_login.sh` (opens the OAuth URL, feeds the pasted code).
- Added `tests/test_smoke.sh` (offline structure + hygiene checks).

## Lessons Learned

Real failures and constraints from building this, kept so the next agent does
not repeat them.

- **Login UX: open the URL, don't make the user copy it.** The official CLI
  prints an OAuth URL and then blocks on `input()` for the pasted code. An
  earlier flow showed the URL as plain text and made the user copy it manually.
  `scripts/colab_login.sh` extracts the URL and calls `open` / `xdg-open` first.
  The paste-back step cannot be automated (it is the point of the consent flow)
  and must stay interactive.
- **`colab new` does not auto-release, and it has no deadline.** Verified on CLI
  0.7.4: `colab new --help` has no timeout or deadline flag. A session created
  with `colab new` stays alive — and meters compute units — until `colab stop -s`
  on the name you created. A stop inside the cell that is currently
  executing never runs if that cell hangs, and `colab exec --timeout` only
  abandons the client wait. The normal path is a `finally` shape: download the
  artifact, then stop that name, including after a timeout. A timeout is not a
  successful job. If the caller can die before that `finally` runs, the
  external deadline is a separate process outside this process group. Leave it
  armed until `colab stop -s` of that name succeeds. Cancelling it first, then
  failing stop, leaks the VM. Killing the parent bash of `sleep N; colab stop`
  does not reliably kill `sleep`, so that pattern is not a deadline. Do not
  discard the deadline's stderr. Keep command, exit status, and HTTP status;
  redact any runtime proxy URL before the note leaves the terminal.
  `colab sessions` lists every assignment on the account. Stop only the session
  this job created. Do not stop another session, including a `[?]` row, to
  satisfy a 412 "free a slot" message. `colab run` without `--keep` attempts
  teardown after a timeout, but a timeout is not a successful job. Prefer
  `colab run` for one-shot jobs that do not need a real file. This is the
  single most expensive mistake an agent can make here.
- **`/content` is ephemeral.** The VM is deleted when idle or at max lifetime;
  anything not on Drive/GCS/local is gone. Long jobs must checkpoint.
- **Premium GPU is a published benefit, not a 400 diagnosis.** Google's Ultra
  benefits page states premium GPU access for Ultra members, with Colab limited
  to 18+, the family plan manager, non-trial memberships, and the listed
  regions: https://support.google.com/googleone/answer/16286513 . That Colab
  sentence is general. It does not say only the 20x plan qualifies. Do not
  require an upgrade from 5x to 20x to request `G4`. Do not invent a narrower gate than that page states.
  Do not read it as excluding Colab Pro+: a 2026-08-10 comment on
  https://github.com/googlecolab/colabtools/issues/6076 said G4 was available
  to Colab Pro+ at that time. That note is dated and is not an allocation
  guarantee.
- **`G4` shape and HTTP class are different facts.** Prefer omitting
  `--high-mem` for `G4`. The default shape can already have a large host RAM.
  `HIGH_RAM` is the shape the flag requests, not a required performance switch.
  On CLI 0.7.4 the flag is ignored only for L4 and the TPU variants; for `G4`
  it is sent. If `G4` plus `--high-mem` returns 400, dropping the flag is one
  single-variable control. It does not prove the default shape is available,
  does not guarantee allocation, and does not diagnose a plan with no
  entitlement. `session.new` (and the same branch in `colab run`) turns any
  accelerator 400 into one message and does not read the response body. "quota
  or entitlement" is that guess. The same 400 can be parameter or shape.
  Classify the status: 403 and 503 / `Service Unavailable` are HTTP classes,
  not proven causes. `colab whoami` after a 403 is a check, not a diagnosis. A
  503 capacity retry (once, then fall back) is a suggestion and does not
  guarantee allocation. 400 has an unknown cause. Do not say every 400 is a
  permission denial, and do not say a 400 proves the failure is not capacity.
  Do not loop on the unchanged request. Record the GPU
  a probe actually printed (`nvidia-smi --query-gpu=name`), not the `--gpu`
  flag. On 0.7.4 an unrecognized `--gpu` value is sent as A100 rather than
  rejected, which is another reason the probe is mandatory. Do not copy the
  runtime endpoint from `colab status` into that note.
- **`colab exec -f` reads the local file and executes that source as a notebook
  cell.** It does not set `__file__` and does not place a file on the VM. Skip
  upload only when cell semantics are enough. When the code needs a real path,
  `colab exec` a `makedirs` of the parent, then `colab upload`, then `colab exec`
  a `subprocess` of that path. Example paths: `/content/example`. `colab upload`
  has no mkdir flag; a missing remote parent fails the contents PUT (seen as
  HTTP 500). `colab run` sets `__name__` and `sys.argv` but also does not set
  `__file__`. `upload` and `exec` are already the write path; do not reimplement
  the CLI.
- **Error text can carry a runtime proxy URL with an auth token.** That includes
  HTTP error strings and assignment error bodies. Redact the URL before it
  reaches chat, issues, public logs, or this repo. Do not copy `colab url`
  output either. The token cache rule is not enough on its own.
- **Auth identity matters.** The CLI authenticates as a user account; a service
  account has no Colab entitlement. A 403 is not proof of that. `colab whoami`
  is a check, not a diagnosis.
- **Compute-unit rates are unpublished.** `colab usage` shows the live rate and
  balance; do not hard-code a rate in docs or scripts.
- **A granted accelerator is not a matching binary.** Probe `compute_cap` and,
  when the job uses them, Torch's device capability and `nvcc --version`.
  Rebuild when the architecture changes. Do not run an `sm_80` binary on
  `sm_120`. A missing or old `nvcc`, or one handwritten assembly failure, does
  not prove NVFP4 unsupported. Check the library or backend the job will call.
- **Size the disk peak, and query memory.** Download, pack or unpack, and
  scratch can all be live at once. A source checkout plus a Hugging Face cache
  of the same weights is two copies. If space is short, back up results, then
  delete this run's remote model files that can be downloaded again. Do not
  delete user data, local files, or another session's files. MIG and a
  product-page capacity are not the allocation; use `memory.total`.
- **Measure the fields the server counted.** `prompt_tokens` and `cache_n`, or
  equivalent response fields, are the input record. A context flag is not.
  Decode time and aggregate wall time are different. Warmup and prompt-cache
  hits are not the measured run.
  Two generated tokens are not throughput. App context must be >= actual input
  + output. A max-context change gets its own config and repro note.
- **Save the run, then stop.** Download the full request, response, tool calls,
  test stdout, and pins before `colab stop`. Raw must not contain a runtime
  proxy URL or token. A loopback API for one bounded measurement is not
  standing hosting. Do not open a tunnel.
- **A switch is real only in the pin you ran.** Look up the flag or env var in
  that source. An unknown env var can be silently ignored. Prove effect from a
  log or behavior. Output quality and an approximation that skips experts are
  separate. If part of the model was disabled for speed, do not label the run
  as that model.
