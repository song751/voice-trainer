param(
    [Parameter(Mandatory = $true)]
    [string]$Endpoint,
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    [string]$FlutterPath = 'flutter',
    [string]$DartPath = 'dart',
    [string]$EvidencePath = 'build\p4_05_android_evidence.json',
    [string]$HttpsProxy,
    [ValidateRange(1024, 65535)]
    [int]$AdbServerPort = 5041
)

$ErrorActionPreference = 'Stop'
$approvedEndpoint = '127.0.0.1:16384'
$packageName = 'com.local.voice_trainer'
$recordPermission = 'android.permission.RECORD_AUDIO'
$gateTarget = 'tool\p4_05_android_lifecycle_main.dart'
$apkPath = 'build\app\outputs\flutter-apk\app-debug.apk'
$gateRelativeRoot = 'files/p4_05_gate'
$faultRelativePath = "$gateRelativeRoot/fault_target"
$originalInstalled = $false
$originalRunning = $false
$originalPermission = $null
$originalAppOp = $null
$originalFaultMode = $null
$gateInstalled = $false
$gateDirectoryCreated = $false
$originalHttpProxy = $env:HTTP_PROXY
$originalHttpsProxy = $env:HTTPS_PROXY
$originalAdbServerPort = $env:ANDROID_ADB_SERVER_PORT
$env:ANDROID_ADB_SERVER_PORT = $AdbServerPort.ToString()

if ($Endpoint -ne $approvedEndpoint) {
    throw "P4-05 is restricted to the repository owner's approved vertical MuMu endpoint $approvedEndpoint."
}
if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    throw 'Android SDK Platform-Tools adb.exe was not found. Pass -AdbPath explicitly.'
}
if (-not (Test-Path -LiteralPath $gateTarget -PathType Leaf)) {
    throw 'The P4-05 gate-only entry point was not found.'
}
if (-not [string]::IsNullOrWhiteSpace($HttpsProxy)) {
    $proxyUri = $null
    if (-not [Uri]::TryCreate($HttpsProxy, [UriKind]::Absolute, [ref]$proxyUri) -or
        $proxyUri.Scheme -notin @('http', 'https')) {
        throw 'HttpsProxy must be an explicit HTTP(S) proxy URI.'
    }
    # Process-scoped only. Dart's sqlite3 hook validates the official binary's
    # pinned SHA-256 after download, and TLS verification remains enabled.
    $env:HTTP_PROXY = $HttpsProxy
    $env:HTTPS_PROXY = $HttpsProxy
}

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $output = & $AdbPath -s $Endpoint @Arguments
    if ($LASTEXITCODE -ne 0) {
        & $AdbPath start-server 2>$null | Out-Null
        & $AdbPath connect $Endpoint 2>$null | Out-Null
        $output = & $AdbPath -s $Endpoint @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "SDK ADB command failed after one reconnect: $($Arguments -join ' ')"
        }
    }
    return $output
}

function Test-PackageInstalled {
    $output = & $AdbPath -s $Endpoint shell pm path $packageName 2>$null
    return $LASTEXITCODE -eq 0 -and (($output -join '') -match '^package:')
}

function Get-PermissionState {
    $dump = Invoke-Adb shell dumpsys package $packageName
    $match = $dump | Select-String -Pattern 'android\.permission\.RECORD_AUDIO: granted=(true|false)' | Select-Object -First 1
    if ($null -eq $match) { throw 'Unable to read the original RECORD_AUDIO permission state.' }
    return $match.Matches[0].Groups[1].Value
}

function Get-AppOpState {
    $output = (Invoke-Adb shell appops get $packageName RECORD_AUDIO) -join "`n"
    $match = [regex]::Match($output, 'RECORD_AUDIO:\s+(allow|deny|ignore|default|foreground)')
    if (-not $match.Success) { throw 'Unable to read the original RECORD_AUDIO app-op state.' }
    return $match.Groups[1].Value
}

