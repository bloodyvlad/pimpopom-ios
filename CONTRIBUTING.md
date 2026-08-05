# Contributing to PimPoPom

1. Read `AGENTS.md`, confirm the PimPoPom Git top level and clean/owned status, and
   choose one concrete outcome.
2. Branch from current `main` as `codex/<task>` or use the reviewed branch name.
3. Keep rules in `PimPoPomCore`, platform effects in services/gameplay, and backend
   implementation in its separate repository.
4. Add focused tests for behavior and update the current contract when behavior,
   API, privacy, economy, or release truth changes.
5. Run `Scripts/check.sh` and `git diff --check`; record physical-device gaps.
6. Submit a focused review. Do not mix unrelated cleanup, assets, backend changes,
   credentials, or deployment.

Use imperative commit subjects. Generated assets require source/tool/licence,
prompt or editable/lossless master, hashes, and rollback information. Completion
includes code, tests proportional to risk, accessibility/privacy review, accurate
documentation, and a clear handoff—not merely a compiling change.
