# PRD — Colab Skill

## Problem

Google Colab can hand an agent a large-VRAM GPU (up to a full 96 GB RTX PRO
6000 as `G4`) by the hour, headlessly, with no cluster setup. For batch data
generation and fine-tuning this is attractive. But the failure modes are
non-obvious and cost real money or lost work:

- People assume the cheap subscription unlocks the 96 GB card. It does not.
- People start a VM and forget to stop it, burning hourly credits.
- People treat the ephemeral `/content` disk as durable storage.
- People try to build a standing service on a runtime whose terms forbid it.

An agent that "just runs a Colab job" without these boundaries will waste
credits, lose artifacts, or violate terms.

## Users

- **Primary**: a coding agent asked to run a job on a Colab GPU (data
  generation, fine-tuning, evaluation, a one-off heavy script).
- **Secondary**: a human who automates Colab from a terminal.

## Goals

1. Give an agent a reliable, headless way to run a job on a Colab accelerator
   and collect its artifacts.
2. Encode the eligibility, cost, and terms boundaries so the agent does not
   mistake Colab for a general-purpose cloud GPU or a persistent server.
3. Make first-time authentication a single guided step that does not require the
   user to manually copy a URL.

## Non-goals

- Not a Colab CLI reimplementation; the official `google-colab-cli` is the
  engine.
- Not a cluster/scale-out tool. Colab is one VM per session.
- Not a hosting tool. Standing services are out of scope and against the terms.
- Not a credentials store. Auth lives in the CLI's own token cache.
- Not a provider-selection engine. Whether Colab beats a rented GPU is a
  workspace-level decision kept in a local overlay.

## Success criteria

A change to this repo is done when:

1. `bash tests/test_smoke.sh` passes.
2. A fresh clone, following only `README.md`, can install the CLI, log in with
   `scripts/colab_login.sh`, run `colab run --gpu T4 hello.py`, and see the
   output — without any browser copy-paste of the URL.
3. No file in the repo contains a real email, phone number, API key, internal
   hostname, or machine-specific path.
4. `skills/colab/SKILL.md` states, in an agent-checkable form, the stop-the-VM
   rule, the ephemeral-disk rule, the eligibility rule, and the no-hosting rule.

## Open questions

- Exact compute-unit rate per accelerator is not published by Google and drifts;
  the skill points at `colab usage` rather than hard-coding a number.
- `G4` availability is a live-capacity property; the skill must treat
  "unavailable" as a normal, recoverable outcome rather than an error to retry
  blindly.
