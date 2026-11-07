#!/usr/bin/env bash
# Proves the extensions of a built Runner.app (argument) were built, are
# embedded where iOS looks for them, declare the expected extension point and
# do not link Flutter. Xcode 16 debug builds may move an extension's code into
# <Name>.debug.dylib (ENABLE_DEBUG_DYLIB), so every Mach-O file in the bundle
# is checked, not only the main binary. macOS only (plutil, otool); CI job
# ios-build runs it after the Debug and the Release build.
set -euo pipefail
app="${1:?usage: check_embedded_extensions.sh path/to/Runner.app}"
while read -r ext key expected; do
  bundle="$app/$ext.appex"
  name=$(basename "$ext")
  test -f "$bundle/$name" || { echo "::error::missing $bundle/$name"; exit 1; }
  plutil -p "$bundle/Info.plist" | grep -E 'CFBundleIdentifier|CFBundleShortVersionString'
  point=$(plutil -extract "$key" raw -o - "$bundle/Info.plist") \
    || { echo "::error::$name has no $key"; exit 1; }
  echo "$name $key = $point"
  if [ "$point" != "$expected" ]; then
    echo "::error::$name declares $point, expected $expected"; exit 1
  fi
  checked=0
  for bin in "$bundle"/*; do
    [ -f "$bin" ] && file -b "$bin" | grep -q Mach-O || continue
    checked=$((checked + 1))
    echo "  $(basename "$bin")"
    if otool -L "$bin" | grep -q Flutter; then
      echo "::error::$(basename "$bin") in $name links Flutter"; exit 1
    fi
  done
  [ "$checked" -gt 0 ] || { echo "::error::no Mach-O file in $bundle"; exit 1; }
done <<'LIST'
PlugIns/FocusTraceMonitor NSExtension.NSExtensionPointIdentifier com.apple.deviceactivity.monitor-extension
PlugIns/FocusTraceShield NSExtension.NSExtensionPointIdentifier com.apple.ManagedSettingsUI.shield-configuration-service
PlugIns/FocusTraceShieldAction NSExtension.NSExtensionPointIdentifier com.apple.ManagedSettings.shield-action-service
PlugIns/FocusTraceWidget NSExtension.NSExtensionPointIdentifier com.apple.widgetkit-extension
Extensions/FocusTraceReport EXAppExtensionAttributes.EXExtensionPointIdentifier com.apple.deviceactivityui.report-extension
LIST
