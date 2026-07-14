# Contributing to PimPoPom

PimPoPom is currently a private native iOS project following the local technical-alpha track.

## Workflow

1. Read `AGENTS.md`, run `git status --short`, and select one concrete outcome.
2. Branch from current `main` as `codex/<short-task>` or another reviewed feature branch.
3. Keep rules in the pure core and platform effects behind adapters.
4. Add tests with every behavior change and update durable documentation when a contract changes.
5. Run the repository check script and `git diff --check` before review.
6. Open a focused pull request; do not mix generated assets, backend changes, and unrelated cleanup without a clear reason.

## Commit and review expectations

- Use imperative, outcome-oriented commit subjects.
- Explain migrations, compatibility risks, privacy changes, monetization effects, and physical-device gaps in the pull request.
- Never commit secrets or private signing material.
- Generated assets must include reproducible source information or an explicit retained editable/lossless master and rights record.
- A proposed decision does not become accepted merely because code exists. Update `docs/DECISIONS.md` only after review accepts it.

## Definition of done

Code, deterministic tests, integration coverage proportional to risk, documentation, accessibility, privacy inventory, device validation, and a clear handoff are all part of completion.
