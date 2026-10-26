# Restrictions redesign — architecture

## Presentation and data

The overview reads top to bottom: permission/platform/error cards, "Your
restrictions" (count and the single Add action), "Choose apps to limit"
(`ChooseAppsSection`), "Your busiest hours" (`BusiestHoursCard`) and block
routines. "Search all apps" and Add open the same picker over every installed
app plus any app that already has a rule; the three suggestions are only a
shortcut. `restriction_insights.dart` owns period loading and aggregation
through the existing report repository. This reuses recorded snapshots and
recovered intervals without adding a database table or using cloud data.

This week means Monday through now in local time. The denominator is the number
of distinct days with recorded rows for any app, including today's partial
snapshot when present. Missing days do not become zero days. An app absent on
an otherwise recorded day contributes zero. The count is displayed. Approximate
OS history is not silently mixed into these recorded-only averages.

Hourly bars split actual intervals at local hour boundaries, clipped to the
selected period. The highest three-hour window is suggested only when it has
at least 15 minutes of recorded usage. Its most-used app is preselected. No
restriction is activated by a suggestion; it opens the editable schedule form.
No intervals means an explanatory empty state, not synthesized bars. Installed
app metadata enriches icons; unavailable metadata leaves the existing avatar
fallback. Metadata failure does not discard usage.

`RestrictionSetupForm` renders the full-height, scrollable editor with a fixed
primary action. Existing app/type rules are edited, not duplicated. Changing
type replaces the original rule and any existing destination-type rule only
after authorization. A schedule suggestion edits an existing schedule or adds a
schedule beside another type. Permission prompts follow successful creation.
The overview retains category groups, daily-limit progress and grouped routines.
Individual rules show type and value, weekdays for schedules, difficulty,
used/left time for daily limits and the current or next blocking status.
Edit, unblock and delete live in an overflow menu. While a rule blocks, Easy
offers "Unblock now", Moderate offers "Unblock after 5-minute wait" with a
confirmation that explains the wait, and Hard offers no unblock: the menu shows
"Locked until …" and delete is disabled. Native authorization still decides;
the menu only avoids offering actions that would be refused. Routines show
their apps, the shared limit, enabled/paused state and, when enabled, shared
limit progress.

The setup sheet has one header (icon, name, average, Close), a three-way type
selector, a duration control with minus/plus, "Edit duration" (hours and
minutes, 1 minute to 24 hours) and presets, the schedule times and weekdays,
and an Easy / Moderate / Hard selector with one explanation for the selected
level. Selectors and headings stack at text scale above 1.3. The fixed action
reads "Save changes" when editing an existing rule.

Theme remains `#070A10`, ColorScheme seed `#5BC0EB`, editor `#0D111A`.
No mockup data is used in production. New strings use the existing seven ARBs.

## Rule model and blocking boundaries

The existing rule JSON gains additive `difficulty` (`easy`, `moderate`, `hard`)
and `weekdays` (ISO Monday=1 through Sunday=7). Missing fields decode to Easy and
all seven days. Existing version-1 rules/version-3 configurations remain valid.
Dart and Kotlin use the same schedule semantics: weekdays identify the start
day; an overnight tail belongs to the preceding selected day. Equal start/end
times and empty weekday selections cannot be saved by the editor.

Protection applies while an individual rule actually blocks:

- Immediate block: until its absolute expiry.
- Daily limit: after today's usage reaches the limit, until local midnight.
- Schedule: during the selected occurrence, including its overnight tail.

Outside those periods rules can be changed normally. Grouped routines retain
their existing behavior; this stage adds difficulty to individual app rules.

## Difficulty and durable enforcement

Easy changes use an explicit Flutter confirmation. The existing confirmed
backup-import and clear-data actions also count as Easy confirmation.

Moderate changes start a five-minute wait after confirmation. Native
`RestrictionChangeGuard` commits a ready timestamp plus the rule and occurrence
signature to the existing Android restriction preferences. Repeated requests
do not restart the timer. Recreating the guard/process reads the same timestamp.
After the wait the user must repeat and confirm the action; nothing automatically
unblocks. A changed rule or a new day's occurrence cannot reuse the approval.

Hard changes are rejected until the current blocking period ends. The editor
requires confirmation of this consequence before saving a Hard rule.

`requestRestrictionChange` checks the native stored rule. `syncRestrictions`
independently validates all changed/removed native rules before replacing the
configuration. This protects all app edit/delete/type-change paths and also
prevents overwriting SQLite through import/reset from bypassing an active
protected rule. Daily-limit checks query current native usage rather than
trusting a possibly historical screen summary. Missing usage access fails the
check instead of assuming zero usage.

The ViewModel authorizes, sends the proposed native configuration, then writes
the local settings mirror. Errors remain visible. Reconciliation accepts ordinary
local imports/clears when native validation allows them; otherwise it restores
the native accepted rules to local settings. If a local write fails after native
acceptance, error recovery restores that accepted configuration. This is recovery
across two stores, not an atomic cross-store transaction. An interrupted Easy
change may require retry; active protected native rules remain guarded.

Cooldowns use wall-clock timestamps and remain device-local. No uninstall,
permission-tamper, system-clock-tamper, or non-Android enforcement guarantee is
made. Existing non-Android platform status remains visible.

## Block routines

A routine has one shared daily allowance (`dailyLimitMinutes`) and members.
Each member may carry an optional `limitMinutes` cap; absent means no cap, so
existing routines keep their behaviour. Persisted JSON gains only that
additive field on members; no migration is needed.

- Usage of every included member counts once toward the shared allowance.
  Caps are caps, not reserved shares of the allowance.
- A member is blocked when its own usage reaches its cap. Every included member
  is blocked when the shared allowance is used up, whatever its cap.
- Members excluded from the shared limit keep their existing meaning (their
  usage is not counted) but their own cap still applies.
- Only enabled routines with an allowance and an included member are sent to
  the native blocker. The daily reset is local midnight, as for app limits.

Native enforcement (`RestrictionConfiguration.blockReasons`) collects every
active reason for the foreground app: app daily limit, schedule, immediate
block, each routine's shared allowance and each routine's app cap, across
overlapping routines. Any one reason blocks; the block screen lists all of
them, and shows the latest end time, so lifting one restriction never looks
like it unblocks the app while another still applies. The routine details
screen shows the same reasons per app from the Dart mirror
(`appBlockReasons`). Routines still have no difficulty level; rule
confirmation, cooldown and Hard protection are unchanged.

Removing a routine's last app asks "Delete the routine?". Delete removes it;
Keep or dismissing keeps the routine with no apps. Empty routines persist,
stay visible and editable, are disabled, and are not sent to the blocker until
apps are added again.

The routine app picker (`RoutineAppPicker`) is shared by the routine editor
and "Add apps". It lists today's most-used app first and the rest
alphabetically, once each, computed once per app list; search and category
filters only hide rows, so order and selection are kept. Category chips filter
by the existing category tags; "Select all in <category>" selects or clears
that category and shows a partial state. FocusTrace itself is not offered
because the blocker never blocks it.
