param(
    [int]$ServerPort = 7396,
    [int]$DebugPort = 9226,
    [string]$EdgePath = '',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($EdgePath)) {
    $edgeCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
    )
    $EdgePath = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($EdgePath) -or -not (Test-Path -LiteralPath $EdgePath -PathType Leaf)) {
    throw 'Microsoft Edge was not found; pass -EdgePath explicitly.'
}

$tempRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('voice-trainer-p4-10-' + [Guid]::NewGuid().ToString('N'))))
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $tempRoot.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or
    -not ([IO.Path]::GetFileName($tempRoot)).StartsWith('voice-trainer-p4-10-', [StringComparison]::Ordinal)) {
    throw 'Refusing to use an unverified temporary directory.'
}
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$server = $null
$serverListenerPid = $null
$edge = $null
try {
    Push-Location $repoRoot
    if (-not $SkipBuild) {
        # Keep this storage gate independent from external CanvasKit/CDN
        # reachability. P4-11 owns the production deployment/cache contract.
        & flutter build web --release --no-web-resources-cdn --target tool/p4_10_web_persistence_main.dart
        if ($LASTEXITCODE -ne 0) { throw "Flutter Web persistence smoke build failed with exit code $LASTEXITCODE." }
    }
    & node --check web/recording_store_client.js
    if ($LASTEXITCODE -ne 0) { throw 'recording_store_client.js syntax validation failed.' }
    & node tool/p4_10_recording_store_contract_test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Recording store contract test failed.' }

    $server = Start-Process -FilePath 'dart' -ArgumentList @(
        'run', 'tool/p4_09_web_server.dart', $ServerPort, 'build/web'
    ) -WorkingDirectory $repoRoot -RedirectStandardOutput (Join-Path $tempRoot 'server.stdout.log') -RedirectStandardError (Join-Path $tempRoot 'server.stderr.log') -WindowStyle Hidden -PassThru
    for ($attempt = 0; $attempt -lt 100; $attempt += 1) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$ServerPort/" -TimeoutSec 1
            if ($response.StatusCode -eq 200) { break }
        } catch {}
        if ($attempt -eq 99) { throw 'P4-10 local server did not become ready.' }
        Start-Sleep -Milliseconds 100
    }
    $serverListenerPid = (Get-NetTCPConnection -LocalPort $ServerPort -State Listen -ErrorAction Stop | Select-Object -First 1).OwningProcess

    $edge = Start-Process -FilePath $EdgePath -ArgumentList @(
        '--headless=new',
        '--no-first-run',
        '--disable-background-networking',
        "--remote-debugging-port=$DebugPort",
        "--user-data-dir=$tempRoot",
        'about:blank'
    ) -WindowStyle Hidden -PassThru
    for ($attempt = 0; $attempt -lt 100; $attempt += 1) {
        try {
            $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$DebugPort/json/list" -TimeoutSec 1
            if ($targets.Count -gt 0) { break }
        } catch {}
        if ($attempt -eq 99) { throw 'Edge CDP endpoint did not become ready.' }
        Start-Sleep -Milliseconds 100
    }

    & node tool/p4_10_edge_persistence_gate.mjs $DebugPort "http://127.0.0.1:$ServerPort/"
    if ($LASTEXITCODE -ne 0) { throw 'Browser persistence/reload/delete gate failed.' }
}
finally {
    Pop-Location
    if ($edge -and -not $edge.HasExited) { Stop-Process -Id $edge.Id -Force -ErrorAction SilentlyContinue }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    if ($serverListenerPid) {
        $listenerProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$serverListenerPid" -ErrorAction SilentlyContinue
        if ($listenerProcess -and $listenerProcess.CommandLine -like '*tool\p4_09_web_server.dart*') {
            Stop-Process -Id $serverListenerPid -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Milliseconds 200
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
