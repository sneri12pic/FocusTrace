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
  expectEqual(config.rules.count, 4, "fixture rule count")
  expectEqual(config.routines.count, 1, "fixture routine count")
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

  store.recordBlocked(appKey: "ios-sel:kept", appName: "K", reason: "blockNow", now: now)
  store.recordBlocked(appKey: "ios-sel:kept", appName: "K", reason: "blockNow", now: now.addingTimeInterval(30))
  store.recordBlocked(appKey: "ios-sel:kept", appName: "K", reason: "blockNow", now: now.addingTimeInterval(61))
  let events = store.takeEvents()
  expectEqual(events.count, 2, "one event a minute per rule")
  expectEqual(events.first?["type"] as? String, "blocked", "event type")
  expectEqual((events.first?["occurredAtMs"] as? NSNumber)?.int64Value, now.epochMilliseconds, "event time")
  expectEqual(store.takeEvents().count, 0, "taking events empties the queue")

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
      "ft.schedule.7c9e6679-7425-40de-944b-e07fc1f90ae7.evening",
      "ft.schedule.7c9e6679-7425-40de-944b-e07fc1f90ae7.morning",
    ], "plans for the fixture (limits are phase 3)")
  if plans.count == 4 {
    expectEqual(plans[2].start, DateComponents(hour: 22, minute: 0), "evening start")
    expectEqual(plans[2].end, DateComponents(hour: 23, minute: 59), "evening end")
    expectEqual(plans[3].start, DateComponents(hour: 0, minute: 0), "morning start")
    expectEqual(plans[3].end, DateComponents(hour: 7, minute: 0), "morning end")
    expect(plans[2].repeats && !plans[0].repeats, "schedules repeat, blocks do not")
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

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
