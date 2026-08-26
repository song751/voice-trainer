param(
    [Parameter(Mandatory = $true)]
    [string]$Endpoint,
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    [string]$ApkPath = 'build\app\outputs\flutter-apk\app-release.apk'
)

$ErrorActionPreference = 'Stop'
$packageName = 'com.local.voice_trainer'

if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    throw 'Android SDK Platform-Tools adb.exe was not found. Pass -AdbPath explicitly.'
}
if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    throw 'Release APK was not found. Run flutter build apk --release first.'
}
if ($Endpoint -notmatch '^[A-Za-z0-9.-]+:\d{1,5}$') {
    throw 'Endpoint must be an explicit host:port value.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ApkPath))
try {
    $rustLibrary = $archive.Entries | Where-Object {
        $_.FullName -match '^lib/x86_64/librust_lib_voice_trainer\.so$'
    }
    if ($null -eq $rustLibrary) {
        throw 'Release APK does not contain the required x86_64 Rust library.'
    }
} finally {
    $archive.Dispose()
}

& $AdbPath connect $Endpoint
if ($LASTEXITCODE -ne 0) { throw 'SDK ADB could not connect to the explicit endpoint.' }
& $AdbPath -s $Endpoint install -r (Resolve-Path -LiteralPath $ApkPath)
if ($LASTEXITCODE -ne 0) { throw 'SDK ADB could not install the release APK.' }

for ($restartIndex = 1; $restartIndex -le 2; $restartIndex += 1) {
    & $AdbPath -s $Endpoint logcat -c
    if ($LASTEXITCODE -ne 0) { throw "Unable to clear logcat before restart $restartIndex." }
    & $AdbPath -s $Endpoint shell am force-stop $packageName
    if ($LASTEXITCODE -ne 0) { throw "Unable to force-stop release app (restart $restartIndex)." }
    & $AdbPath -s $Endpoint shell monkey -p $packageName 1
    if ($LASTEXITCODE -ne 0) { throw "Unable to launch release app (restart $restartIndex)." }
    Start-Sleep -Seconds 2
    $appProcessId = (& $AdbPath -s $Endpoint shell pidof $packageName).Trim()
    if ([string]::IsNullOrWhiteSpace($appProcessId)) {
        throw "Release app did not remain running after restart $restartIndex."
    }

    & $AdbPath -s $Endpoint shell uiautomator dump /sdcard/p4_02_window.xml | Out-Null
    # MuMu may return 139 after successfully writing the hierarchy, so the
    # readable sentinel file is the actual contract rather than that exit code.
    $windowXml = (& $AdbPath -s $Endpoint exec-out cat /sdcard/p4_02_window.xml) -join ''
    if ($LASTEXITCODE -ne 0 -or $windowXml -notmatch 'P4_02_RELEASE_BRIDGE_OK frames=94 samples=2098080') {
        throw "Release Rust bridge sentinel was not visible after restart $restartIndex."
    }

    $appLog = & $AdbPath -s $Endpoint logcat -d "--pid=$appProcessId"
    if ($LASTEXITCODE -ne 0) { throw "Unable to read app logcat after restart $restartIndex." }
    $crashLog = & $AdbPath -s $Endpoint logcat -b crash -d
    if ($LASTEXITCODE -ne 0) { throw "Unable to read crash log after restart $restartIndex." }
    $appCrashSignatures = $appLog |
        Select-String -SimpleMatch -Pattern 'UnsatisfiedLinkError', 'FATAL EXCEPTION', 'Fatal signal'
    $crashText = $crashLog -join "`n"
    $packageCrash = $crashText.Contains($packageName) -and (
        $crashText.Contains('FATAL EXCEPTION') -or
        $crashText.Contains('Fatal signal') -or
        $crashText.Contains('UnsatisfiedLinkError')
    )
    if ($appCrashSignatures -or $packageCrash) {
        throw "Android logcat contains a crash signature from release restart $restartIndex."
    }
}

[pscustomobject]@{
    evidenceType = 'emulator'
    emulator = $true
    realDevice = $false
    endpoint = $Endpoint
    x86_64RustLibrary = $true
    releaseBridgeSentinel = 'P4_02_RELEASE_BRIDGE_OK'
    releaseRestarts = 2
    nativeCrashSignatures = 'none'
} | ConvertTo-Json -Compress
