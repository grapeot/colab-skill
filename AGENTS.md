# AGENTS.md — Colab Skill

## Project identity

Public, English, filesystem-native skill for operating Google Colab headlessly
through the official `google-colab-cli`. It wraps the vendor CLI; it does not
reimplement it. The product is the Markdown under `skills/` plus two small
helper scripts.

This repository is public. Treat every committed byte as publishable.

## Layout

```text
colab_skill/
├── AGENTS.md              # this file — project-local rules
├── README.md              # human-facing: install + usage
├── .gitignore
├── .env.example           # fake/placeholder defaults only
├── docs/
│   ├── prd.md             # goals, users, success criteria
│   ├── rfc.md             # architecture, boundaries, design decisions
│   ├── test.md            # what "verified" means
│   └── working.md         # Changelog + Lessons Learned
├── skills/
│   └── colab/
│       └── SKILL.md       # the one root skill exposed to a workspace
├── scripts/
│   └── colab_login.sh     # OAuth helper: opens the URL, feeds the code
└── tests/
    └── test_smoke.sh      # offline sanity checks
```

## Hard rules

1. This is a **public** repo. No real emails, phone numbers, API keys, internal
   hostnames, machine-specific home paths, or private vault references — in any
   file, including tests and fixtures. Use `example.com` / `alice@example.com`
   style placeholders.
2. Expose exactly **one** root skill (`skills/colab/SKILL.md`) to any workspace
   index. Focused details live in that file or beside it; do not add more
   top-level skills without collapsing them into the router.
3. Do not vendor or fork the Colab CLI. Call the installed `colab` binary. When
   it changes, re-verify against `colab <command> --help` and update the skill.
4. Authentication is out of scope for this repo: it lives in the CLI's own token
   cache (`~/.config/colab-cli/token.json`). Never commit a token, a client
   secret, or an OAuth code.
5. Update `docs/working.md` (Changelog + Lessons Learned) after any substantive
   change.
6. Commit only when the user explicitly asks. Prefer small, reversible commits.
7. Do not add credentials-handling, network calls, or scheduling to the helper
   scripts beyond what `scripts/colab_login.sh` already does.

## Environment

- Shell: bash/zsh, macOS or Linux. The Colab CLI does not support Windows.
- Runtime dep: `google-colab-cli` (installed via `uv tool install
  google-colab-cli` or `pip install google-colab-cli`).
- No Python package of our own; `scripts/` and `tests/` are pure shell.

## Verification

```bash
bash tests/test_smoke.sh
```

A change is complete only when the smoke test passes and the README's install
path still works from a clean shell.
