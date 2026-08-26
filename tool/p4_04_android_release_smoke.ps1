param(
    [Parameter(Mandatory = $true)]
    [string]$Endpoint,
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    [string]$ApkPath = 'build\app\outputs\flutter-apk\app-release.apk'
)

$ErrorActionPreference = 'Stop'
$packageName = 'com.local.voice_trainer'
$expectedSentinels = @(
    'P4_04_RELEASE_PERSISTENCE_CREATED',
    'P4_04_RELEASE_PERSISTENCE_RESTORED'
)

if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    throw 'Android SDK Platform-Tools adb.exe was not found. Pass -AdbPath explicitly.'
}
if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    throw 'Release APK was not found. Run flutter build apk --release first.'
}
if ($Endpoint -notmatch '^[A-Za-z0-9.-]+:\d{1,5}$') {
    throw 'Endpoint must be an explicit host:port value.'
}

& $AdbPath connect $Endpoint
if ($LASTEXITCODE -ne 0) { throw 'SDK ADB could not connect to the explicit endpoint.' }
& $AdbPath -s $Endpoint install -r (Resolve-Path -LiteralPath $ApkPath)
if ($LASTEXITCODE -ne 0) { throw 'SDK ADB could not install the release APK.' }
& $AdbPath -s $Endpoint shell pm clear $packageName | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to clear the release probe app sandbox.' }

for ($restartIndex = 0; $restartIndex -lt $expectedSentinels.Count; $restartIndex += 1) {
    $attempt = $restartIndex + 1
    & $AdbPath -s $Endpoint logcat -c
    if ($LASTEXITCODE -ne 0) { throw "Unable to clear logcat before launch $attempt." }
    & $AdbPath -s $Endpoint shell am force-stop $packageName
    if ($LASTEXITCODE -ne 0) { throw "Unable to force-stop release app (launch $attempt)." }
    & $AdbPath -s $Endpoint shell monkey -p $packageName 1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unable to launch release app (launch $attempt)." }
    Start-Sleep -Seconds 2
    $appProcessId = (& $AdbPath -s $Endpoint shell pidof $packageName).Trim()
    if ([string]::IsNullOrWhiteSpace($appProcessId)) {
        throw "Release app did not remain running after launch $attempt."
    }

    & $AdbPath -s $Endpoint shell uiautomator dump /sdcard/p4_04_window.xml | Out-Null
    # MuMu may return 139 after successfully writing the hierarchy, so the
    # readable sentinel file is the actual contract rather than that exit code.
    $windowXml = (& $AdbPath -s $Endpoint exec-out cat /sdcard/p4_04_window.xml) -join ''
    $expected = $expectedSentinels[$restartIndex]
    if ($LASTEXITCODE -ne 0 -or $windowXml -notmatch $expected) {
        throw "Release persistence sentinel was not visible after launch $attempt."
    }

    $appLog = & $AdbPath -s $Endpoint logcat -d "--pid=$appProcessId"
    if ($LASTEXITCODE -ne 0) { throw "Unable to read app logcat after launch $attempt." }
    $crashLog = & $AdbPath -s $Endpoint logcat -b crash -d
    if ($LASTEXITCODE -ne 0) { throw "Unable to read crash log after launch $attempt." }
    # Android's loader always emits APK and sandbox paths. The privacy gate is
    # specifically for application-authored Flutter logs, not OS loader lines.
    $flutterAppLog = $appLog | Where-Object { $_ -match '\s[VDIWEF]\s+flutter\s*:' }
    $absolutePathLeaks = $flutterAppLog |
        Select-String -Pattern '/data/(user|data)/', '/storage/emulated/'
    if ($absolutePathLeaks) {
        throw "App logcat exposed an absolute persistence path after launch $attempt."
    }
    $appCrashSignatures = $appLog |
        Select-String -SimpleMatch -Pattern 'FATAL EXCEPTION', 'Fatal signal'
    $crashText = $crashLog -join "`n"
    $packageCrash = $crashText.Contains($packageName) -and (
        $crashText.Contains('FATAL EXCEPTION') -or
        $crashText.Contains('Fatal signal')
    )
    if ($appCrashSignatures -or $packageCrash) {
        throw "Android logcat contains a crash signature from launch $attempt."
    }
}

[pscustomobject]@{
    evidenceType = 'emulator'
    emulator = $true
    realDevice = $false
    endpoint = $Endpoint
    applicationSupportPersistence = $true
    firstLaunch = 'created'
    forceStopRelaunch = 'restored'
    absolutePersistencePathsInAppLog = 'none'
    crashSignatures = 'none'
} | ConvertTo-Json -Compress
