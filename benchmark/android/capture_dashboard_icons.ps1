param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [int]$Pairs = 15,
    [string]$AdbPath = 'adb'
)

$ErrorActionPreference = 'Stop'
$adb = (Get-Command -Name $AdbPath -ErrorAction Stop).Source
$package = 'com.stepandemianenko.focustrace.dev'
$activity = "$package/com.stepandemianenko.focustrace.MainActivity"
$results = @()

function Read-Details {
    param([string[]]$Parts, [int]$StartIndex)
    $details = @{}
    for ($index = $StartIndex; $index -lt $Parts.Count; $index++) {
        $pair = $Parts[$index].Split('=', 2)
        if ($pair.Count -eq 2) {
            $details[$pair[0]] = $pair[1]
        }
    }
    return $details
}

function Capture-DashboardIconOpen {
    param(
        [string]$RequestedScenario,
        [int]$PairIndex
    )

    & $adb logcat -c
    $launchOutput = @(& $adb shell am start -W -n $activity)
    $launchState = (($launchOutput | Select-String '^LaunchState:').Line -split ':', 2)[1].Trim()
    $totalTimeMs = [int]((($launchOutput | Select-String '^TotalTime:').Line -split ':', 2)[1].Trim())

    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    $lines = @()
    do {
        Start-Sleep -Milliseconds 200
        $lines = @(& $adb logcat -d -v raw 'flutter:I' 'FTDashboardNativePerf:I' '*:S')
        $hasIconsFrame = $lines -match 'first_all_available_icons_frame'
        $hasLivePayload = $lines -match '^live_usage_payload,'
        $hasLiveAvailable = $lines -match 'FocusTraceDashboardPerf,live_usage_available,'
    } while ((-not $hasIconsFrame -or -not $hasLivePayload -or -not $hasLiveAvailable) -and [DateTime]::UtcNow -lt $deadline)

    $events = @{}
    $eventDetails = @{}
    $runId = $null
    foreach ($line in $lines) {
        if ($line -notmatch 'FocusTraceDashboardPerf,') {
            continue
        }
        $payload = ($line -split 'FocusTraceDashboardPerf,', 2)[1]
        $parts = $payload.Split(',')
        if ($parts.Count -lt 3) {
            continue
        }
        $eventName = $parts[0]
        $runId = $parts[1]
        $events[$eventName] = [long]$parts[2]
        $eventDetails[$eventName] = Read-Details -Parts $parts -StartIndex 3
    }

    $native = @{}
    $metadataNative = @{}
    foreach ($line in $lines) {
        if ($line -notmatch '^live_usage_payload,') {
            continue
        }
        $parts = $line.Split(',')
        if ($parts.Count -lt 3 -or $parts[1] -ne $runId) {
            continue
        }
        $native['total_us'] = [long]$parts[2]
        $details = Read-Details -Parts $parts -StartIndex 3
        foreach ($key in $details.Keys) {
            $native[$key] = $details[$key]
        }
    }
    foreach ($line in $lines) {
        if ($line -notmatch '^metadata_payload,') {
            continue
        }
        $parts = $line.Split(',')
        if ($parts.Count -lt 3 -or $parts[1] -ne $runId) {
            continue
        }
        $metadataNative['total_us'] = [long]$parts[2]
        $details = Read-Details -Parts $parts -StartIndex 3
        foreach ($key in $details.Keys) {
            $metadataNative[$key] = $details[$key]
        }
    }

    $requiredEvents = @(
        'dashboard_open',
        'cached_state_published',
        'first_bubble_frame',
        'initial_graph_icon_state',
        'icon_hydration_start',
        'icon_hydration_complete',
        'first_all_available_icons_frame',
        'live_usage_available'
    )
    $hydrationSource = $eventDetails['icon_hydration_start']['source']
    $hasHydrationNative =
        ($hydrationSource -eq 'live_usage' -and $native.ContainsKey('total_us')) -or
        ($hydrationSource -eq 'metadata' -and $metadataNative.ContainsKey('total_us'))
    $complete =
        ($requiredEvents | Where-Object { -not $events.ContainsKey($_) }).Count -eq 0 -and
        $native.ContainsKey('total_us') -and $hasHydrationNative
    $placeholderUs = if ($complete) {
        $events['first_all_available_icons_frame'] - $events['first_bubble_frame']
    } else {
        $null
    }
    $row = [pscustomobject]@{
        pair_index = $PairIndex
        scenario = $RequestedScenario
        launch_state = $launchState
        run_id = $runId
        activity_total_time_ms = $totalTimeMs
        cached_state_published_us = $events['cached_state_published']
        first_bubble_frame_us = $events['first_bubble_frame']
        initial_top_count = $eventDetails['initial_graph_icon_state']['top_count']
        initial_real_icon_count = $eventDetails['initial_graph_icon_state']['real_icon_count']
        icon_hydration_start_us = $events['icon_hydration_start']
        hydration_source = $hydrationSource
        icon_hydration_complete_us = $events['icon_hydration_complete']
        available_top_icon_count = $eventDetails['icon_hydration_complete']['available_top_count']
        first_all_available_icons_frame_us = $events['first_all_available_icons_frame']
        placeholder_duration_us = $placeholderUs
        live_usage_available_us = $events['live_usage_available']
        live_native_total_us = $native['total_us']
        live_query_us = $native['query_us']
        live_metadata_us = $native['metadata_us']
        live_icon_bytes = $native['icon_bytes']
        icon_memory_hits = $native['memory_hits']
        icon_disk_hits = $native['disk_hits']
        icon_regenerated = $native['regenerated']
        icon_failures = $native['failures']
        metadata_native_total_us = $metadataNative['total_us']
        metadata_icon_bytes = $metadataNative['icon_bytes']
        metadata_memory_hits = $metadataNative['memory_hits']
        metadata_disk_hits = $metadataNative['disk_hits']
        metadata_regenerated = $metadataNative['regenerated']
        metadata_failures = $metadataNative['failures']
        metadata_missing_packages = $metadataNative['missing_packages']
        complete = $complete.ToString().ToLowerInvariant()
        included = $complete.ToString().ToLowerInvariant()
    }
    $script:results += $row
    $script:results | Export-Csv -Path $OutputPath -NoTypeInformation
    $row | Format-Table -AutoSize | Out-String | Write-Host
}

for ($pair = 1; $pair -le $Pairs; $pair++) {
    & $adb shell am force-stop $package
    Start-Sleep -Milliseconds 750
    Capture-DashboardIconOpen -RequestedScenario 'process_cold' -PairIndex $pair

    & $adb shell input keyevent KEYCODE_BACK
    Start-Sleep -Milliseconds 750
    Capture-DashboardIconOpen -RequestedScenario 'activity_warm' -PairIndex $pair
}
