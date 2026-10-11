[CmdletBinding()]
param(
    [Parameter()]
    [string]$DeviceId,

    [Parameter()]
    [string]$PackageId = 'com.busster.busster',

    [Parameter()]
    [ValidateRange(1, 10)]
    [int]$Samples = 5,

    [Parameter()]
    [string]$OutputDirectory = 'build/android-metrics'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-AdbPath {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $adbCommand) {
        return $adbCommand.Source
    }

    $sdkPath = $env:ANDROID_SDK_ROOT
    if ([string]::IsNullOrWhiteSpace($sdkPath)) {
        $sdkPath = $env:ANDROID_HOME
    }
    if ([string]::IsNullOrWhiteSpace($sdkPath)) {
        $sdkPath = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
    }

    $candidate = Join-Path $sdkPath 'platform-tools/adb.exe'
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    $localProperties = Join-Path $repositoryRoot 'android/local.properties'
    if (Test-Path -LiteralPath $localProperties) {
        $sdkLine = Get-Content -LiteralPath $localProperties |
            Where-Object { $_ -match '^sdk\.dir=' } |
            Select-Object -First 1
        if ($null -ne $sdkLine) {
            $sdkPath = ($sdkLine -replace '^sdk\.dir=', '') -replace '\\\\', '\'
            $candidate = Join-Path $sdkPath 'platform-tools/adb.exe'
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }

    throw 'adb was not found. Add Android platform-tools to PATH or configure the Android SDK.'
}

function Invoke-AdbCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $commandOutput = & $adbPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb $($Arguments -join ' ') failed: $($commandOutput | Out-String)"
    }
    return ($commandOutput | Out-String)
}

$adbPath = Resolve-AdbPath
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $deviceRows = Invoke-AdbCommand -Arguments @('devices')
    $connectedDevices = [regex]::Matches($deviceRows, '(?m)^([^\s]+)\s+device\b')
    if ($connectedDevices.Count -eq 0) {
        throw 'No Android device or emulator is connected. Start one or connect a device, then pass -DeviceId if needed.'
    }
    if ($connectedDevices.Count -gt 1) {
        throw 'More than one Android device or emulator is connected. Pass -DeviceId to select the intended target.'
    }
    $DeviceId = $connectedDevices[0].Groups[1].Value
}

$deviceState = Invoke-AdbCommand -Arguments @('-s', $DeviceId, 'get-state')
if ($deviceState.Trim() -ne 'device') {
    throw "Android target '$DeviceId' is not ready. adb reported: $($deviceState.Trim())"
}

$packageInfo = Invoke-AdbCommand -Arguments @('-s', $DeviceId, 'shell', 'pm', 'path', $PackageId)
if ($packageInfo -notmatch "package:/") {
    throw "Package '$PackageId' is not installed on '$DeviceId'. Install the release APK first."
}

$sdkApi = (Invoke-AdbCommand -Arguments @('-s', $DeviceId, 'shell', 'getprop', 'ro.build.version.sdk')).Trim()
$deviceModel = (Invoke-AdbCommand -Arguments @('-s', $DeviceId, 'shell', 'getprop', 'ro.product.model')).Trim()
$activityName = "$PackageId/.MainActivity"
$sampleRecords = @()

for ($sampleIndex = 1; $sampleIndex -le $Samples; $sampleIndex++) {
    [void](Invoke-AdbCommand -Arguments @('-s', $DeviceId, 'shell', 'am', 'force-stop', $PackageId))
    $launchOutput = Invoke-AdbCommand -Arguments @(
        '-s', $DeviceId,
        'shell', 'am', 'start', '-W', '-n', $activityName
    )
    $totalTimeMatch = [regex]::Match($launchOutput, '(?m)^TotalTime:\s*(\d+)')
    $waitTimeMatch = [regex]::Match($launchOutput, '(?m)^WaitTime:\s*(\d+)')
    if (-not $totalTimeMatch.Success) {
        throw "Could not read Android launch timing for sample $sampleIndex`: $launchOutput"
    }

    Start-Sleep -Milliseconds 1000
    $memoryOutput = Invoke-AdbCommand -Arguments @('-s', $DeviceId, 'shell', 'dumpsys', 'meminfo', $PackageId)
    $pssMatch = [regex]::Match($memoryOutput, '(?im)^\s*TOTAL PSS:\s*([\d,]+)')
    $pssKilobytes = $null
    if ($pssMatch.Success) {
        $pssKilobytes = [int]($pssMatch.Groups[1].Value -replace ',', '')
    }

    $sampleRecords += [pscustomobject]@{
        sample = $sampleIndex
        totalTimeMs = [int]$totalTimeMatch.Groups[1].Value
        waitTimeMs = if ($waitTimeMatch.Success) { [int]$waitTimeMatch.Groups[1].Value } else { $null }
        totalPssKbAfter1s = $pssKilobytes
    }
}

$sortedLaunchTimes = @($sampleRecords | ForEach-Object { $_.totalTimeMs } | Sort-Object)
$middleIndex = [int][math]::Floor($sortedLaunchTimes.Count / 2)
if ($sortedLaunchTimes.Count % 2 -eq 1) {
    $medianLaunchMs = [double]$sortedLaunchTimes[$middleIndex]
} else {
    $medianLaunchMs = ([double]$sortedLaunchTimes[$middleIndex - 1] + [double]$sortedLaunchTimes[$middleIndex]) / 2
}

$artifactFiles = @(
    (Join-Path $repositoryRoot 'build/app/outputs/flutter-apk/app-release.apk'),
    (Join-Path $repositoryRoot 'build/app/outputs/bundle/release/app-release.aab')
)
$artifactSizes = @(
    foreach ($artifactPath in $artifactFiles) {
        if (Test-Path -LiteralPath $artifactPath) {
            $artifactInfo = Get-Item -LiteralPath $artifactPath
            [pscustomobject]@{
                path = $artifactInfo.FullName.Substring($repositoryRoot.Length).TrimStart([char[]]@('\', '/'))
                sizeBytes = $artifactInfo.Length
            }
        }
    }
)

$report = [ordered]@{
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    deviceId = $DeviceId
    model = $deviceModel
    androidApi = [int]$sdkApi
    packageId = $PackageId
    sampleCount = $Samples
    medianTotalLaunchTimeMs = $medianLaunchMs
    samples = $sampleRecords
    releaseArtifacts = $artifactSizes
    limitations = @(
        'Android am start -W is a process/activity launch metric, not time-to-first-interactive measurement.',
        'PSS is a point-in-time reading one second after launch.',
        'Emulator results do not replace physical-device, thermal, frame-time, or touch-response testing.'
    )
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $outputPath = $OutputDirectory
} else {
    $outputPath = Join-Path $repositoryRoot $OutputDirectory
}
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$reportName = "android-$DeviceId-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$reportPath = Join-Path $outputPath $reportName
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8

Write-Host "Android API $sdkApi ($deviceModel), package $PackageId"
Write-Host "Process-launch TotalTime median: $medianLaunchMs ms across $Samples launches"
Write-Host "Report: $reportPath"
Write-Host 'Emulator-only data; it does not close physical-device QA gates.'
