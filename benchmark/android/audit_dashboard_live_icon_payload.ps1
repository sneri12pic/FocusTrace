param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [int]$Pairs = 10,
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

function Capture-LivePayload {
    param([bool]$IncludeIcons, [int]$PairIndex)

    & $adb shell am force-stop $package
    Start-Sleep -Milliseconds 750
    & $adb logcat -c
    $includeValue = $IncludeIcons.ToString().ToLowerInvariant()
    $launchOutput = @(
        & $adb shell am start -W --ez benchmarkIncludeUsageIcons $includeValue -n $activity
    )
    $launchState = (($launchOutput | Select-String '^LaunchState:').Line -split ':', 2)[1].Trim()

    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    $lines = @()
    do {
        Start-Sleep -Milliseconds 200
        $lines = @(& $adb logcat -d -v raw 'flutter:I' 'FTDashboardNativePerf:I' '*:S')
        $hasLive = $lines -match 'FocusTraceDashboardPerf,live_usage_available,'
        $hasNative = $lines -match '^live_usage_payload,'
    } while ((-not $hasLive -or -not $hasNative) -and [DateTime]::UtcNow -lt $deadline)

    $events = @{}
    $runId = $null
    foreach ($line in $lines) {
        if ($line -notmatch 'FocusTraceDashboardPerf,') { continue }
        $parts = (($line -split 'FocusTraceDashboardPerf,', 2)[1]).Split(',')
        if ($parts.Count -lt 3) { continue }
        $runId = $parts[1]
        $events[$parts[0]] = [long]$parts[2]
    }

    $native = @{}
    foreach ($line in $lines) {
        if ($line -notmatch '^live_usage_payload,') { continue }
        $parts = $line.Split(',')
        if ($parts.Count -lt 3 -or $parts[1] -ne $runId) { continue }
        $native['total_us'] = [long]$parts[2]
        $details = Read-Details -Parts $parts -StartIndex 3
        foreach ($key in $details.Keys) { $native[$key] = $details[$key] }
    }

    $complete =
        $events.ContainsKey('live_platform_call_start') -and
        $events.ContainsKey('live_usage_available') -and
        $native.ContainsKey('total_us')
    $row = [pscustomobject]@{
        pair_index = $PairIndex
        include_icons = $includeValue
        launch_state = $launchState
        run_id = $runId
        live_platform_call_start_us = $events['live_platform_call_start']
        live_usage_available_us = $events['live_usage_available']
        live_platform_call_duration_us = if ($complete) {
            $events['live_usage_available'] - $events['live_platform_call_start']
        } else { $null }
        native_total_us = $native['total_us']
        native_query_us = $native['query_us']
        native_metadata_us = $native['metadata_us']
        icon_bytes = $native['icon_bytes']
        icon_memory_hits = $native['memory_hits']
        icon_disk_hits = $native['disk_hits']
        icon_regenerated = $native['regenerated']
        complete = $complete.ToString().ToLowerInvariant()
        included = $complete.ToString().ToLowerInvariant()
    }
    $script:results += $row
    $script:results | Export-Csv -Path $OutputPath -NoTypeInformation
    $row | Format-Table -AutoSize | Out-String | Write-Host
}

for ($pair = 1; $pair -le $Pairs; $pair++) {
    Capture-LivePayload -IncludeIcons $true -PairIndex $pair
    Capture-LivePayload -IncludeIcons $false -PairIndex $pair
}
