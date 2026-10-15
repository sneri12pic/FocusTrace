# Earlier usage history import - plan

## Scope

Show a new user's past screen time right away, instead of empty charts, using
what Android itself still retains, and keep it clearly apart from precisely
recorded usage.

- Read Android's aggregated daily and monthly usage buckets
  (`UsageStatsManager.queryUsageStats`).
- Store them in a separate, device-local table.
- Use them only where FocusTrace has no recorded data: unrecorded days in the
  app detail charts and calendar, and whole months in the year chart and month
  stats.
- Mark every such value as approximate ("≈", faint bars, softened calendar days,
  a note under the chart, an "≈ Approximate" tag on the selected day).
- Run the import once usage access is granted during onboarding, and say how far
  back it found data.

## Non-goals

- Weekly or yearly buckets, or spreading a month's total across its days.
- Launch counts, sessions or timelines for imported days (Android keeps none).
- Cloud sync or portable backup of imported history.
- Dashboard, reports and widgets: they keep showing recorded data only.

## Acceptance

- A recorded day, including a recorded day where the app had zero use, is never
  replaced by an imported value.
- Imported values always carry an approximate marker.
- Missing access, an unsupported platform or a failed import never blocks a
  screen or affects tracking or blocking.
- Onboarding names the earliest day found, or says that nothing was found.

## Remaining

- Measure on the Samsung test phone how far back each interval type actually
  goes (onboarding now reports the earliest day).
