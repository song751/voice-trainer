param(
    [Parameter(Mandatory = $true)]
    [string]$Endpoint,
    [ValidateSet('allow', 'deny')]
    [string]$Permission = 'allow',
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    [string]$FlutterPath = 'flutter',
    [string]$TestPath = 'integration_test\p4_03_android_capture_smoke_test.dart',
    [string]$ApkPath = 'build\app\outputs\flutter-apk\app-debug.apk'
)

$ErrorActionPreference = 'Stop'
$packageName = 'com.local.voice_trainer'
$recordPermission = 'android.permission.RECORD_AUDIO'

if ($Endpoint -notmatch '^[A-Za-z0-9.-]+:\d{1,5}$') {
    throw 'Endpoint must be an explicit host:port value.'
}
if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    throw 'Android SDK Platform-Tools adb.exe was not found. Pass -AdbPath explicitly.'
}
if (-not (Test-Path -LiteralPath $TestPath -PathType Leaf)) {
    throw 'The Android integration test was not found. Pass -TestPath explicitly.'
}

$flutterCommand = Get-Command $FlutterPath -ErrorAction Stop
$flutterExecutable = $flutterCommand.Source
$stdoutPath = Join-Path $env:TEMP "voice-trainer-android-$([Guid]::NewGuid()).stdout.log"
$stderrPath = Join-Path $env:TEMP "voice-trainer-android-$([Guid]::NewGuid()).stderr.log"
$process = $null
$permissionApplied = $false

function Test-PackageInstalled {
    $pathOutput = & $AdbPath -s $Endpoint shell pm path $packageName 2>$null
    return $LASTEXITCODE -eq 0 -and (($pathOutput -join '') -match '^package:')
}

function Set-RecordingPermission {
    & $AdbPath -s $Endpoint shell pm clear-permission-flags $packageName $recordPermission user-set user-fixed | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clear prior RECORD_AUDIO decision flags.' }
    if ($Permission -eq 'allow') {
        & $AdbPath -s $Endpoint shell pm grant $packageName $recordPermission | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to grant RECORD_AUDIO with standard SDK ADB.' }
        & $AdbPath -s $Endpoint shell appops set $packageName RECORD_AUDIO allow | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to set the RECORD_AUDIO app-op to allow.' }
    } else {
        & $AdbPath -s $Endpoint shell pm revoke $packageName $recordPermission | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to revoke RECORD_AUDIO with standard SDK ADB.' }
        & $AdbPath -s $Endpoint shell appops set $packageName RECORD_AUDIO deny | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to set the RECORD_AUDIO app-op to deny.' }
        & $AdbPath -s $Endpoint shell pm set-permission-flags $packageName $recordPermission user-set user-fixed | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to fix the denied permission state for the test.' }
    }
}

try {
    & $AdbPath connect $Endpoint | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'SDK ADB could not connect to the explicit endpoint.' }

    # Preinstall the same signed debug package and set its permission before
    # Flutter starts the instrumentation app. `flutter test` uses a replace
    # install, so Android retains this decision and no permission UI races the
    # test body. The polling below reapplies it if a toolchain replaces state.
    & $flutterExecutable build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'Unable to build the debug APK used for permission pre-seeding.' }
    if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
        throw 'The debug APK was not found after the build.'
    }
    & $AdbPath -s $Endpoint install -r (Resolve-Path -LiteralPath $ApkPath) | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'SDK ADB could not preinstall the debug APK.' }
    Set-RecordingPermission

    $arguments = @(
        'test',
        (Resolve-Path -LiteralPath $TestPath).Path,
        '-d',
        $Endpoint,
        "--dart-define=P4_03_PERMISSION=$Permission"
    )
    $process = Start-Process `
        -FilePath $flutterExecutable `
        -ArgumentList $arguments `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -PassThru

    $deadline = [DateTime]::UtcNow.AddMinutes(5)
    while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        if (Test-PackageInstalled) {
            Set-RecordingPermission
            $permissionApplied = $true
            break
        }
        Start-Sleep -Milliseconds 100
        $process.Refresh()
    }
    if (-not $permissionApplied) {
        if (-not $process.HasExited) { $process.Kill($true) }
        throw 'The test package did not appear before the permission deadline.'
    }

    $process.WaitForExit()
    Get-Content -LiteralPath $stdoutPath
    Get-Content -LiteralPath $stderrPath
    if ($process.ExitCode -ne 0) {
        throw "Flutter integration test failed with exit code $($process.ExitCode)."
    }

    [pscustomobject]@{
        evidenceType = 'emulator'
        emulator = $true
        realDevice = $false
        endpoint = $Endpoint
        permission = $Permission
        permissionMethod = 'sdk-adb-pm-and-appops'
        rootUsed = $false
        testPassed = $true
    } | ConvertTo-Json -Compress
} finally {
    if ($null -ne $process -and -not $process.HasExited) {
        $process.Kill($true)
    }
    foreach ($temporaryPath in @($stdoutPath, $stderrPath)) {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}
