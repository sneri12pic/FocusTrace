// Unit tests for the pure-Foundation part of ios/FocusTraceKit.
//
// Compiled and run on macOS by the `ios-build` CI job (see
// tool/ios/run_kit_tests.sh); no Xcode project or simulator involved.
// Usage: kit-tests <path to test/fixtures/ios_restriction_configuration.json>

import Foundation

var failures = 0
var checks = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
  checks += 1
  if !condition() {
    failures += 1
    print("FAIL (line \(line)): \(message)")
  }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, line: Int = #line) {
  checks += 1
  if actual != expected {
    failures += 1
    print("FAIL (line \(line)): \(message): got \(actual), expected \(expected)")
  }
}

let utc: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  return calendar
}()

/// 2026-11-02 is a Monday.
func date(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 11) -> Date {
  utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

func freshDefaults() -> UserDefaults {
  let name = "focustrace.kit-tests.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: name)!
  defaults.removePersistentDomain(forName: name)
  return defaults
}

func jsonObject(_ text: String) -> NSObject? {
  (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? NSObject
}

// MARK: - The fixture Dart encodes (test/ios_restriction_fixture_test.dart)

let fixturePath = CommandLine.arguments.dropFirst().first ?? "test/fixtures/ios_restriction_configuration.json"
guard let fixture = try? String(contentsOfFile: fixturePath, encoding: .utf8) else {
  print("FAIL: cannot read \(fixturePath)")
  exit(1)
}

do {
  let config = RestrictionConfiguration.parse(fixture)
  expectEqual(config.rules.count, 5, "fixture rule count")
  expectEqual(config.routines.count, 2, "fixture routine count (disabled ones are not sent)")
  expectEqual(
    config.routineAppKeys.last, "ios-sel:7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "picked groups of every routine, also disabled ones")
  expect(
    config.routineAppKeys.contains("ios-sel:5d0c7a3e-1f2b-4c6d-8e9f-0a1b2c3d4e5f"),
    "a group only a paused routine uses is listed")
  let social = config.rules[0]
  expectEqual(social.type, .blockNow, "first rule type")
  expectEqual(social.untilMs, 1_793_995_200_000, "first rule until")
  expectEqual(social.selectionId, "0f8fad5b-d9cb-469f-a165-70867728950e", "selection id")
  let evenings = config.rules[1]
  expectEqual(evenings.startMinute, 1320, "schedule start")
  expectEqual(evenings.endMinute, 420, "schedule end")
  expectEqual(evenings.weekdays, [1, 2, 3, 4, 5], "weekdays")
  expectEqual(evenings.difficulty, "moderate", "difficulty")
  expectEqual(config.rules[3].limitMinutes, 45, "daily limit")
  expectEqual(config.rules[3].selectionId, nil, "android key has no selection")
  expectEqual(config.routines[0].apps.count, 2, "routine apps")
  expectEqual(config.routines[0].apps[1].limitMinutes, 15, "routine app cap")
  expectEqual(config.rules[4].limitMinutes, 30, "iOS daily limit")
  expectEqual(config.routines[1].includedApps.map(\.appName), ["Social", "Games"], "included apps")
  expectEqual(config.routines[1].cappedApps.map(\.appName), ["Games", "Evenings"], "capped apps")
  expect(config.preferredLimits.isEmpty, "develop sends no preferred limits")

  // Swift re-encodes exactly what Dart wrote, so Dart reads it back too.
  let encoded = config.encodedJSON() ?? ""
  expect(jsonObject(encoded) == jsonObject(fixture), "re-encoded JSON equals the Dart fixture\n\(encoded)")
  expectEqual(RestrictionConfiguration.parse(encoded), config, "round trip")
}

// MARK: - Lenient decoding, as RestrictionRules.kt

do {
  let json = """
    {"version":3,"rules":[
      {"appKey":"a","appName":"A","type":"blockNow","untilMs":"1793995200000"},
      {"appKey":"b","appName":"B","type":"blockNow"},
      {"appKey":"c","appName":"C","type":"schedule","startMinute":60,"endMinute":60},
      {"appKey":"d","appName":" ","type":"schedule","startMinute":60,"endMinute":90},
      {"appKey":"e","appName":"E","type":"routineBlock"},
      {"appKey":"f","appName":"F","type":"schedule","startMinute":60.0,"endMinute":1440},
      {"appKey":"g","appName":"G","type":"schedule","startMinute":60,"endMinute":90,
       "weekdays":[0,8,3,3,"x",5]},
      {"appKey":"h","appName":"H","type":"dailyLimit","limitMinutes":0},
      7
    ]}
    """
  let rules = RestrictionConfiguration.parse(json).rules
  expectEqual(rules.map(\.appKey), ["a", "g"], "only valid rules survive")
  expectEqual(rules.first?.untilMs, 1_793_995_200_000, "numeric strings are read")
  expectEqual(rules.last?.weekdays, [3, 5], "weekdays filtered and deduplicated")
  expectEqual(rules.first?.difficulty, "easy", "difficulty defaults to easy")
  expect(RestrictionConfiguration.parse("not json").isEmpty, "garbage is an empty configuration")
  expect(RestrictionConfiguration.parse(nil).isEmpty, "nil is an empty configuration")
  expect(RestrictionConfiguration.parse("[]").isEmpty, "a bare list is an empty configuration")
}

// MARK: - Time logic matches RestrictionRule.blocksAt (Dart) / isBlocked (Kotlin)

do {
  let overnight = RestrictionRule(
    appKey: "ios-sel:x", appName: "X", type: .schedule, startMinute: 22 * 60,
    endMinute: 7 * 60, weekdays: [1])  // Mondays
  expect(overnight.isBlocked(at: date(2, 23, 0), calendar: utc), "Monday 23:00 blocked")
  expect(overnight.isBlocked(at: date(3, 6, 59), calendar: utc), "Tuesday 06:59 (Monday's tail) blocked")
  expect(!overnight.isBlocked(at: date(3, 7, 0), calendar: utc), "Tuesday 07:00 free")
  expect(!overnight.isBlocked(at: date(3, 23, 0), calendar: utc), "Tuesday 23:00 free")
  expect(!overnight.isBlocked(at: date(2, 6, 0), calendar: utc), "Monday 06:00 (Sunday's tail) free")
  expectEqual(
    overnight.blockedUntil(at: date(2, 23, 0), calendar: utc), date(3, 7, 0), "ends next morning")

  let day = RestrictionRule(
    appKey: "k", appName: "K", type: .schedule, startMinute: 9 * 60, endMinute: 17 * 60,
    weekdays: [6, 7])
  expect(day.isBlocked(at: date(7, 9, 0), calendar: utc), "Saturday 09:00 blocked")
  expect(!day.isBlocked(at: date(7, 17, 0), calendar: utc), "end is exclusive")
  expect(!day.isBlocked(at: date(6, 10, 0), calendar: utc), "Friday not selected")
  expectEqual(utc.isoWeekday(of: date(8, 12, 0)), 7, "Sunday is ISO 7")
  expectEqual(utc.isoWeekday(of: date(2, 12, 0)), 1, "Monday is ISO 1")

  let block = RestrictionRule(
    appKey: "k", appName: "K", type: .blockNow, untilMs: date(2, 12, 0).epochMilliseconds)
  expect(block.isBlocked(at: date(2, 11, 59)), "block now before until")
  expect(!block.isBlocked(at: date(2, 12, 0)), "block now ends at until")
  expectEqual(block.blockedUntil(at: date(2, 11, 0)), date(2, 12, 0), "block now until")

  let limit = RestrictionRule(appKey: "k", appName: "K", type: .dailyLimit, limitMinutes: 10)
  expect(!limit.isBlocked(at: date(2, 12, 0)), "a limit never blocks without usage")
  expect(limit.isBlocked(at: date(2, 12, 0), usageSecondsToday: 600), "limit reached")
}

// MARK: - Change guard, same results as RestrictionChangeGuard.kt

do {
  let defaults = freshDefaults()
  let guardian = RestrictionChangeGuard(defaults: defaults)
  let now = date(2, 11, 0)
  func rule(_ difficulty: String) -> RestrictionRule {
    RestrictionRule(
      appKey: "ios-sel:g", appName: "G", type: .blockNow,
      untilMs: date(2, 12, 0).epochMilliseconds, difficulty: difficulty)
  }
  let expired = RestrictionRule(
    appKey: "ios-sel:g", appName: "G", type: .blockNow,
    untilMs: date(2, 10, 0).epochMilliseconds, difficulty: "hard")
  expectEqual(guardian.check(expired, now: now), "allowed", "not blocking: allowed")
  expectEqual(guardian.check(rule("easy"), now: now), "allowed", "easy: allowed")
  expectEqual(guardian.check(rule("hard"), now: now, request: true), "hard", "hard: locked")

  let moderate = rule("moderate")
  expectEqual(guardian.check(moderate, now: now), "cooldown", "moderate without request")
  expectEqual(guardian.check(moderate, now: now, request: true), "cooldown", "request starts cooldown")
  let later = now.addingTimeInterval(299)
  expectEqual(guardian.check(moderate, now: later, request: true), "cooldown", "still cooling down")
  let after = now.addingTimeInterval(300)
  expectEqual(guardian.check(moderate, now: after), "allowed", "allowed once the cooldown ends")
  var edited = moderate
  edited.untilMs = date(2, 12, 30).epochMilliseconds
  expectEqual(guardian.check(edited, now: after), "cooldown", "a different occurrence starts over")
  guardian.clear(moderate)
  expectEqual(guardian.check(moderate, now: after), "cooldown", "clear forgets the request")
}

// MARK: - Sync validation, as MainActivity.syncRestrictions

do {
  let store = RestrictionStore(defaults: freshDefaults())
  let now = date(2, 11, 0)
  let until = date(2, 12, 0).epochMilliseconds
  let hard = """
    {"version":3,"rules":[{"appKey":"ios-sel:h","appName":"H","type":"blockNow","untilMs":\(until),"difficulty":"hard"}],"routines":[]}
    """
  let easy = """
    {"version":3,"rules":[{"appKey":"ios-sel:e","appName":"E","type":"blockNow","untilMs":\(until),"difficulty":"easy"}],"routines":[]}
    """
  let empty = #"{"version":3,"rules":[],"routines":[]}"#
  expect((try? RestrictionSync.apply(json: hard, store: store, now: now)) != nil, "adding a hard rule")
  expectEqual(store.configurationJSON, hard, "stored verbatim")
  var refused = false
  do { try RestrictionSync.apply(json: empty, store: store, now: now) } catch { refused = true }
  expect(refused, "removing an active hard rule is refused")
  expectEqual(store.configurationJSON, hard, "a refused sync stores nothing")
  expectEqual(
    RestrictionSync.requestChange(appKey: "ios-sel:h", type: "blockNow", store: store, now: now),
    "hard", "requestRestrictionChange reports hard")
  expectEqual(
    RestrictionSync.requestChange(appKey: "ios-sel:none", type: "blockNow", store: store, now: now),
    "allowed", "unknown rule: allowed")
  expect(
    (try? RestrictionSync.apply(json: empty, store: store, now: date(2, 12, 0))) != nil,
    "removing it after the block ended")
  expect((try? RestrictionSync.apply(json: easy, store: store, now: now)) != nil, "adding an easy rule")
  expect((try? RestrictionSync.apply(json: empty, store: store, now: now)) != nil, "removing an easy rule")
}

// MARK: - Store

do {
  let store = RestrictionStore(defaults: freshDefaults())
  let now = date(2, 11, 0)
  store.configurationJSON = """
    {"version":3,"rules":[{"appKey":"ios-sel:kept","appName":"K","type":"blockNow","untilMs":1}]}
    """
  store.setSelectionData(Data([1]), id: "kept", now: now.addingTimeInterval(-90_000))
  store.setSelectionData(Data([2]), id: "old", now: now.addingTimeInterval(-90_000))
  store.setSelectionData(Data([3]), id: "new", now: now.addingTimeInterval(-60))
  store.removeUnreferencedSelections(now: now)
  expectEqual(store.selectionIds, ["kept", "new"], "only old unreferenced selections go")

  // A paused routine's groups arrive only in routineAppKeys and are kept.
  store.configurationJSON = """
    {"version":3,"rules":[{"appKey":"ios-sel:kept","appName":"K","type":"blockNow","untilMs":1}],
     "routines":[],"routineAppKeys":["ios-sel:paused"]}
    """
  store.setSelectionData(Data([5]), id: "paused", now: now.addingTimeInterval(-90_000))
  store.removeUnreferencedSelections(now: now)
  expectEqual(store.selectionIds, ["kept", "new", "paused"], "a paused routine's selection stays")

  store.recordBlocked(appKey: "ios-sel:kept", appName: "K", reason: "blockNow", now: now)
  store.recordBlocked(appKey: "ios-sel:kept", appName: "K", reason: "blockNow", now: now.addingTimeInterval(30))
  store.recordBlocked(appKey: "ios-sel:kept", appName: "K", reason: "blockNow", now: now.addingTimeInterval(61))
  let events = store.takeEvents()
  expectEqual(events.count, 2, "one event a minute per rule")
  expectEqual(events.first?["type"] as? String, "blocked", "event type")
  expectEqual((events.first?["occurredAtMs"] as? NSNumber)?.int64Value, now.epochMilliseconds, "event time")
  expectEqual(store.takeEvents().count, 0, "taking events empties the queue")

  // Events recorded while the app takes them are never lost.
  let racing = RestrictionStore(defaults: freshDefaults())
  let taken = NSMutableArray()
  let lock = NSLock()
  DispatchQueue.concurrentPerform(iterations: 200) { index in
    racing.recordBlocked(
      appKey: "ios-sel:\(index)", appName: "A", reason: "blockNow", now: now, minimumInterval: 0)
    if index % 10 == 0 {
      let events = racing.takeEvents()
      lock.lock()
      taken.addObjects(from: events)
      lock.unlock()
    }
  }
  taken.addObjects(from: racing.takeEvents())
  let takenIds = Set(taken.compactMap { ($0 as? [String: Any])?["id"] as? String })
  expectEqual(takenIds.count, 200, "every event recorded during takeEvents is taken once")
  expectEqual(taken.count, 200, "no event is taken twice")

  expectEqual(AppGroup.withLock("kit-tests") { 7 }, 7, "withLock returns the body's value")

  let generation = store.configurationGeneration
  store.setSelectionData(Data([4]), id: "kept", now: now)
  expect(store.configurationGeneration > generation, "an edited selection bumps the generation")
  let beforeSync = store.configurationGeneration
  _ = try? RestrictionSync.apply(json: #"{"version":3,"rules":[]}"#, store: store, now: now)
  expect(store.configurationGeneration > beforeSync, "a sync bumps the generation")

  store.recordDisplayed(ruleKeys: ["ios-sel:a#blockNow"], tokenKey: "app:x", now: now)
  expectEqual(store.displayedRuleKeys(tokenKey: "app:x"), ["ios-sel:a#blockNow"], "displayed keys")
  expectEqual(store.displayedRuleKeys(tokenKey: "app:y"), [], "nothing displayed for another token")
  store.recordDisplayed(ruleKeys: [], tokenKey: "app:x", now: now)
  expectEqual(store.displayedRuleKeys(tokenKey: "app:x"), [], "a newer display replaces the record")
  for index in 0..<5 {
    store.recordDisplayed(
      ruleKeys: ["k\(index)"], tokenKey: "app:\(index)", now: now.addingTimeInterval(Double(index)),
      limit: 3)
  }
  expectEqual(store.displayedRuleKeys(tokenKey: "app:1"), [], "oldest records are dropped")
  expectEqual(store.displayedRuleKeys(tokenKey: "app:4"), ["k4"], "newest records are kept")

  store.shieldStrings = ShieldStrings(values: ["leave": "Verlassen"])
  expectEqual(store.shieldStrings.text("leave"), "Verlassen", "strings from Flutter")
  expectEqual(store.shieldStrings.text("unblockInApp"), "Unblock in FocusTrace", "English fallback")
  let rule = RestrictionRule(appKey: "ios-sel:a", appName: "Social", type: .blockNow, untilMs: 1)
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm"
  formatter.timeZone = TimeZone(identifier: "UTC")
  expectEqual(
    ShieldStrings(values: [:]).reason(for: rule, until: date(2, 15, 0), timeFormatter: formatter),
    "Temporary block until 15:00 · Social", "shield reason line")
}

// MARK: - DeviceActivity mapping

func fitted(_ result: (start: Int, end: Int, warning: Int?)) -> [Int?] {
  [result.start, result.end, result.warning]
}

do {
  expectEqual(fitted(ScheduleMapper.fit(lo: 540, hi: 600, needsOn: true, needsOff: true)), [540, 600, nil], "long piece unchanged")
  expectEqual(fitted(ScheduleMapper.fit(lo: 600, hi: 605, needsOn: true, needsOff: true)), [600, 615, 10], "short: warning at the end")
  expectEqual(fitted(ScheduleMapper.fit(lo: 1430, hi: 1439, needsOn: true, needsOff: false)), [1424, 1439, 9], "short evening")
  expectEqual(fitted(ScheduleMapper.fit(lo: 0, hi: 5, needsOn: false, needsOff: true)), [0, 15, 10], "short morning")
  expectEqual(fitted(ScheduleMapper.fit(lo: 1430, hi: 1436, needsOn: true, needsOff: true)), [1421, 1436, 6], "short at day end")
  expectEqual(fitted(ScheduleMapper.fit(lo: 1439, hi: 1439, needsOn: true, needsOff: false)), [1424, 1439, nil], "start at 23:59")

  let now = date(2, 11, 0)
  let config = RestrictionConfiguration.parse(fixture)
  let plans = ScheduleMapper.plans(for: config, now: now, calendar: utc)
  expectEqual(
    plans.map(\.name),
    [
      "ft.blockNow.0f8fad5b-d9cb-469f-a165-70867728950e",
      "ft.blockNow.7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "ft.limit.3b241101-e2bb-4255-8caf-4136c566a962",
      "ft.routine.routine-2",
      "ft.schedule.7c9e6679-7425-40de-944b-e07fc1f90ae7.evening",
      "ft.schedule.7c9e6679-7425-40de-944b-e07fc1f90ae7.morning",
    ], "plans for the fixture: blocks, limits and routines, then schedules")
  if plans.count == 6 {
    expectEqual(plans[4].start, DateComponents(hour: 22, minute: 0), "evening start")
    expectEqual(plans[4].end, DateComponents(hour: 23, minute: 59), "evening end")
    expectEqual(plans[5].start, DateComponents(hour: 0, minute: 0), "morning start")
    expectEqual(plans[5].end, DateComponents(hour: 7, minute: 0), "morning end")
    expect(plans[4].repeats && !plans[0].repeats, "schedules repeat, blocks do not")
    expect(plans[0].events.isEmpty && plans[4].events.isEmpty, "only usage activities have events")

    let limit = plans[2]
    expectEqual(limit.start, DateComponents(hour: 0, minute: 0), "limit day start")
    expectEqual(limit.end, DateComponents(hour: 23, minute: 59), "limit day end")
    expect(limit.repeats, "limit repeats daily")
    expectEqual(
      limit.events,
      [
        ThresholdPlan(name: "warning", minutes: 25, selectionIds: ["3b241101-e2bb-4255-8caf-4136c566a962"]),
        ThresholdPlan(name: "reached", minutes: 30, selectionIds: ["3b241101-e2bb-4255-8caf-4136c566a962"]),
      ], "limit events: warning 5 minutes ahead, then the limit")
    expectEqual(limit.ruleKey, "ios-sel:3b241101-e2bb-4255-8caf-4136c566a962#dailyLimit", "limit key")

    let routine = plans[3]
    let shared = ["0f8fad5b-d9cb-469f-a165-70867728950e", "3b241101-e2bb-4255-8caf-4136c566a962"]
    expectEqual(
      routine.events,
      [
        ThresholdPlan(name: "warning", minutes: 85, selectionIds: shared),
        ThresholdPlan(name: "reached", minutes: 90, selectionIds: shared),
        ThresholdPlan(name: "cap.3b241101-e2bb-4255-8caf-4136c566a962", minutes: 20,
          selectionIds: ["3b241101-e2bb-4255-8caf-4136c566a962"]),
        ThresholdPlan(name: "cap.7c9e6679-7425-40de-944b-e07fc1f90ae7", minutes: 10,
          selectionIds: ["7c9e6679-7425-40de-944b-e07fc1f90ae7"]),
      ], "routine: one shared event over all included selections, one per cap")
  }

  let soon = RestrictionConfiguration(rules: [
    RestrictionRule(
      appKey: "ios-sel:s", appName: "S", type: .blockNow,
      untilMs: now.addingTimeInterval(300).epochMilliseconds)
  ])
  let short = ScheduleMapper.plans(for: soon, now: now, calendar: utc)
  expectEqual(short.first?.end.minute, 15, "a five-minute block is widened to 15 minutes")
  expectEqual(short.first?.warning, DateComponents(minute: 10, second: 0), "warning lands on until")
  let expired = RestrictionConfiguration(rules: [
    RestrictionRule(appKey: "ios-sel:s", appName: "S", type: .blockNow, untilMs: 1)
  ])
  expect(ScheduleMapper.plans(for: expired, now: now).isEmpty, "expired blocks are not monitored")

  let many = RestrictionConfiguration(
    rules: (0..<30).map {
      RestrictionRule(
        appKey: "ios-sel:\($0)", appName: "S", type: .schedule, startMinute: 60, endMinute: 120)
    })
  expectEqual(ScheduleMapper.plans(for: many, now: now).count, ScheduleMapper.maxActivities, "capped")
}

// MARK: - Usage thresholds (UsageEvents)

do {
  expectEqual(UsageEvents.warningMinute(limit: 30), 25, "warning 5 minutes ahead")
  expectEqual(UsageEvents.warningMinute(limit: 6), 1, "warning at 1 for a 6 minute limit")
  expectEqual(UsageEvents.warningMinute(limit: 5), 1, "short limit: after the first minute")
  expectEqual(UsageEvents.warningMinute(limit: 1), nil, "no warning for a 1 minute limit")

  let late = RestrictionRule(
    appKey: "ios-sel:late", appName: "Late", type: .dailyLimit, limitMinutes: 1442)
  let latePlan = UsageEvents.limitPlan(late, id: "late")
  expectEqual(latePlan?.events.map(\.name), ["warning"], "thresholds past 23:59 are left out")
  let never = RestrictionRule(
    appKey: "ios-sel:n", appName: "N", type: .dailyLimit, limitMinutes: 2000)
  expect(UsageEvents.limitPlan(never, id: "n") == nil, "an unreachable limit is not monitored")

  let androidOnly = RestrictionConfiguration.parse(fixture).routines[0]
  expect(UsageEvents.routinePlan(androidOnly) == nil, "a routine without picked apps is not monitored")

  // Wire format of the preferred-usage branch (claude/project-thread-gt9is1).
  let json = """
    {"version":3,"rules":[
      {"appKey":"ios-sel:s","appName":"Social","type":"blockNow","untilMs":1}],
     "routines":[],
     "preferredLimits":[
       {"limitMinutes":30,"apps":["ios-sel:s","com.android.app","ios-sel:s"]},
       {"limitMinutes":0,"apps":["ios-sel:s"]},
       {"limitMinutes":20,"apps":[]},
       {"limitMinutes":"3","apps":["ios-sel:v",7]}]}
    """
  let config = RestrictionConfiguration.parse(json)
  expectEqual(
    config.preferredLimits,
    [
      PreferredLimit(limitMinutes: 30, appKeys: ["ios-sel:s", "com.android.app"]),
      PreferredLimit(limitMinutes: 3, appKeys: ["ios-sel:v"]),
    ], "preferred limits decoded leniently")
  expectEqual(
    RestrictionConfiguration.parse(config.encodedJSON()), config, "preferred limits round trip")

  let nudges = UsageEvents.preferredPlan(config.preferredLimits[0])
  expectEqual(
    nudges?.events.prefix(4).map { "\($0.name)@\($0.minutes)" },
    ["amber@25", "red@29", "limit@30", "over.10@40"], "amber, red, limit, then every 10 minutes")
  expectEqual(nudges?.events.count, 3 + UsageEvents.nudgeMaxRepeats, "over-limit nudges registered ahead")
  expectEqual(nudges?.events.last?.minutes, 30 + 10 * UsageEvents.nudgeMaxRepeats, "last repeat")
  expectEqual(nudges?.events.first?.selectionIds, ["s"], "only picked apps are counted")
  expect(nudges?.name.hasPrefix("ft.preferred.") ?? false, "preferred activity name")
  let short = UsageEvents.preferredPlan(config.preferredLimits[1])
  expectEqual(
    short?.events.prefix(3).map { "\($0.name)@\($0.minutes)" },
    ["amber@1", "red@2", "limit@3"], "short preferred limit")
  expect(
    UsageEvents.preferredPlan(PreferredLimit(limitMinutes: 30, appKeys: ["com.android.app"])) == nil,
    "a preferred limit over unpicked apps is not monitored")
  expectEqual(
    UsageEvents.preferredPlan(config.preferredLimits[0])?.name, nudges?.name,
    "preferred activity names are stable")

  expectEqual(
    UsageEvents.reachedKey(activity: "ft.limit.abc", event: "reached"), "ios-sel:abc#dailyLimit",
    "a reached limit blocks its rule")
  expectEqual(UsageEvents.reachedKey(activity: "ft.limit.abc", event: "warning"), nil, "warnings block nothing")
  expectEqual(UsageEvents.reachedKey(activity: "ft.routine.r1", event: "reached"), "routine:r1", "routine allowance")
  expectEqual(
    UsageEvents.reachedKey(activity: "ft.routine.r1", event: "cap.abc"), "routineApp:r1:abc",
    "routine member cap")
  expectEqual(UsageEvents.reachedKey(activity: "ft.preferred.x", event: "limit"), nil, "nudges never block")
}

// MARK: - Notices

do {
  let config = RestrictionConfiguration.parse(fixture)
  let english = ShieldStrings(values: [:])
  let warning = UsageEvents.notice(
    activity: "ft.limit.3b241101-e2bb-4255-8caf-4136c566a962", event: "warning",
    configuration: config, strings: english)
  expectEqual(warning?.title, "Games limit almost reached", "limit warning title, as Android")
  expectEqual(warning?.body, "Blocking starts in about 5 minutes.", "limit warning body")
  let routine = UsageEvents.notice(
    activity: "ft.routine.routine-2", event: "warning", configuration: config, strings: english)
  expectEqual(routine?.title, "Downtime routine limit almost reached", "routine warning")
  expectEqual(
    warning?.claimKey, "ft.limit.3b241101-e2bb-4255-8caf-4136c566a962#warning#30",
    "the once-a-day claim holds the limit, so a raised limit warns again")
  var raised = config
  if let index = raised.rules.firstIndex(where: { $0.appName == "Games" }) {
    raised.rules[index].limitMinutes = 45
  }
  expect(
    UsageEvents.notice(
      activity: "ft.limit.3b241101-e2bb-4255-8caf-4136c566a962", event: "warning",
      configuration: raised, strings: english)?.claimKey != warning?.claimKey,
    "a raised limit claims a new warning")
  expect(
    UsageEvents.notice(
      activity: "ft.limit.3b241101-e2bb-4255-8caf-4136c566a962", event: "warning",
      configuration: config, strings: english,
      isReached: { $0 == "ios-sel:3b241101-e2bb-4255-8caf-4136c566a962#dailyLimit" }) == nil,
    "no warning for a limit already reached")
  expect(
    UsageEvents.notice(
      activity: "ft.routine.routine-2", event: "warning", configuration: config, strings: english,
      isReached: { $0 == "routine:routine-2" }) == nil,
    "no warning for a routine already reached")
  expect(
    UsageEvents.notice(
      activity: "ft.routine.routine-2", event: "reached", configuration: config, strings: english)
      == nil, "a reached limit posts nothing: the shield says it")

  let german = ShieldStrings(values: [
    "limitWarningTitle": "{name} hat das Limit fast erreicht",
    "limitWarningBody.5": "Die Sperre beginnt in etwa 5 Minuten.",
    "nudgeTitle": "Bevorzugte Nutzungszeit",
    "nudgeOver.20": "20 Min. drüber",
  ])
  let localized = UsageEvents.notice(
    activity: "ft.limit.3b241101-e2bb-4255-8caf-4136c566a962", event: "warning",
    configuration: config, strings: german)
  expectEqual(localized?.title, "Games hat das Limit fast erreicht", "strings from Flutter")
  expectEqual(localized?.body, "Die Sperre beginnt in etwa 5 Minuten.", "pluralized by Flutter")

  var withPreferred = config
  withPreferred.preferredLimits = [
    PreferredLimit(limitMinutes: 30, appKeys: ["ios-sel:3b241101-e2bb-4255-8caf-4136c566a962"])
  ]
  let activity = UsageEvents.preferredPlan(withPreferred.preferredLimits[0])!.name
  func nudge(_ event: String, _ strings: ShieldStrings) -> String? {
    UsageEvents.notice(
      activity: activity, event: event, configuration: withPreferred, strings: strings)?.body
  }
  expectEqual(nudge("amber", english), "5 min left", "amber nudge")
  expectEqual(nudge("red", english), "1 min left", "red nudge")
  expectEqual(nudge("limit", english), "You've reached your time", "limit nudge")
  expectEqual(nudge("over.10", english), "10 min over", "over nudge")
  expectEqual(nudge("over.20", german), "20 Min. drüber", "localized over nudge")
  expectEqual(
    UsageEvents.notice(
      activity: activity, event: "amber", configuration: withPreferred, strings: english)?.title,
    "Preferred usage time · Games", "nudge names the picked apps")
  expectEqual(
    UsageEvents.notice(
      activity: activity, event: "amber", configuration: withPreferred, strings: english)?.identifier,
    "focustrace.nudge." + activity, "one notification per activity, replaced by the next")
}

// MARK: - Shield planning

do {
  let config = RestrictionConfiguration.parse(fixture)
  let blocks = ShieldPlanner.blocks(for: config)
  expectEqual(
    blocks.map(\.storeName),
    [
      "ft.blockNow.0f8fad5b-d9cb-469f-a165-70867728950e",
      "ft.schedule.7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "ft.blockNow.7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "ft.dailyLimit.3b241101-e2bb-4255-8caf-4136c566a962",
      "ft.routine.routine-2",
      "ft.routineApp.routine-2.3b241101-e2bb-4255-8caf-4136c566a962",
      "ft.routineApp.routine-2.7c9e6679-7425-40de-944b-e07fc1f90ae7",
    ], "one store per rule, routine allowance and member cap")
  let shared = blocks[4]
  expectEqual(
    shared.selectionIds,
    ["0f8fad5b-d9cb-469f-a165-70867728950e", "3b241101-e2bb-4255-8caf-4136c566a962"],
    "the allowance shields every included app, not excluded ones")
  expectEqual(shared.eventReason, "routineLimit:routine-2", "Android's event name")
  expectEqual(blocks[5].eventReason, "routineAppLimit:routine-2", "Android's cap event name")

  let now = date(2, 11, 0)
  var reached = Set<String>()
  func active() -> [String] {
    blocks.filter { ShieldPlanner.isActive($0, at: now, isReached: { reached.contains($0) }, calendar: utc) }
      .map(\.key)
  }
  expect(!active().contains("ios-sel:3b241101-e2bb-4255-8caf-4136c566a962#dailyLimit"), "limit not reached")
  reached = [
    "ios-sel:3b241101-e2bb-4255-8caf-4136c566a962#dailyLimit", "routine:routine-2",
    "routineApp:routine-2:7c9e6679-7425-40de-944b-e07fc1f90ae7",
  ]
  let on = active()
  expect(on.contains("ios-sel:3b241101-e2bb-4255-8caf-4136c566a962#dailyLimit"), "reached limit blocks")
  expect(on.contains("routine:routine-2"), "reached allowance blocks")
  expect(on.contains("routineApp:routine-2:7c9e6679-7425-40de-944b-e07fc1f90ae7"), "reached cap blocks")
  expect(!on.contains("routineApp:routine-2:3b241101-e2bb-4255-8caf-4136c566a962"), "other cap does not")

  let limitRule = config.rules[4]
  expectEqual(ShieldPlanner.usageProxy(limitRule, reached: true), 1800, "reached: at the limit")
  expectEqual(ShieldPlanner.usageProxy(limitRule, reached: false), 0, "else unused")
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm"
  formatter.timeZone = TimeZone(identifier: "UTC")
  let english = ShieldStrings(values: [:])
  expectEqual(
    english.reason(for: shared, until: nil, timeFormatter: formatter),
    "Downtime: shared allowance reached", "routine shield line, as Android")
  expectEqual(
    english.reason(for: blocks[6], until: nil, timeFormatter: formatter),
    "Downtime: app limit reached · Evenings", "routine cap shield line")
  expectEqual(
    english.reason(for: blocks[3], until: nil, timeFormatter: formatter),
    "Daily app limit reached · Games", "limit shield line")
}

// MARK: - Reached state and the change guard for limits

do {
  let store = RestrictionStore(defaults: freshDefaults())
  let key = "ios-sel:g#dailyLimit"
  store.markReached(key, at: date(2, 15, 0), calendar: utc)
  expect(store.isReached(key, at: date(2, 23, 59), calendar: utc), "reached for the rest of the day")
  expect(!store.isReached(key, at: date(3, 0, 0), calendar: utc), "a new day starts unreached")
  expect(store.claimNotice("ft.limit.g#warning", at: date(2, 15, 0), calendar: utc), "first notice")
  expect(!store.claimNotice("ft.limit.g#warning", at: date(2, 16, 0), calendar: utc), "once a day")
  expect(store.claimNotice("ft.limit.g#warning", at: date(3, 15, 0), calendar: utc), "again tomorrow")

  func json(limit: Int, difficulty: String) -> String {
    """
    {"version":3,"rules":[{"appKey":"ios-sel:g","appName":"G","type":"dailyLimit","limitMinutes":\(limit),"difficulty":"\(difficulty)"}],"routines":[]}
    """
  }
  let empty = #"{"version":3,"rules":[],"routines":[]}"#
  let now = date(2, 15, 0)
  expect((try? RestrictionSync.apply(json: json(limit: 30, difficulty: "hard"), store: store, now: now, calendar: utc)) != nil, "add a hard limit")
  expectEqual(
    RestrictionSync.requestChange(appKey: "ios-sel:g", type: "dailyLimit", store: store, now: now, calendar: utc),
    "hard", "a reached hard limit is locked")
  var refused = false
  do { try RestrictionSync.apply(json: empty, store: store, now: now, calendar: utc) } catch { refused = true }
  expect(refused, "removing a reached hard limit is refused")
  expect(
    (try? RestrictionSync.apply(json: empty, store: store, now: date(3, 9, 0), calendar: utc)) != nil,
    "removable the next day")

  let fresh = RestrictionStore(defaults: freshDefaults())
  expect((try? RestrictionSync.apply(json: json(limit: 30, difficulty: "hard"), store: fresh, now: now, calendar: utc)) != nil, "add again")
  expectEqual(
    RestrictionSync.requestChange(appKey: "ios-sel:g", type: "dailyLimit", store: fresh, now: now, calendar: utc),
    "allowed", "an unreached limit is not blocking")

  let easy = RestrictionStore(defaults: freshDefaults())
  _ = try? RestrictionSync.apply(json: json(limit: 30, difficulty: "easy"), store: easy, now: now, calendar: utc)
  easy.markReached(key, at: now, calendar: utc)
  expect((try? RestrictionSync.apply(json: json(limit: 30, difficulty: "moderate"), store: easy, now: now, calendar: utc)) != nil, "easy: allowed")
  expect(easy.isReached(key, at: now, calendar: utc), "same thresholds: still reached")
  expect((try? RestrictionSync.apply(json: json(limit: 30, difficulty: "easy"), store: easy, now: now, calendar: utc)) == nil, "moderate reached limit needs the cooldown")
  _ = RestrictionSync.requestChange(appKey: "ios-sel:g", type: "dailyLimit", store: easy, now: now, calendar: utc)
  let later = now.addingTimeInterval(300)
  expect((try? RestrictionSync.apply(json: json(limit: 60, difficulty: "moderate"), store: easy, now: later, calendar: utc)) != nil, "after the cooldown")
  expect(!easy.isReached(key, at: later, calendar: utc), "a new limit is measured again")

  // A deleted limit recreated on the same key, or a paused routine turned on
  // again, does not inherit today's reached flag.
  let gone = RestrictionStore(defaults: freshDefaults())
  _ = try? RestrictionSync.apply(json: json(limit: 30, difficulty: "easy"), store: gone, now: now, calendar: utc)
  gone.markReached(key, at: now, calendar: utc)
  expect((try? RestrictionSync.apply(json: empty, store: gone, now: now, calendar: utc)) != nil, "delete an easy limit")
  _ = try? RestrictionSync.apply(json: json(limit: 30, difficulty: "easy"), store: gone, now: later, calendar: utc)
  expect(!gone.isReached(key, at: later, calendar: utc), "a recreated limit starts unreached")

  let routineJSON = """
    {"version":3,"rules":[],"routines":[{"id":"r","name":"R","isEnabled":true,"dailyLimitMinutes":60,
     "apps":[{"appKey":"ios-sel:a","appName":"A"},{"appKey":"ios-sel:b","appName":"B","limitMinutes":10}]}]}
    """
  let paused = RestrictionStore(defaults: freshDefaults())
  _ = try? RestrictionSync.apply(json: routineJSON, store: paused, now: now, calendar: utc)
  paused.markReached(UsageEvents.routineKey("r"), at: now, calendar: utc)
  paused.markReached(UsageEvents.routineAppKey("r", selectionId: "b"), at: now, calendar: utc)
  _ = try? RestrictionSync.apply(json: routineJSON, store: paused, now: now, calendar: utc)
  expect(paused.isReached(UsageEvents.routineKey("r"), at: now, calendar: utc), "unchanged routine stays reached")
  _ = try? RestrictionSync.apply(json: empty, store: paused, now: now, calendar: utc)
  _ = try? RestrictionSync.apply(json: routineJSON, store: paused, now: later, calendar: utc)
  expect(!paused.isReached(UsageEvents.routineKey("r"), at: later, calendar: utc), "a resumed routine starts unreached")
  expect(
    !paused.isReached(UsageEvents.routineAppKey("r", selectionId: "b"), at: later, calendar: utc),
    "its member caps too")
}

// MARK: - Activity budget

do {
  let now = date(2, 11, 0)  // Monday
  var rules: [RestrictionRule] = []
  rules.append(
    RestrictionRule(
      appKey: "ios-sel:later", appName: "L", type: .schedule, startMinute: 60, endMinute: 120,
      weekdays: [3]))
  rules.append(
    RestrictionRule(
      appKey: "ios-sel:today", appName: "T", type: .schedule, startMinute: 60, endMinute: 120,
      weekdays: [1]))
  rules.append(
    RestrictionRule(appKey: "ios-sel:limit", appName: "Li", type: .dailyLimit, limitMinutes: 30))
  rules.append(
    RestrictionRule(
      appKey: "ios-sel:now", appName: "N", type: .blockNow,
      untilMs: now.addingTimeInterval(3600).epochMilliseconds))
  let config = RestrictionConfiguration(
    rules: rules, preferredLimits: [PreferredLimit(limitMinutes: 60, appKeys: ["ios-sel:p"])])
  let names = ScheduleMapper.plans(for: config, now: now, calendar: utc).map(\.name)
  expectEqual(Array(names.prefix(4)), [
    "ft.blockNow.now", "ft.limit.limit", "ft.schedule.today.day", "ft.schedule.later.day",
  ], "block now, limits, today's schedules, other schedules")
  expect(names.last?.hasPrefix("ft.preferred.") ?? false, "preferred usage last")

  let crowded = RestrictionConfiguration(
    rules: (0..<25).map {
      RestrictionRule(
        appKey: "ios-sel:\($0)", appName: "S", type: .schedule, startMinute: 60, endMinute: 120)
    } + [RestrictionRule(appKey: "ios-sel:limit", appName: "Li", type: .dailyLimit, limitMinutes: 30)])
  let kept = ScheduleMapper.plans(for: crowded, now: now, calendar: utc).map(\.name)
  expectEqual(kept.count, ScheduleMapper.maxActivities, "capped at 20")
  expectEqual(kept.first, "ft.limit.limit", "a limit is kept ahead of schedules")
}

// MARK: - Usage reports (UsageReportModels.swift)

do {
  let week = UsageReportRange.week.interval(endingOn: date(6, 15, 30), calendar: utc)
  expectEqual(week.start, date(31, 0, 0, month: 10), "a week starts six days back")
  expectEqual(week.end, date(7, 0, 0), "and ends after the given day")
  let today = UsageReportRange.today.interval(endingOn: date(6, 15, 30), calendar: utc)
  expectEqual(today.duration, 86_400, "today is one day")
  expectEqual(UsageReportRange.month.interval(endingOn: date(6, 1, 0), calendar: utc).duration, 30 * 86_400, "thirty days")
  expect(UsageReportRange.today.isHourly && !UsageReportRange.week.isHourly, "only a day is hourly")
  expectEqual(UsageReportKind.appDetail.defaultRange, .today, "details default to today")
  expectEqual(UsageReportKind.month.defaultRange, .month, "month report")
  expectEqual(UsageReportKind(rawValue: "hourly"), .hourly, "context names are the raw values")

  var hours = UsageBuckets.hourly(day: date(6, 15, 30), calendar: utc)
  expectEqual(hours.starts.count, 24, "24 hours")
  hours.add(600, at: date(6, 13, 0))
  hours.add(300, at: date(6, 13, 59))
  hours.add(1200, at: date(6, 0, 0))
  hours.add(999, at: date(7, 0, 0))
  hours.add(999, at: date(5, 23, 0))
  expectEqual(hours.seconds[13], 900, "both segments in 13:00")
  expectEqual(hours.seconds[0], 1200, "midnight hour")
  expectEqual(hours.total, 2100, "outside the day is ignored")
  expectEqual(hours.peakIndex, 0, "busiest hour")
  expectEqual(hours.activeCount, 2, "two active hours")

  // DST days in Berlin: buckets follow the wall clock, still 24 of them.
  var berlin = Calendar(identifier: .gregorian)
  berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
  func utcDate(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    date(day, hour, minute, month: month)
  }
  // 2026-03-29: 02:00 CET jumps to 03:00 CEST; the day has 23 hours.
  var spring = UsageBuckets.hourly(day: utcDate(3, 29, 10), calendar: berlin)
  expectEqual(spring.starts.count, 24, "spring DST day: 24 buckets")
  expectEqual(spring.starts.first, utcDate(3, 28, 23), "spring: starts at local midnight")
  expectEqual(spring.end, utcDate(3, 29, 22), "spring: ends at the next local midnight")
  expectEqual(spring.starts[2], spring.starts[3], "spring: the skipped 02:00 hour is empty")
  expectEqual(spring.starts[3], utcDate(3, 29, 1), "spring: 03:00 CEST")
  expectEqual(spring.starts[13], utcDate(3, 29, 11), "spring: 13:00 CEST")
  expectEqual(
    (0..<24).filter { $0 != 2 }.map { berlin.component(.hour, from: spring.starts[$0]) },
    (0..<24).filter { $0 != 2 }, "spring: every bucket starts on its clock hour")
  spring.add(600, at: utcDate(3, 29, 1, 30))
  expectEqual(spring.seconds[3], 600, "spring: 03:30 CEST is in the 03:00 bucket")
  expectEqual(spring.seconds[2], 0, "spring: nothing in the skipped hour")
  // 2026-10-25: 03:00 CEST falls back to 02:00 CET; the day has 25 hours.
  var autumn = UsageBuckets.hourly(day: utcDate(10, 25, 10), calendar: berlin)
  expectEqual(autumn.starts.count, 24, "autumn DST day: 24 buckets")
  expectEqual(autumn.starts.first, utcDate(10, 24, 22), "autumn: starts at local midnight")
  expectEqual(autumn.end, utcDate(10, 25, 23), "autumn: ends at the next local midnight")
  expectEqual(autumn.starts[2], utcDate(10, 25, 0), "autumn: first 02:00 (CEST)")
  expectEqual(autumn.starts[3], utcDate(10, 25, 2), "autumn: 03:00 CET")
  expectEqual(autumn.starts[13], utcDate(10, 25, 12), "autumn: 13:00 CET")
  autumn.add(300, at: utcDate(10, 25, 0, 30))
  autumn.add(400, at: utcDate(10, 25, 1, 30))
  autumn.add(500, at: utcDate(10, 25, 2, 30))
  expectEqual(autumn.seconds[2], 700, "autumn: both 02:00 hours are one bucket")
  expectEqual(autumn.seconds[3], 500, "autumn: 03:00 CET")

  var days = UsageBuckets.daily(interval: week, calendar: utc)
  expectEqual(days.starts.count, 7, "seven days")
  days.add(3600, at: date(6, 0, 0))
  days.add(30, at: date(2, 9, 0))
  expectEqual(days.seconds[6], 3600, "last day")
  expectEqual(days.seconds[2], 30, "Monday")
  expectEqual(days.activeCount, 1, "under a minute is not an active day")
  expectEqual(days.average, 3630.0 / 7, "average over every day of the range")
  expectEqual(UsageBuckets.daily(interval: week, calendar: utc).peakIndex, nil, "no use, no peak")

  expectEqual(UsageReportMath.fraction(0, of: 100), 0, "nothing")
  expectEqual(UsageReportMath.fraction(1, of: 1000), 0.02, "a visible stub")
  expectEqual(UsageReportMath.fraction(50, of: 100), 0.5, "half")
  expectEqual(UsageReportMath.fraction(50, of: 0), 0, "no maximum")
  expectEqual(UsageReportMath.dialShade(1800), 0.5, "half an hour")
  expectEqual(UsageReportMath.dialShade(7200), 1, "capped")

  let ranked = UsageReportMath.ranked(
    [("b", 10.0), ("a", 10.0), ("c", 30.0), ("d", 1.0)], limit: 3, seconds: { $0.1 }, name: { $0.0 })
  expectEqual(ranked.shown.map { $0.0 }, ["c", "a", "b"], "longest first, ties by name")
  expectEqual(ranked.hidden, 1, "one left out")

  let english = ReportStrings()
  expectEqual(english.duration(59), "<1m", "under a minute")
  expectEqual(english.duration(25 * 60 + 59), "25m", "whole minutes")
  expectEqual(english.duration(7200), "2h", "whole hours")
  expectEqual(english.duration(5700), "1h 35m", "hours and minutes")
  expectEqual(english.moreApps(4), "+4 more", "more apps")
  expectEqual(english.localeIdentifier, nil, "device language by default")
  let german = ReportStrings(sharedValues: [
    "report.durationHM": "{h} Std. {m} Min.", "report.locale": "de", "leave": "Verlassen",
  ])
  expectEqual(german.duration(5700), "1 Std. 35 Min.", "translated template")
  expectEqual(german.text("totalTime"), "Total time", "English for a missing text")
  expectEqual(german.localeIdentifier, "de", "app language")
  expectEqual(german.values["leave"], nil, "shield texts are not report texts")

  let store = RestrictionStore(defaults: freshDefaults())
  store.configurationJSON = """
    {"version":3,"rules":[
    {"appKey":"ios-sel:g","appName":"G","type":"dailyLimit","limitMinutes":30},
    {"appKey":"ios-sel:h","appName":"H","type":"dailyLimit","limitMinutes":45},
    {"appKey":"ios-sel:g","appName":"G","type":"schedule","startMinute":60,"endMinute":120}],"routines":[]}
    """
  expectEqual(store.reachedLimitUsage(at: date(2, 15, 0), calendar: utc), [:], "nothing reached")
  store.markReached("ios-sel:g#dailyLimit", at: date(2, 15, 0), calendar: utc)
  expectEqual(
    store.reachedLimitUsage(at: date(2, 16, 0), calendar: utc), ["ios-sel:g": 1800],
    "a reached limit reports its limit as today's use")
  expectEqual(store.reachedLimitUsage(at: date(3, 0, 1), calendar: utc), [:], "gone the next day")
  store.shieldStrings = ShieldStrings(values: ["report.totalTime": "Gesamtzeit", "leave": "L"])
  expectEqual(store.reportStrings.text("totalTime"), "Gesamtzeit", "report texts from the App Group")
}

// MARK: - Apple Health workouts (Runner/WorkoutStore.swift)

do {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("focustrace-kit-\(UUID().uuidString)")
  let file = directory.appendingPathComponent("workouts.json")
  let defaults = freshDefaults()
  let store = WorkoutStore(defaults: defaults, fileURL: file)
  func workout(_ id: String, start: Int64, title: String? = nil) -> StoredWorkout {
    StoredWorkout(
      id: id, sourceBundle: "com.hevy", sourceName: "Hevy", activityType: 50,
      category: "strength", title: title, startMillis: start, endMillis: start + 3_600_000)
  }
  expect(store.upsert(workout("a", start: 1_000)), "new workout counts")
  expect(!store.upsert(workout("a", start: 1_000)), "unchanged workout does not count")
  expect(store.upsert(workout("a", start: 1_000, title: "Push")), "changed workout counts")
  store.upsert(workout("b", start: 5_000))
  store.upsert(workout("c", start: 9_000))
  expectEqual(store.workouts().map(\.id), ["c", "b", "a"], "newest first")
  expectEqual(store.workouts(limit: 2).count, 2, "limit")
  expectEqual(
    store.deleteMissing(fromMillis: 4_000, toMillis: 10_000, keep: ["c"]), 1,
    "stale workout in the window removed")
  expectEqual(store.workouts().map(\.id), ["c", "a"], "outside the window kept")
  try? store.save()
  let reloaded = WorkoutStore(defaults: defaults, fileURL: file)
  expectEqual(reloaded.workouts().map(\.id), ["c", "a"], "saved to disk")
  expectEqual(reloaded.workouts().last?.title, "Push", "title kept")

  reloaded.enabled = true
  reloaded.anchorData = Data([1, 2])
  reloaded.recordAttempt(outcome: "failed", importedCount: 0, nowMillis: 10)
  expectEqual(reloaded.lastSuccessMillis, 0, "a failure is not a success")
  reloaded.recordAttempt(outcome: "imported", importedCount: 2, nowMillis: 20)
  expectEqual(reloaded.lastSuccessMillis, 20, "success time")
  let status = reloaded.status(available: true, requestAnswered: true)
  expectEqual(status["sdkStatus"] as? String, "available", "status availability")
  expectEqual(status["enabled"] as? Bool, true, "status enabled")
  expectEqual(status["readGranted"] as? Bool, true, "answered sheet counts as granted")
  expectEqual(status["lastOutcome"] as? String, "imported", "status outcome")
  expectEqual(status["lastImportedCount"] as? Int, 2, "status count")
  expectEqual(status["workoutCount"] as? Int, 2, "status workouts")
  expectEqual((status["lastSuccessMillis"] as? NSNumber)?.int64Value, 20, "status success millis")
  let unavailable = reloaded.status(available: false, requestAnswered: true)
  expectEqual(unavailable["sdkStatus"] as? String, "unavailable", "unavailable device")
  expectEqual(unavailable["readGranted"] as? Bool, false, "nothing granted without Health")

  let row = WorkoutStore.channelMap(workout("x", start: 7, title: ""))
  expectEqual(row["sourcePackage"] as? String, "com.hevy", "source bundle")
  expectEqual(row["category"] as? String, "strength", "category")
  expect(row["title"] == nil, "empty title left out")
  expectEqual((row["endMillis"] as? NSNumber)?.int64Value, 3_600_007, "end millis")

  let generation = reloaded.generation
  reloaded.clearImported()
  expect(reloaded.generation != generation, "a clear tells a running import to drop its result")
  expectEqual(reloaded.workoutCount, 0, "cleared")
  expect(reloaded.anchorData == nil, "anchor forgotten, next import reconciles 30 days")
  expectEqual(reloaded.lastSuccessMillis, 0, "import state cleared")
  expect(reloaded.enabled, "settings stay")
  expect(!FileManager.default.fileExists(atPath: file.path), "file removed")
  try? FileManager.default.removeItem(at: directory)
}

// MARK: - Backups, language and the home screen widget

do {
  let store = RestrictionStore(defaults: freshDefaults())
  store.setSelectionData(Data([1, 2, 3]), id: "aaaa-1", now: date(2, 9, 0))
  store.setSelectionData(Data([9]), id: "bbbb-2", now: date(2, 9, 0))
  expectEqual(
    store.exportSelections(ids: ["aaaa-1", "missing", "../etc"]), ["aaaa-1": "AQID"],
    "only stored selections with valid ids are exported")
  expect(RestrictionStore.isValidSelectionId("0f8fad5b-d9cb-469f-a165-70867728950e"), "uuid id")
  expect(!RestrictionStore.isValidSelectionId("a/b"), "no path separators")
  expect(!RestrictionStore.isValidSelectionId(""), "no empty id")

  let other = RestrictionStore(defaults: freshDefaults())
  other.setSelectionData(Data([7]), id: "bbbb-2")
  let added = other.importSelections(
    ["aaaa-1": "AQID", "bbbb-2": "AQID", "cccc-3": "not base64!", "dddd-4": "AAAA", "x/y": "AQID"],
    now: date(3, 9, 0), isValid: { $0 != Data([0, 0, 0]) })
  expectEqual(added, 1, "one new, valid selection added")
  expectEqual(other.selectionData(id: "aaaa-1"), Data([1, 2, 3]), "restored data")
  expectEqual(other.selectionData(id: "bbbb-2"), Data([7]), "an existing selection is kept")
  expect(other.selectionData(id: "dddd-4") == nil, "data the codec rejects is skipped")
  expectEqual(other.selectionIds, ["aaaa-1", "bbbb-2"], "nothing else stored")

  store.shieldStrings = ShieldStrings(values: ["leave": "Verlassen", "report.locale": "de"])
  store.setAppLanguage("ja")
  expectEqual(store.reportStrings.localeIdentifier, "ja", "extensions follow the app language")
  expectEqual(store.shieldStrings.text("leave"), "Verlassen", "texts untouched")
  store.setAppLanguage(nil)
  expectEqual(store.reportStrings.localeIdentifier, nil, "device language again")

  let strings = WidgetStrings(sharedValues: [
    "widget.blockingNow": "Jetzt gesperrt", "widget.until": "bis {time}", "leave": "x",
  ])
  expectEqual(strings.text("blockingNow"), "Jetzt gesperrt", "translated widget text")
  expectEqual(strings.text("nextBlock"), "Next block", "English fallback")
  expectEqual(strings.until("15:00"), "bis 15:00", "time filled in")
  expectEqual(strings.values["leave"], nil, "shield texts are not widget texts")
}

do {
  // Monday 2026-11-02, 10:00 UTC.
  let now = date(2, 10, 0)
  let json = """
    {"version":3,"rules":[
    {"appKey":"ios-sel:s","appName":"Social","type":"blockNow","untilMs":\(date(2, 11, 30).epochMilliseconds)},
    {"appKey":"ios-sel:w","appName":"Work","type":"schedule","startMinute":540,"endMinute":720,"weekdays":[1,2,3,4,5]},
    {"appKey":"ios-sel:e","appName":"Evenings","type":"schedule","startMinute":1260,"endMinute":420,"weekdays":[1,2,3,4,5]},
    {"appKey":"ios-sel:k","appName":"Weekend","type":"schedule","startMinute":600,"endMinute":660,"weekdays":[6]},
    {"appKey":"ios-sel:g","appName":"Games","type":"dailyLimit","limitMinutes":30},
    {"appKey":"com.android.app","appName":"Android","type":"schedule","startMinute":600,"endMinute":700}],
    "routines":[{"id":"r1","name":"Study","isEnabled":true,"dailyLimitMinutes":60,
    "apps":[{"appKey":"ios-sel:g","appName":"Games","isIncludedInLimit":true,"limitMinutes":20}]}]}
    """
  let config = RestrictionConfiguration.parse(json)
  let reached: Set<String> = ["ios-sel:g#dailyLimit", "routineApp:r1:g"]
  let snapshot = WidgetStatus.snapshot(
    configuration: config, at: now, isReached: { reached.contains($0) }, calendar: utc)
  expectEqual(
    snapshot.activeNames, ["Social", "Work", "Games"],
    "active blocks, soonest end first, each name once")
  expectEqual(snapshot.activeUntil, date(2, 11, 30), "soonest end")
  expectEqual(snapshot.limitsReached, 2, "daily limit and member cap reached")
  expectEqual(snapshot.next?.name, "Evenings", "next schedule")
  expectEqual(snapshot.next?.start, date(2, 21, 0), "next start today")
  expect(snapshot.hasRestrictions, "has restrictions")

  let friday = WidgetStatus.nextSchedule(configuration: config, after: date(6, 22, 0), calendar: utc)
  expectEqual(friday?.name, "Weekend", "weekday filter skips to Saturday")
  expectEqual(friday?.start, date(7, 10, 0), "Saturday 10:00")

  let empty = WidgetStatus.snapshot(
    configuration: RestrictionConfiguration.parse(nil), at: now, isReached: { _ in false },
    calendar: utc)
  expect(!empty.hasRestrictions, "no restrictions yet")
  expect(empty.activeNames.isEmpty && empty.next == nil, "nothing to show")

  let timeline = WidgetStatus.timeline(configuration: config, from: now, calendar: utc)
  expectEqual(timeline.first, now, "starts now")
  expect(timeline.contains(date(2, 11, 30)), "block-now end")
  expect(timeline.contains(date(2, 12, 0)), "schedule end")
  expect(timeline.contains(date(2, 21, 0)), "schedule start")
  expect(timeline.contains(date(3, 0, 0)), "midnight lifts reached limits")
  expect(timeline.contains(date(3, 9, 0)), "tomorrow's start within a day")
  expect(!timeline.contains(date(2, 10, 0).addingTimeInterval(-60)), "nothing in the past")
  expect(timeline.allSatisfy { $0 <= now.addingTimeInterval(24 * 3600) }, "one day ahead at most")
  expectEqual(timeline, timeline.sorted(), "sorted")
}

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
