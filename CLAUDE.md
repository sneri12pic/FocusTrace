# FocusTrace — Claude Code Instructions

FocusTrace is a local-first digital wellbeing app: Flutter UI, native
Android/Kotlin tracking and blocking, with a Java Spring Boot backend being
introduced for optional cloud sync.

**Read `AGENTS.md` first.** It holds the repository working agreement shared with
Codex: source-of-truth rules, inspect-before-modify, preserving other agents'
work, the stage plan/architecture/progress document contract, verification, and
the handoff standard. This file holds only what is Claude-specific or
project-critical, and does not repeat it.

---

## Product invariants

FocusTrace must keep working fully offline for usage tracking, local
persistence, restriction enforcement, app blocking, scheduled restrictions, and
normal UI.

Cloud functionality must never be on the critical path for tracking,
enforcement, or blocking. An unreachable, misconfigured, or disabled backend
must not degrade any of it.

Preserve existing working behaviour unless the task explicitly requires changing
it.

---

## Backend

Fixed for the backend-sync stage. Do not revisit:

Java 21 · Spring Boot · PostgreSQL · Spring Data JPA · Spring Security · Flyway ·
Gradle Kotlin DSL · JUnit 5 · Testcontainers.

The backend lives under `server/`.

Do not substitute FastAPI, Flask, Django, Dart Shelf, Node/Express, Supabase
Edge Functions, another BaaS, or microservices. Do not resurrect abandoned
backend experiments because remnants survive in Git history or ignored build
directories.

Before any backend-sync work, read:

```text
docs/backend/backend-sync-v1-plan.md          scope, sequence, acceptance criteria
docs/backend/backend-sync-architecture.md     decisions, schema, API contract, sync semantics
docs/backend/backend-sync-v1-progress.md      current state
```

Then inspect the actual implementation — documentation may have gone stale.

The backend augments the app; it never becomes the runtime source required for
restriction enforcement. Sync normalized domain data, not raw UsageStats events.
Do not sync window-title or session-level data unless an explicit future
requirement changes that decision. Build only what the current stage requires.

---

## Engineering style

Prefer simple architecture, explicit data models, clear state ownership,
database constraints, transactional correctness, DTOs at REST boundaries,
integration tests at important boundaries, small cohesive changes, and existing
repository conventions.

Avoid unnecessary abstraction, speculative frameworks, single-implementation
interfaces, excessive wrappers, duplicated domain models without a boundary
reason, and portfolio-driven overengineering.

Never expose JPA entities through REST.

Tests verify the implementation; they do not define it. Never hard-code
behaviour merely to satisfy a test.

---

## Skills

Canonical reusable skills live at:

```text
.agents/skills/<skill>/SKILL.md
```

Before substantial implementation, list what is actually there and read the
`SKILL.md` of any skill whose documented scope matches the task. Read the real
file — never reproduce a skill's procedure from memory, and never claim a skill
was loaded when it was not.

A loaded skill's procedural guidance applies on top of this file and `AGENTS.md`,
not instead of them. If a skill conflicts with a documented FocusTrace
architectural decision, report the conflict rather than overriding the
architecture silently.

`caveman` is a **response-compression style mode** (terse output, triggered by
`/caveman` or "be brief"). It is not engineering or architecture guidance. Do not
reinterpret it as such.

---

## Git

Backend-sync work belongs on `feature/backend-sync-v1`. If backend work is
requested from another branch, report the mismatch before making substantial
changes. Do not silently switch branches when the working tree holds changes
that could be lost or mixed.

- Do not commit unless explicitly instructed.
- Do not push unless explicitly instructed.
- Do not rewrite published history. Do not force-push.
- Do not modify closed-test reliability work unless the task genuinely depends
  on it or a real regression is found.

---

## Environment

Do not modify `~/.claude/settings.json`, global Claude Code or Codex
configuration, shell configuration, IDE configuration, or machine-wide tooling
unless explicitly instructed. Do not modify another agent's configuration to
solve a project problem.

If an operation is blocked by permissions, report the minimal manual command
needed rather than working around it by changing project files.

---

## Dependencies

Before adding one: check whether the repository already solves the problem, then
whether the framework or platform already provides it, then justify the
dependency. Do not replace working technology because an alternative is more
familiar, and do not add a framework to avoid understanding existing code.
