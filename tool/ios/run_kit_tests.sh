#!/usr/bin/env bash
# Compiles the pure-Foundation FocusTraceKit sources with tool/ios/kit_tests and
# runs them against the fixture Dart writes. macOS only (needs swiftc); CI job
# ios-build runs it. Screen Time files (ScreenTimeEnforcement.swift) are left
# out: those frameworks do not exist on macOS.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/focustrace-kit-tests"
kit="$root/ios/FocusTraceKit"
swiftc -O -o "$out" \
  "$kit/AppGroup.swift" \
  "$kit/RestrictionModels.swift" \
  "$kit/RestrictionChangeGuard.swift" \
  "$kit/RestrictionStore.swift" \
  "$kit/ShieldStrings.swift" \
  "$kit/ScheduleMapper.swift" \
  "$kit/UsageEvents.swift" \
  "$kit/ShieldPlanner.swift" \
  "$kit/UsageReportModels.swift" \
  "$root/tool/ios/kit_tests/main.swift"
"$out" "$root/test/fixtures/ios_restriction_configuration.json"
