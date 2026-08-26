param(
    [Parameter(Mandatory = $true)]
    [string]$Endpoint,
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    [string]$FlutterPath = 'flutter',
    [string]$ApkPath = 'build\app\outputs\flutter-apk\app-release.apk',
    [string]$EvidencePath = 'build\p4_08_android_evidence.json',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$packageName = 'com.local.voice_trainer'
$recordPermission = 'android.permission.RECORD_AUDIO'
$gateTarget = 'tool/p4_08_android_release_main.dart'
$approvedEndpoint = '127.0.0.1:16384'
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("voice-trainer-p4-08-" + [guid]::NewGuid().ToString('N'))
$gateInstalled = $false
$originalInstalled = $false
$originalRunning = $false
$originalPermission = 'false'
$originalAppOp = 'default'
$originalPackages = @()

if ($Endpoint -ne $approvedEndpoint) {
    throw "P4-08 is locked to the approved vertical emulator $approvedEndpoint."
}
if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    throw 'Android SDK Platform-Tools adb.exe was not found. Pass -AdbPath explicitly.'
}

function Invoke-Adb {
    param([Parameter(Mandatory = $true)][string[]]$AdbArguments)
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $AdbPath -s $Endpoint @AdbArguments 2>&1
        $commandExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($commandExitCode -ne 0) {
        throw "SDK ADB command failed: $($AdbArguments -join ' ')"
    }
    return $output
}

function Test-PackageInstalled {
    & $AdbPath -s $Endpoint shell pm path $packageName *> $null
    return $LASTEXITCODE -eq 0
}

function Get-AppProcessId {
    $output = & $AdbPath -s $Endpoint shell pidof $packageName 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return (($output -join '').Trim())
}

function Get-AppLog {
    $appProcessId = Get-AppProcessId
    if ([string]::IsNullOrWhiteSpace($appProcessId)) { return '' }
    return ((Invoke-Adb -AdbArguments @('logcat', '-d', "--pid=$appProcessId")) -join "`n")
}

function Start-GateApp {
    Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $packageName) | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'monkey', '-p', $packageName, '1') | Out-Null
}

function Wait-AppLog {
    param([string]$Pattern, [int]$TimeoutSeconds)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $lastObserved = ''
    while ([DateTime]::UtcNow -lt $deadline) {
        $lastObserved = Get-AppLog
        if ($lastObserved.Contains('P4_08_RELEASE_GATE_FAILED')) {
            throw 'The release gate reported a typed terminal failure.'
        }
        if ($lastObserved.Contains($Pattern)) { return $lastObserved }
        Start-Sleep -Milliseconds 500
    }
    $observed = [regex]::Matches($lastObserved, 'P4_08_[A-Z_]+') |
        ForEach-Object { $_.Value } |
        Select-Object -Unique
    Write-Host "Last observed P4-08 sentinels: $($observed -join ', ')."
    throw "Timed out waiting for release sentinel: $Pattern"
}

function Get-PermissionState {
    $output = (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'package', $packageName)) -join "`n"
    $match = [regex]::Match(
        $output,
        'android\.permission\.RECORD_AUDIO:\s+granted=(true|false)'
    )
    if (-not $match.Success) { throw 'Unable to read RECORD_AUDIO permission state.' }
    return $match.Groups[1].Value
}

function Get-AppOpState {
    $output = (Invoke-Adb -AdbArguments @('shell', 'appops', 'get', $packageName, 'RECORD_AUDIO')) -join "`n"
    $match = [regex]::Match($output, 'RECORD_AUDIO:\s+(allow|deny|ignore|default|foreground)')
    if (-not $match.Success) { throw 'Unable to read the RECORD_AUDIO app-op state.' }
    return $match.Groups[1].Value
}

function Set-PermissionState {
    param([ValidateSet('true', 'false')][string]$Granted, [string]$AppOp)
    Invoke-Adb -AdbArguments @('shell', 'pm', 'clear-permission-flags', $packageName, $recordPermission, 'user-set', 'user-fixed') | Out-Null
    if ($Granted -eq 'true') {
        Invoke-Adb -AdbArguments @('shell', 'pm', 'grant', $packageName, $recordPermission) | Out-Null
    } else {
        Invoke-Adb -AdbArguments @('shell', 'pm', 'revoke', $packageName, $recordPermission) | Out-Null
        Invoke-Adb -AdbArguments @('shell', 'pm', 'set-permission-flags', $packageName, $recordPermission, 'user-set', 'user-fixed') | Out-Null
    }
    Invoke-Adb -AdbArguments @('shell', 'appops', 'set', $packageName, 'RECORD_AUDIO', $AppOp) | Out-Null
}

