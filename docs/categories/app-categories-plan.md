# App categories — issue #28

## Scope

Extend the existing six categories with dashboard filters, a small colored dot
and label beneath each app name, and an editable tag in app details. Preserve
the existing design and all usage/tracking/restriction behavior.

## Implementation sequence and acceptance

- [x] Share category resolution: saved app-key override, automatic name-based
  classification, then Activity.
- [x] Persist overrides through the existing settings repository; no schema or
  dependency changes. Preserve restart and portable backup/import behavior.
- [x] Add All and represented-category filters above the dashboard list. Keep
  totals, percentages, bubble contents, ranks, and restrictions unfiltered.
- [x] Add category dots/labels and a colored details tag. Entertainment is yellow.
- [x] Redesign tags as one tinted pill with category icons across list rows,
  filters, and the details tag (replaces the dots).
- [x] Add a bottom-sheet category picker with Automatic to remove an override.
  Publish changes only after a successful write; report failures and allow retry.
- [x] Reuse translated category names; localize new controls in all seven locales.
- [x] Verify today/historical filtering, cross-screen updates, failed writes,
  persistence/reset, invalid settings, backup/import, and existing regressions.

## Non-goals

Custom categories, multiple tags, cloud sync, category-wide restrictions, changes
to automatic classification, bubble recoloring, or an overall app redesign.

## Remaining

Manual visual/accessibility validation on a physical Android device, including
large text, long translated category labels, sheet scrolling and TalkBack: case 6
of the physical-device protocol in `docs/backend/backend-sync-v1-plan.md`.
NOT RUN. Automated widget and guideline checks passed; no device installation
was performed for this stage.

References: [architecture](app-categories-architecture.md),
[progress](app-categories-progress.md),
[issue #28](https://github.com/sneri12pic/FocusTrace/issues/28).
