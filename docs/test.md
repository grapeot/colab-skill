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
3. The root skill declares the four load-bearing boundaries (stop-the-VM,
   ephemeral disk, eligibility, no-hosting) — a grep for the required phrases.
4. Public-hygiene scan: no real email addresses, no vault (password-manager)
   references, no private key blocks, no secrets accidentally committed, no
   absolute home paths other than the documented `~/.config/colab-cli/` default.

### Opt-in live check (requires a logged-in account, spends credits)

Not part of default CI. When a user explicitly asks to prove the toolchain:

```bash
colab new                      # CPU runtime is cheapest
echo 'print(6*7)' | colab exec
colab usage
colab stop
```

Pass criteria: `colab exec` prints `42`; `colab status`/`colab sessions` shows no
leftover session after `colab stop`. This is a *manual* acceptance step, not an
automated test, because it touches a real account and real credits.

### Manual review

- Read `skills/colab/SKILL.md` and confirm an agent with no prior context can
  decide: which accelerator to ask for, how to move data, and where the artifacts
  must end up.
- Confirm `README.md`'s install path needs no private information.
