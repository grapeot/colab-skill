# Working Notes — Colab Skill

## Changelog

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
- **`colab new` does not auto-release.** A session created with `colab new` stays
  alive — and meters compute units — until `colab stop`. `colab run` self-releases
  on completion. Prefer `colab run` for one-shot jobs. This is the single most
  expensive mistake an agent can make here.
- **`/content` is ephemeral.** The VM is deleted when idle or at max lifetime;
  anything not on Drive/GCS/local is gone. Long jobs must checkpoint.
- **The 96 GB card is tier-gated.** `G4` is a Premium GPU (Google AI Ultra, or
  Colab Pro+). Cheaper tiers get priority access to T4/L4/A100, not `G4`. The
  vendor's marketing copy is ambiguous; the Help Center page and blog tie
  Premium GPU to Ultra.
- **`G4` availability is normal to fail.** It is frequently greyed out and the
  CLI can return `Service Unavailable`. Treat "unavailable" as recoverable, not
  as a bug to retry in a tight loop.
- **`colab exec -f file.py` transmits the file's content**, so you do not need to
  `colab upload` before executing. But remote paths referenced *inside* the
  script (e.g. `/proc/meminfo`, datasets) still must exist on the VM.
- **Auth identity matters.** The CLI authenticates as a user account; a service
  account has no Colab entitlement. Use `colab whoami` to confirm identity and
  scopes before blaming a 403 on the code.
- **Compute-unit rates are unpublished.** `colab usage` shows the live rate and
  balance; do not hard-code a rate in docs or scripts.