function Save-InstalledPackage {
    param([string]$Destination)
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $remotePaths = Invoke-Adb -AdbArguments @('shell', 'pm', 'path', $packageName)
    $saved = @()
    $index = 0
    foreach ($entry in $remotePaths) {
        if ($entry -notmatch '^package:(.+\.apk)$') { continue }
        $remotePath = $Matches[1]
        $leaf = [IO.Path]::GetFileName($remotePath)
        $localPath = Join-Path $Destination ("$index-$leaf")
        Invoke-Adb -AdbArguments @('pull', $remotePath, $localPath) | Out-Null
        $saved += [pscustomobject]@{
            path = $localPath
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $localPath).Hash
        }
        $index += 1
    }
    if ($saved.Count -eq 0) { throw 'Unable to preserve the installed APK set.' }
    return $saved
}

function Restore-InstalledPackage {
    if (-not $originalInstalled) {
        if (Test-PackageInstalled) { Invoke-Adb -AdbArguments @('uninstall', $packageName) | Out-Null }
        return
    }
    $paths = @($originalPackages | ForEach-Object { $_.path })
    if ($paths.Count -eq 1) {
        Invoke-Adb -AdbArguments @('install', '-r', $paths[0]) | Out-Null
    } else {
        Invoke-Adb -AdbArguments (@('install-multiple', '-r') + $paths) | Out-Null
    }
    $verificationRoot = Join-Path $temporaryRoot 'verification'
    $restored = Save-InstalledPackage -Destination $verificationRoot
    try {
        $before = @($originalPackages | ForEach-Object { $_.sha256 } | Sort-Object)
        $after = @($restored | ForEach-Object { $_.sha256 } | Sort-Object)
        if (($before -join ',') -ne ($after -join ',')) {
            throw 'The restored installed APK set does not match the preserved hashes.'
        }
    } finally {
        if (Test-Path -LiteralPath $verificationRoot) {
            Remove-Item -LiteralPath $verificationRoot -Recurse -Force
        }
    }
}

function Get-MemorySample {
    param([double]$ElapsedSeconds)
    $appProcessId = Get-AppProcessId
    if ([string]::IsNullOrWhiteSpace($appProcessId)) {
        throw 'The release app stopped while collecting memory evidence.'
    }
    $text = (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'meminfo', $appProcessId)) -join "`n"
    $pss = [regex]::Match($text, 'TOTAL PSS:\s+([\d,]+)')
    $rss = [regex]::Match($text, 'TOTAL RSS:\s+([\d,]+)')
    if (-not $pss.Success -or -not $rss.Success) {
        throw 'Unable to parse bounded TOTAL PSS/RSS memory evidence.'
    }
    return [ordered]@{
        elapsed_seconds = [math]::Round($ElapsedSeconds, 3)
        rss_mib = [math]::Round(([double]($rss.Groups[1].Value -replace ',', '') / 1024), 3)
        pss_mib = [math]::Round(([double]($pss.Groups[1].Value -replace ',', '') / 1024), 3)
    }
}

function Test-ReleaseCrash {
    $appLog = Get-AppLog
    $crashLog = (Invoke-Adb -AdbArguments @('logcat', '-b', 'crash', '-d')) -join "`n"
    $signatures = $appLog.Contains('FATAL EXCEPTION') -or
        $appLog.Contains('Fatal signal') -or
        $appLog.Contains('UnsatisfiedLinkError') -or
        ($crashLog.Contains($packageName) -and (
            $crashLog.Contains('FATAL EXCEPTION') -or
            $crashLog.Contains('Fatal signal') -or
            $crashLog.Contains('UnsatisfiedLinkError')
        ))
    if ($signatures) { throw 'Android logs contain an app-owned release crash signature.' }
}

