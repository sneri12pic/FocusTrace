# FocusTrace — Agent Working Agreement

Applies equally to Claude Code, Codex, and any other agent working in this
repository. Claude-specific and project-critical rules live in `CLAUDE.md`;
stage-specific engineering state lives under `docs/<area>/`.

---

## Source of truth

The repository, Git history, tests, and tracked documentation under `docs/` are
authoritative.

Conversation history is not. Never treat a previous session's summary as the
record of project state — re-derive it from the repository.

Documentation can go stale. When documentation and the implementation disagree,
inspect the implementation and correct the document.

---

## Before modifying anything

```bash
git status --short --branch
git diff
git diff --staged
git log -8 --oneline --decorate
```

Then read the stage documents for the area you are about to touch.

Do not assume repository structure, schema, branch state, API contracts, or
implementation status. Search first.

Before changing an existing subsystem: locate the implementation, inspect its
callers, dependencies, tests, and data model, understand any uncommitted changes
touching it, then design the modification.

---

## Preserve work you did not write

The working tree may contain changes from another agent or from the developer.

1. Inspect them.
2. Understand what they do.
3. Decide whether they overlap your task.
4. Preserve them unless your task explicitly requires changing them.

Never silently discard another agent's work. If existing changes conflict
materially with what you were asked to build, explain the conflict before
replacing anything.

**Never run these merely to obtain a clean working tree:**

```bash
git reset --hard
git restore .
git checkout -- .
git clean -fd
git stash
```

Code written by Claude, Codex, or the developer is treated identically. Do not
rewrite working code because a different author would have written it
differently. Review on technical merit only.

---

## Shared stage documentation

Each substantial engineering stage owns three documents under `docs/<area>/`:

| Document | Owns | Does not own |
| --- | --- | --- |
| `<stage>-plan.md` | Scope, non-goals, implementation sequence, acceptance criteria, remaining work | Design rationale |
| `<stage>-architecture.md` | Stable decisions: boundaries, data flow, API contract, persistence model, sync semantics, conflict handling, security, trade-offs | Chronological logs, schedules |
| `<stage>-progress.md` | Current implementation state, newest entry first | Design rationale |

Current example: `docs/backend/backend-sync-v1-plan.md`,
`docs/backend/backend-sync-architecture.md`,
`docs/backend/backend-sync-v1-progress.md`.

Rules:

- All agents update the **same** documents. Never create `claude-*`, `codex-*`,
  `audit-*`, or `handoff-*` variants in tracked directories.
- Never create a second permanent document describing the same architecture.
  Update the canonical one.
- Architecture documents record decisions that were **actually implemented**. Do
  not document speculative design as completed work.

The progress document is the cross-agent handoff mechanism. After substantial
implementation, append an entry:

```text
Date:
Agent:
Goal:

Completed:
Files materially changed:
Verification:          (commands run + result)
Decisions made:
Remaining:
Risks / unresolved questions:
Relevant commit:       (hash if one exists)
```

Keep entries concise.

---

## Documentation locations

- `docs/` — durable engineering knowledge: architecture, plans, testing evidence,
  performance results, contracts, investigations.
- `.local/` — temporary scratch: one-off audits, raw agent output, notes.
  Gitignored. Agent-specific material belongs here, never in `docs/`.

Keep `README.md` and `docs/**` tracked. Do not globally ignore Markdown.

---

## Scope discipline

Implement the requested task, not every adjacent improvement found on the way.

When you discover an unrelated problem: fix it only if it blocks correctness or
materially threatens the requested work. Otherwise record it in the relevant
plan or progress document.

No large opportunistic refactors during focused feature work.

---

## Verification

Run the narrowest meaningful check first, then broader relevant tests.

Distinguish **pass**, **fail**, **unavailable**, and **blocked** exactly. Never
claim verification succeeded unless the command actually completed successfully.
If something could not be run, state precisely what was and was not verified.

---

## Before finishing substantial work

1. Inspect `git status`.
2. Inspect the final diff.
3. Confirm no unrelated files were modified.
4. Run relevant verification.
5. Update the stage progress document.
6. Update the architecture document only if a decision actually changed.
7. State remaining work explicitly.

The next session — Claude, Codex, or human — must be able to reconstruct the
current state from Git, the tests, and the three stage documents alone, with no
access to any prior agent conversation. That is the handoff standard.
