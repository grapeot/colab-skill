# Working Notes — Colab Skill

## Changelog

### 2026-10-14
- Documented live CLI 0.7.4 behavior in `skills/colab/SKILL.md`: missing upload
  parent, `exec -f` / `run` file semantics, quota versus capacity, no deadline on
  `colab new`, and runtime proxy URLs in error text. No new runtime was allocated
  to write this; flags were checked with `colab <command> --help`.
- Pointed `README.md` at that section. Extended the offline phrase checks.
- Corrected the managed-session example. A same-group `sleep` under `bash` is
  not an external deadline: killing that bash does not reliably kill `sleep`,
  and cancelling the deadline before a successful `colab stop -s` drops the
  fallback. The normal path is collect, then stop. Failure notes keep exit
  status and HTTP status, and redact proxy URLs. HTTP 400 "quota or
  entitlement" is not capacity; retry does not fix entitlement. Confirm the
  account. Do not claim every quota never clears.

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
- **The 96 GB card is tier-gated.** `G4` is a Premium GPU (Google AI Ultra, or
  Colab Pro+). Cheaper tiers get priority access to T4/L4/A100, not `G4`. The
  vendor's marketing copy is ambiguous; the Help Center page and blog tie
  Premium GPU to Ultra.
- **`G4` availability is normal to fail, and the two failures differ.** Capacity
  comes back as `Service Unavailable`; retry once, then fall back. HTTP 400
  with the CLI text "quota or entitlement" is not that. Retrying it does not
  fix an entitlement rejection. Confirm the account with `colab whoami` rather
  than treating the 400 as capacity. The CLI does not expose a reason that
  proves every quota will never clear, so do not claim that, and do not loop
  on the 400. Either way, record the GPU a probe actually printed
  (`nvidia-smi --query-gpu=name`), not the `--gpu` flag. On 0.7.4 an
  unrecognized `--gpu` value is sent as A100 rather than rejected, which is
  another reason the probe is mandatory. Do not copy the runtime endpoint from
  `colab status` into that note.
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
  account has no Colab entitlement. Use `colab whoami` to confirm identity and
  scopes before blaming a 403 on the code.
- **Compute-unit rates are unpublished.** `colab usage` shows the live rate and
  balance; do not hard-code a rate in docs or scripts.
