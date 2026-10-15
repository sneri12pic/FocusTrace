# Earlier usage history import - architecture

## Data flow

1. `OsUsageHistory.read` (Kotlin) queries `INTERVAL_DAILY` over the last 31
   days and `INTERVAL_MONTHLY` over the last two years. Android returns only what
   it still keeps, and how much it keeps depends on the OEM. For each bucket and
   package it keeps the largest `totalTimeInForeground` (some OEMs repeat a
   package in one bucket), and drops apps with no launcher entry, like the
   precise path does.
2. The `getOsUsageHistory` method channel returns the rows, and
   `AndroidUsageDataSource` (implementing `OsUsageHistoryDataSource`) maps them
   to `OsUsageBucket`.
3. `OsUsageHistoryRepository.importOnce` upserts them into `os_usage_buckets`
   once per app run. An empty or failed import is retried on the next call.
4. The detail and calendar view models ask the repository for one app's seconds
   per day (`dailySeconds`) and per month (`monthlySeconds`).

## Persistence

`os_usage_buckets(interval, start_ms, end_ms, app_key, app_name,
duration_seconds)`, keyed by `(interval, start_ms, app_key)`. Rows are upserted
and never pruned, because a bucket Android has dropped is still the only record
of that period. The table is created with `CREATE TABLE IF NOT EXISTS` on
database open instead of a schema version bump: native recovery accepts only
schema v5, and this table is additive and written only by Flutter. It is not
part of portable backups or sync, and clear-local-data removes it.

## Merge rules

- A daily bucket belongs to the local day containing its midpoint, because
  Android's day boundaries need not match local midnight.
- A day counts as recorded when `daily_app_usage` has a row for any app that
  day, or when it is the selected day, whose live value is used. Imported values
  fill only days that are not recorded. A recorded day without a row for this
  app stays at zero.
- A month uses Android's monthly total only when it has no recorded and no
  daily-imported days. For a previous month known only that way, the
  "vs. last month" comparison is prorated.
- The comparison with yesterday uses recorded usage only.

## Platform

The repository provider is null on platforms other than Android, so other
platforms never touch the table or the channel.
