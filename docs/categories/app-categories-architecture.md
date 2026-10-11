# App categories — architecture

## Domain and storage

Reuse `UsageCategory` in `usage_item.dart`: Entertainment, Productivity, Web,
Communication, System, Activity. `resolveUsageCategory` first checks overrides
by `AppUsageSummary.appKey`, then calls the existing app-name classifier, whose
fallback is Activity. Android app keys are package names; desktop keys retain
the existing process-name/app-name fallback. Categories are current app metadata
across dates, not fields written into daily usage records or sessions.

`SettingsRepository` reads/writes a JSON object under the SQLite settings key
`app_category_overrides`, e.g. `{"com.spotify.music":"entertainment"}`. Values
are stable enum names, never translated labels or numeric indexes. Missing,
malformed, and unknown entries fall back to automatic classification. Automatic
removes the app's map entry. No schema migration or new dependency is needed.

Existing portable export/import includes this settings row. Import retains its
existing row-replacement semantics: an imported category map replaces the local
map; a backup without the key leaves the local map intact. Clear-local-data
removes it with other settings. There is no cloud category sync.

## State and UI

`AppCategoriesViewModel`, provided at the shared presentation scope, loads the
map and publishes overrides only after persistence succeeds. Failed writes
retain the previous saved map. A write in flight rejects another save, avoiding
map overwrite races. Loading failures leave automatic labels visible and provide
a retry in details; editing is disabled until the map is available. Settings UI
invalidates category state after import or clear so screens reload durable data.

Dashboard filters live in `UsageBubbleViewModel` presentation state. All is the
default; only categories represented in the current summaries are offered, in
enum order. If the chosen category is absent, the displayed filter is All.
Filtering changes only the `SummaryTile` list. Bubble items use every original
summary with the shared category resolver; chart layout, colors, totals,
percentages, ranks, analytics, tracking, and restrictions remain unchanged.

`app_category_widgets.dart` owns the shared palette, per-category icons, the
`CategoryPill` tag (tinted stadium pill: icon plus name; compact in list rows,
full size with an edit icon and a 48dp touch target on the details screen),
 and scrollable category picker. Entertainment is yellow
(`#FFD166`); Productivity purple, Web cyan, Communication green, System gray,
Activity peach. Colors are accompanied by localized text. The details tag opens
radio choices plus Automatic and an explicit Save category button. A failed
save keeps the picker open with localized error text and retry capability.

All additions reuse existing Material controls, theme, typography, and spacing.
Navigation, headers, cards, charts, and backgrounds are not redesigned.
