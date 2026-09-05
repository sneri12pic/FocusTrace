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

function Capture-DashboardOpen {
    param(
        [string]$RequestedScenario,
        [int]$PairIndex
    )

    & $adb logcat -c
    $launchOutput = @(& $adb shell am start -W -n $activity)
    $launchState = (($launchOutput | Select-String '^LaunchState:').Line -split ':', 2)[1].Trim()
    $totalTimeMs = [int]((($launchOutput | Select-String '^TotalTime:').Line -split ':', 2)[1].Trim())

    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    $eventLines = @()
    do {
        Start-Sleep -Milliseconds 250
        $eventLines = @(
            & $adb logcat -d -v raw 'flutter:I' '*:S' |
                Select-String 'FocusTraceDashboardPerf,' |
                ForEach-Object { $_.Line }
        )
        $hasCompletion = $eventLines -match 'entrance_animation_complete'
    } while (-not $hasCompletion -and [DateTime]::UtcNow -lt $deadline)

    $events = @{}
    $runId = $null
    foreach ($line in $eventLines) {
        $payload = ($line -split 'FocusTraceDashboardPerf,', 2)[1]
        $parts = $payload.Split(',')
        if ($parts.Count -ne 3) {
            continue
        }
        $eventName = $parts[0]
        $runId = $parts[1]
        $events[$eventName] = [long]$parts[2]
    }

    $requiredEvents = @(
        'dashboard_open',
        'view_model_init',
        'live_usage_available',
        'first_non_empty_state',
        'first_bubble_frame',
        'entrance_animation_complete'
    )
    $complete = ($requiredEvents | Where-Object { -not $events.ContainsKey($_) }).Count -eq 0
    $row = [pscustomobject]@{
        pair_index = $PairIndex
        scenario = $RequestedScenario
        launch_state = $launchState
        run_id = $runId
        activity_total_time_ms = $totalTimeMs
        dashboard_open_us = $events['dashboard_open']
        view_model_init_us = $events['view_model_init']
        live_usage_available_us = $events['live_usage_available']
        first_non_empty_state_us = $events['first_non_empty_state']
        first_bubble_frame_us = $events['first_bubble_frame']
        entrance_animation_complete_us = $events['entrance_animation_complete']
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
    Capture-DashboardOpen -RequestedScenario 'process_cold' -PairIndex $pair

    & $adb shell input keyevent KEYCODE_BACK
    Start-Sleep -Milliseconds 750
    Capture-DashboardOpen -RequestedScenario 'activity_warm' -PairIndex $pair
}
