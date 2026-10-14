# Test Plan — Colab Skill

## What "verified" means

This repo has no business logic of its own, so tests are mostly about the two
things it *does* own: the helper script and the repo's public hygiene.

### Offline (default, no network, no Colab account)

Run:

```bash
bash tests/test_smoke.sh
```

It checks:

1. Every file the skill promises exists (`skills/colab/SKILL.md`, `README.md`,
   `AGENTS.md`, `.env.example`, the login script).
2. `scripts/colab_login.sh` passes `bash -n` (syntax) and is executable.
3. The root skill contains required phrases. Fixed-string grep uses `-e` to
   accept patterns starting with `--` on GNU and BSD grep. Phrases: stop-the-VM, ephemeral
   disk, eligibility, no-hosting, `Service Unavailable`, unknown cause, response
   body unread, `--high-mem`, single-variable, `HIGH_RAM` not a required switch,
   the Ultra benefits page, 5x, dated colabtools 6076, no allocation guarantee,
   503 not a proven capacity cause, HTTP 500, `__file__`, external deadline,
   watchdog (rejected as a same-group sleep pattern), runtime proxy, and
   `not complete`. Documented `bash` fences must pass `bash -n`. These checks
   verify documented phrases and bash syntax only. They are not runtime
   behavior proof. They do not add a runner or a framework.
4. Public-hygiene scan: no real email addresses, no vault (password-manager)
   references, no private key blocks, no secrets accidentally committed, no
   absolute home paths other than the documented `~/.config/colab-cli/` default.

### Opt-in live check (requires a logged-in account, spends credits)

Not part of default CI. When a user explicitly asks to prove the toolchain:

```bash
colab new -s example
echo 'print(6*7)' | colab exec -s example --timeout 60
colab usage
colab stop -s example
```

Pass criteria: `colab exec` prints `42` and exits 0. A timeout or any other
non-zero status is not a pass. After stop, `colab sessions` no longer lists
`example`. Do not stop any other session. This is a *manual* acceptance step,
not an automated test, because it touches a real account and real credits.

### Manual review

- Read `skills/colab/SKILL.md` and confirm an agent with no prior context can
  decide: which accelerator to ask for, how to move data, and where the artifacts
  must end up.
- Confirm `README.md`'s install path needs no private information.