function Set-PermissionState {
    param([ValidateSet('true', 'false')][string]$Granted, [string]$AppOp)
    Invoke-Adb shell pm clear-permission-flags $packageName $recordPermission user-set user-fixed | Out-Null
    if ($Granted -eq 'true') {
        Invoke-Adb shell pm grant $packageName $recordPermission | Out-Null
    } else {
        Invoke-Adb shell pm revoke $packageName $recordPermission | Out-Null
    }
    Invoke-Adb shell appops set $packageName RECORD_AUDIO $AppOp | Out-Null
}

function Start-GateApp {
    Invoke-Adb shell am force-stop $packageName | Out-Null
    Invoke-Adb -Arguments @(
        'shell', 'am', 'start', '-W', '-n', "$packageName/.MainActivity"
    ) | Out-Null
}

function Get-AppProcessId {
    $output = & $AdbPath -s $Endpoint shell pidof $packageName 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return (($output -join '').Trim())
}

function Wait-ForSentinels {
    param([string[]]$Sentinels, [int]$TimeoutSeconds = 40)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $lastLog = ''
    while ([DateTime]::UtcNow -lt $deadline) {
        $appProcessId = Get-AppProcessId
        $log = if ([string]::IsNullOrWhiteSpace($appProcessId)) {
            ''
        } else {
            (Invoke-Adb -Arguments @(
                'shell', 'logcat', '-d', "--pid=$appProcessId"
            )) -join "`n"
        }
        $lastLog = $log
        $allPresent = $true
        foreach ($sentinel in $Sentinels) {
            if (-not $log.Contains($sentinel)) { $allPresent = $false; break }
        }
        if ($allPresent) { return $log }
        Start-Sleep -Milliseconds 300
    }
    $observed = [regex]::Matches($lastLog, 'P4_05_[A-Z_]+') |
        ForEach-Object { $_.Value } |
        Select-Object -Unique
    Write-Host "Last observed P4-05 sentinels: $($observed -join ', ')."
    throw "Timed out waiting for gate sentinel(s): $($Sentinels -join ', ')."
}