try {
    & $AdbPath connect $Endpoint | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'SDK ADB could not connect to the approved endpoint.' }
    $apiLevel = [int](((Invoke-Adb -AdbArguments @('shell', 'getprop', 'ro.build.version.sdk')) -join '').Trim())
    $abi = ((Invoke-Adb -AdbArguments @('shell', 'getprop', 'ro.product.cpu.abi')) -join '').Trim()
    $physicalSize = [regex]::Match(
        ((Invoke-Adb -AdbArguments @('shell', 'wm', 'size')) -join ' '),
        'Physical size:\s*(\d+x\d+)'
    ).Groups[1].Value
    $densityDpi = [int]([regex]::Match(
        ((Invoke-Adb -AdbArguments @('shell', 'wm', 'density')) -join ' '),
        'Physical density:\s*(\d+)'
    ).Groups[1].Value)
    if ($apiLevel -ne 35 -or $abi -ne 'x86_64' -or
        $physicalSize -ne '1080x1920' -or $densityDpi -ne 480) {
        throw 'The endpoint does not match the approved API 35 x86_64 1080x1920@480 emulator.'
    }
    $originalInstalled = Test-PackageInstalled
    if ($originalInstalled) {
        $originalRunning = -not [string]::IsNullOrWhiteSpace((Get-AppProcessId))
        $originalPermission = Get-PermissionState
        $originalAppOp = Get-AppOpState
        $originalPackages = Save-InstalledPackage -Destination (Join-Path $temporaryRoot 'original')
    }

    if (-not $SkipBuild) {
        & $FlutterPath build apk --release --target $gateTarget
        if ($LASTEXITCODE -ne 0) { throw 'Unable to build the P4-08 release APK.' }
    }
    if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
        throw 'The P4-08 release APK was not found.'
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ApkPath))
    try {
        $x86Library = $archive.Entries | Where-Object {
            $_.FullName -eq 'lib/x86_64/librust_lib_voice_trainer.so'
        }
        if ($null -eq $x86Library) { throw 'Release APK is missing the x86_64 Rust library.' }
    } finally {
        $archive.Dispose()
    }
    $apkFile = Get-Item -LiteralPath $ApkPath
    $apkHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash.ToLowerInvariant()

    Invoke-Adb -AdbArguments @('install', '-r', (Resolve-Path -LiteralPath $ApkPath).Path) | Out-Null
    $gateInstalled = $true

    Set-PermissionState -Granted 'false' -AppOp 'deny'
    Invoke-Adb -AdbArguments @('logcat', '-c') | Out-Null
    Start-GateApp
    Wait-AppLog -Pattern 'P4_08_PERMISSION_DENIED_OK' -TimeoutSeconds 30 | Out-Null
    Test-ReleaseCrash

    Set-PermissionState -Granted 'true' -AppOp 'allow'
    Invoke-Adb -AdbArguments @('logcat', '-c') | Out-Null
    Start-GateApp
    Wait-AppLog -Pattern 'P4_08_STABILITY_RUNNING' -TimeoutSeconds 60 | Out-Null

    $memorySamples = [System.Collections.Generic.List[object]]::new()
    $runStart = [DateTime]::UtcNow
    $nextMemoryAt = 0.0
    $backgroundSent = $false
    $metrics = $null
    $deadline = $runStart.AddSeconds(760)
    while ([DateTime]::UtcNow -lt $deadline) {
        $elapsed = ([DateTime]::UtcNow - $runStart).TotalSeconds
        if ($elapsed -ge $nextMemoryAt) {
            $memorySamples.Add((Get-MemorySample -ElapsedSeconds $elapsed))
            $nextMemoryAt += 30
        }
        if (-not $backgroundSent -and $elapsed -ge 30) {
            Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', '3') | Out-Null
            Start-Sleep -Seconds 3
            Invoke-Adb -AdbArguments @('shell', 'monkey', '-p', $packageName, '1') | Out-Null
            $backgroundSent = $true
        }
        $observed = Get-AppLog
        if ($observed.Contains('P4_08_RELEASE_GATE_FAILED')) {
            throw 'The ten-minute release run reported failure.'
        }
        if ($observed.Contains('P4_08_READY_FOR_RESTART')) {
            $metricMatches = [regex]::Matches(
                $observed,
                'P4_08_(?:METRICS|READY_FOR_RESTART)\s+(\{[^\r\n<]+\})'
            )
            if ($metricMatches.Count -eq 0) { throw 'Release metrics were not emitted.' }
            $metrics = $metricMatches[$metricMatches.Count - 1].Groups[1].Value |
                ConvertFrom-Json
            break
        }
        Start-Sleep -Seconds 2
    }
    if ($null -eq $metrics) { throw 'Timed out waiting for the ten-minute release run.' }
    if (-not $backgroundSent -or
        $metrics.manual_pause_resume -ne $true -or
        $metrics.background_observed -ne $true -or
        $metrics.foreground_observed -ne $true) {
        throw 'Pause/resume or background/foreground evidence is incomplete.'
    }
    Test-ReleaseCrash

    Invoke-Adb -AdbArguments @('logcat', '-c') | Out-Null
    Start-GateApp
    Wait-AppLog -Pattern 'P4_08_RESTART_DELETE_OK' -TimeoutSeconds 60 | Out-Null
    Test-ReleaseCrash

    $metrics | Add-Member -NotePropertyName memory_samples -NotePropertyValue @($memorySamples)
    $commit = (& git rev-parse --short=12 HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve the tested Git commit.' }
    $passedScenarios = @(
        'cold_start',
        'permission_denied',
        'permission_granted',
        'synthetic_session_start_pause_resume_stop',
        'result_history_recording_delete',
        'background_foreground',
        'process_force_stop_relaunch',
        'ten_minute_stability'
    )
    $scenarios = @($passedScenarios | ForEach-Object {
        [ordered]@{
            scenario_id = $_
            evidence_kind = if ($_ -eq 'cold_start' -or $_ -eq 'process_force_stop_relaunch') {
                'release_emulator'
            } else { 'synthetic' }
            result = [ordered]@{
                status = 'pass'
                reason = 'The deterministic release emulator gate passed.'
            }
            uncovered_reasons = @()
        }
    })
    $scenarios += [ordered]@{
        scenario_id = 'real_microphone'
        evidence_kind = 'capture_only'
        result = [ordered]@{
            status = 'pending'
            reason = 'The emulator cannot establish real microphone or voice evidence.'
        }
        uncovered_reasons = @(
            'A physical Android microphone, route, AGC, latency, and voiced input were not exercised.'
        )
    }
    $bundle = [ordered]@{
        schema_version = 'P4_08_ANDROID_EMULATOR_BASELINE_V1'
        commit = $commit
        captured_on = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
        build_mode = 'release'
        environment = [ordered]@{
            evidence_type = 'emulator'
            endpoint = $Endpoint
            emulator = $true
            real_device = $false
            real_microphone = $false
            root_used = $false
            api_level = $apiLevel
            abi = $abi
            physical_size = $physicalSize
            density_dpi = $densityDpi
        }
        artifact = [ordered]@{
            sha256 = $apkHash
            byte_length = $apkFile.Length
            x86_64_rust_library = $true
        }
        scenarios = $scenarios
        stability_metrics = $metrics
    }
    $evidenceDirectory = Split-Path -Parent $EvidencePath
    if (-not [string]::IsNullOrWhiteSpace($evidenceDirectory)) {
        New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
    }
    $bundle | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $EvidencePath -Encoding utf8
    & dart run tool/p4_08_android_evidence.dart validate $EvidencePath
    if ($LASTEXITCODE -ne 0) { throw 'The P4-08 evidence validator rejected the bundle.' }
    $bundle | ConvertTo-Json -Depth 8 -Compress
} finally {
    try {
        if ($gateInstalled -and (Test-PackageInstalled)) {
            Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $packageName) | Out-Null
        }
        Restore-InstalledPackage
        if ($originalInstalled) {
            Set-PermissionState -Granted $originalPermission -AppOp $originalAppOp
            if ($originalRunning) {
                Invoke-Adb -AdbArguments @('shell', 'monkey', '-p', $packageName, '1') | Out-Null
            } else {
                Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $packageName) | Out-Null
            }
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            $resolvedTemporary = (Resolve-Path -LiteralPath $temporaryRoot).Path
            $resolvedSystemTemporary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
            if (-not $resolvedTemporary.StartsWith($resolvedSystemTemporary, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Refusing to remove a temporary path outside the system temporary directory.'
            }
            Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
        }
    }
}