try {
    & $AdbPath connect $Endpoint | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'SDK ADB could not connect to the approved endpoint.' }
    $api = ((Invoke-Adb shell getprop ro.build.version.sdk) -join '').Trim()
    $abi = ((Invoke-Adb shell getprop ro.product.cpu.abi) -join '').Trim()
    $size = ((Invoke-Adb shell wm size) -join ' ')
    $density = ((Invoke-Adb shell wm density) -join ' ')
    if ($api -ne '35' -or $abi -ne 'x86_64' -or $size -notmatch '1080x1920' -or $density -notmatch '480') {
        throw 'The endpoint does not match the approved API 35 x86_64 1080x1920@480 emulator profile.'
    }

    $originalInstalled = Test-PackageInstalled
    if ($originalInstalled) {
        $originalRunning = -not [string]::IsNullOrWhiteSpace(
            (Get-AppProcessId)
        )
        $originalPermission = Get-PermissionState
        $originalAppOp = Get-AppOpState
    }

    & $FlutterPath build apk --debug --target $gateTarget
    if ($LASTEXITCODE -ne 0) { throw 'Unable to build the P4-05 debug gate APK.' }
    Invoke-Adb -Arguments @(
        'install', '-r', (Resolve-Path -LiteralPath $apkPath)
    ) | Out-Null
    $gateInstalled = $true
    if (-not $originalInstalled) {
        $originalPermission = Get-PermissionState
        $originalAppOp = Get-AppOpState
    }

    # Remove only the gate-owned relative directory inside this debuggable
    # package. Product recordings, database files and other app data remain.
    Invoke-Adb -Arguments @(
        'shell', 'run-as', $packageName, 'rm', '-rf', $gateRelativeRoot
    ) | Out-Null

    Set-PermissionState -Granted 'true' -AppOp 'allow'
    if ((Get-PermissionState) -ne 'true') { throw 'ADB permission allow was not observed.' }
    Set-PermissionState -Granted 'false' -AppOp 'deny'
    if ((Get-PermissionState) -ne 'false') { throw 'ADB permission deny was not observed.' }
    Set-PermissionState -Granted 'true' -AppOp 'allow'

    Invoke-Adb -Arguments @('logcat', '-c') | Out-Null
    Start-GateApp
    Wait-ForSentinels @('P4_05_READY', 'P4_05_PHASE_FOREGROUND') | Out-Null
    $gateDirectoryCreated = $true
    Write-Host 'P4-05 gate ready.'

    Invoke-Adb shell input keyevent KEYCODE_HOME | Out-Null
    Start-Sleep -Seconds 2
    $originalFaultMode = ((Invoke-Adb -Arguments @(
        'shell', 'run-as', $packageName, 'stat', '-c', '%a', $faultRelativePath
    )) -join '').Trim()
    if ($originalFaultMode -notmatch '^\d{3,4}$') { throw 'Unable to capture the original fault-directory mode.' }
    Invoke-Adb shell run-as $packageName chmod 500 $faultRelativePath | Out-Null
    Invoke-Adb -Arguments @(
        'shell', 'am', 'start', '-W', '-n', "$packageName/.MainActivity"
    ) | Out-Null
    Wait-ForSentinels @(
        'P4_05_BACKGROUND_FOREGROUND_OK',
        'P4_05_STORAGE_RECORDINGUNAVAILABLE'
    ) | Out-Null
    Write-Host 'P4-05 lifecycle and storage fault sentinels observed.'
    Invoke-Adb shell run-as $packageName chmod $originalFaultMode $faultRelativePath | Out-Null
    $originalFaultMode = $null

    Start-GateApp
    Wait-ForSentinels @(
        'P4_05_PROCESS_RESTORED',
        'P4_05_PARTIAL_RECOVERED'
    ) | Out-Null
    Write-Host 'P4-05 process and partial recovery sentinels observed.'

    $appProcessId = ((Invoke-Adb shell pidof $packageName) -join '').Trim()
    if ([string]::IsNullOrWhiteSpace($appProcessId)) { throw 'Gate app did not remain running.' }
    $appLog = Invoke-Adb -Arguments @(
        'shell', 'logcat', '-d', "--pid=$appProcessId"
    )
    $crashLog = (Invoke-Adb -Arguments @(
        'shell', 'logcat', '-b', 'crash', '-d'
    )) -join "`n"
    if (($appLog | Select-String -SimpleMatch -Pattern 'FATAL EXCEPTION', 'Fatal signal') -or
        ($crashLog.Contains($packageName) -and
            ($crashLog.Contains('FATAL EXCEPTION') -or $crashLog.Contains('Fatal signal')))) {
        throw 'Android logcat contains an app crash signature.'
    }

    $commit = (git rev-parse HEAD).Trim()
    $pendingCall = 'Emulator automation cannot produce a real telephony interruption.'
    $pendingBluetooth = 'No physical Bluetooth route is present in emulator evidence.'
    $pendingHardware = 'No physical wired or hardware route change is present in emulator evidence.'
    $bundle = [ordered]@{
        schema_version = 'P4_05_ANDROID_EVIDENCE_V1'
        schema_family = 'P3'
        commit = $commit
        captured_on = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
        build_mode = 'debug'
        environment = [ordered]@{
            evidence_type = 'emulator'
            endpoint = $approvedEndpoint
            emulator = $true
            real_device = $false
            root_used = $false
            api = 35
            abi = 'x86_64'
            viewport = '1080x1920@480'
        }
        scenarios = @(
            [ordered]@{scenario_id='permission_allow_deny';evidence_kind='capture_only';root_used=$false;typed_result='permissionDenied';result=[ordered]@{status='pass';reason='SDK ADB grant/revoke and appops allow/deny were observed without a dialog.'};uncovered_reasons=@('Does not prove runtime revocation on a physical device.')},
            [ordered]@{scenario_id='background_foreground';evidence_kind='capture_only';root_used=$false;typed_result='paused-resumed-discontinuity';result=[ordered]@{status='pass';reason='HOME and explicit relaunch produced application background/foreground sentinels.'};uncovered_reasons=@('Emulator scheduling is not physical-device scheduling evidence.')},
            [ordered]@{scenario_id='process_force_stop_relaunch';evidence_kind='capture_only';root_used=$false;typed_result='restored';result=[ordered]@{status='pass';reason='am force-stop and relaunch restored the gate marker.'};uncovered_reasons=@('Does not cover vendor task killers on a physical device.')},
            [ordered]@{scenario_id='storage_read_only';evidence_kind='synthetic';root_used=$false;typed_result='recordingUnavailable';result=[ordered]@{status='pass';reason='Only the gate-owned sandbox directory was made read-only and recording failure stayed typed.'};uncovered_reasons=@('Mode injection is not a real quota-exhaustion event.')},
            [ordered]@{scenario_id='partial_recovery';evidence_kind='synthetic';root_used=$false;typed_result='partial-removed';result=[ordered]@{status='pass';reason='A gate partial was removed after force-stop and relaunch.'};uncovered_reasons=@('The broader database tombstone matrix remains covered by P4-04 automation.')},
            [ordered]@{scenario_id='incoming_call';evidence_kind='capture_only';root_used=$false;typed_result='pending';result=[ordered]@{status='pending';reason=$pendingCall};uncovered_reasons=@($pendingCall)},
            [ordered]@{scenario_id='bluetooth_route';evidence_kind='capture_only';root_used=$false;typed_result='pending';result=[ordered]@{status='pending';reason=$pendingBluetooth};uncovered_reasons=@($pendingBluetooth)},
            [ordered]@{scenario_id='hardware_route';evidence_kind='capture_only';root_used=$false;typed_result='pending';result=[ordered]@{status='pending';reason=$pendingHardware};uncovered_reasons=@($pendingHardware)}
        )
    }
    $evidenceDirectory = Split-Path -Parent $EvidencePath
    if (-not [string]::IsNullOrWhiteSpace($evidenceDirectory)) {
        New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
    }
    $bundle | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $EvidencePath -Encoding utf8
    & $DartPath run tool/p4_05_android_evidence.dart validate $EvidencePath
    if ($LASTEXITCODE -ne 0) { throw 'P4-05 evidence validation failed.' }
    $bundle | ConvertTo-Json -Depth 8 -Compress
} finally {
    if ($gateInstalled) {
        & $AdbPath -s $Endpoint shell am force-stop $packageName 2>$null | Out-Null
        if ($gateDirectoryCreated) {
            if ($null -ne $originalFaultMode) {
                & $AdbPath -s $Endpoint shell run-as $packageName chmod $originalFaultMode $faultRelativePath 2>$null | Out-Null
            }
            & $AdbPath -s $Endpoint shell run-as $packageName rm -rf $gateRelativeRoot 2>$null | Out-Null
        }
        if ($null -ne $originalPermission -and $null -ne $originalAppOp) {
            try { Set-PermissionState -Granted $originalPermission -AppOp $originalAppOp } catch { Write-Warning $_ }
        }
        if ($originalInstalled) {
            & $FlutterPath build apk --debug 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                & $AdbPath -s $Endpoint install -r (Resolve-Path -LiteralPath $apkPath) 2>$null | Out-Null
                if ($originalRunning) {
                    & $AdbPath -s $Endpoint shell am start -W -n "$packageName/.MainActivity" 2>$null | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning 'The restored normal application was not relaunched.'
                    }
                }
            } else {
                Write-Warning 'The normal debug application could not be rebuilt after the gate.'
            }
        } else {
            & $AdbPath -s $Endpoint uninstall $packageName 2>$null | Out-Null
        }
    }
    $env:HTTP_PROXY = $originalHttpProxy
    $env:HTTPS_PROXY = $originalHttpsProxy
    $env:ANDROID_ADB_SERVER_PORT = $originalAdbServerPort
}
