param(
    [int]$ServerPort = 7394,
    [int]$DebugPort = 9224,
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

$tempRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('voice-trainer-p4-09-' + [Guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$server = $null
$edge = $null
$grantedEdge = $null

try {
    Push-Location $repoRoot
    if (-not $SkipBuild) {
        & flutter build web --release --target tool/p4_09_web_capture_main.dart
        if ($LASTEXITCODE -ne 0) { throw "Flutter Web smoke build failed with exit code $LASTEXITCODE." }
    }
    & dart run tool/verify_frb_web_artifacts.dart
    if ($LASTEXITCODE -ne 0) { throw "Web artifact validation failed with exit code $LASTEXITCODE." }
    & node --check web/analysis_worker_client.js
    if ($LASTEXITCODE -ne 0) { throw 'analysis_worker_client.js syntax validation failed.' }
    & node --check web/analysis_worker.js
    if ($LASTEXITCODE -ne 0) { throw 'analysis_worker.js syntax validation failed.' }

    $serverOut = Join-Path $tempRoot 'server.stdout.log'
    $serverErr = Join-Path $tempRoot 'server.stderr.log'
    $server = Start-Process -FilePath 'dart' -ArgumentList @(
        'run', 'tool/p4_09_web_server.dart', $ServerPort, 'build/web'
    ) -WorkingDirectory $repoRoot -RedirectStandardOutput $serverOut -RedirectStandardError $serverErr -WindowStyle Hidden -PassThru

    $serverReady = $false
    for ($attempt = 0; $attempt -lt 100; $attempt += 1) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$ServerPort/" -TimeoutSec 1
            if ($response.StatusCode -eq 200) { $serverReady = $true; break }
        } catch {}
        Start-Sleep -Milliseconds 100
    }
    if (-not $serverReady) { throw "P4-09 local server did not become ready. $(Get-Content $serverErr -Raw)" }

    $edge = Start-Process -FilePath $EdgePath -ArgumentList @(
        '--headless=new',
        '--no-first-run',
        '--disable-background-networking',
        '--autoplay-policy=no-user-gesture-required',
        '--use-fake-device-for-media-stream',
        "--remote-debugging-port=$DebugPort",
        "--user-data-dir=$tempRoot",
        'about:blank'
    ) -WindowStyle Hidden -PassThru

    $debugReady = $false
    for ($attempt = 0; $attempt -lt 100; $attempt += 1) {
        try {
            $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$DebugPort/json/list" -TimeoutSec 1
            if ($targets.Count -gt 0) { $debugReady = $true; break }
        } catch {}
        Start-Sleep -Milliseconds 100
    }
    if (-not $debugReady) { throw 'Edge CDP endpoint did not become ready.' }

    $origin = "http://127.0.0.1:$ServerPort"
    & node tool/p4_09_edge_capture_gate.mjs $DebugPort "$origin/?mode=denied" 'denied'
    if ($LASTEXITCODE -ne 0) { throw 'Browser permission-denied gate failed.' }
    & node tool/p4_09_edge_worker_gate.mjs $DebugPort $origin
    if ($LASTEXITCODE -ne 0) { throw 'Dedicated Rust worker gate failed.' }

    $grantedDebugPort = $DebugPort + 1
    $grantedProfile = Join-Path $tempRoot 'granted-profile'
    New-Item -ItemType Directory -Path $grantedProfile | Out-Null
    $grantedEdge = Start-Process -FilePath $EdgePath -ArgumentList @(
        '--headless=new',
        '--no-first-run',
        '--disable-background-networking',
        '--autoplay-policy=no-user-gesture-required',
        '--use-fake-device-for-media-stream',
        '--use-fake-ui-for-media-stream',
        "--remote-debugging-port=$grantedDebugPort",
        "--user-data-dir=$grantedProfile",
        'about:blank'
    ) -WindowStyle Hidden -PassThru
    $grantedReady = $false
    for ($attempt = 0; $attempt -lt 100; $attempt += 1) {
        try {
            $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$grantedDebugPort/json/list" -TimeoutSec 1
            if ($targets.Count -gt 0) { $grantedReady = $true; break }
        } catch {}
        Start-Sleep -Milliseconds 100
    }
    if (-not $grantedReady) { throw 'Granted Edge CDP endpoint did not become ready.' }
    & node tool/p4_09_edge_capture_gate.mjs $grantedDebugPort $origin 'granted'
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic record_web capture gate failed.' }

    [ordered]@{
        evidenceType = 'synthetic_browser'
        realMicrophone = $false
        recordWebCapture = $true
        dedicatedRustWorker = $true
        permissionDenied = $true
        sharedArrayBufferRequired = $false
    } | ConvertTo-Json -Compress
}
finally {
    Pop-Location
    if ($grantedEdge -and -not $grantedEdge.HasExited) { Stop-Process -Id $grantedEdge.Id -Force -ErrorAction SilentlyContinue }
    if ($edge -and -not $edge.HasExited) { Stop-Process -Id $edge.Id -Force -ErrorAction SilentlyContinue }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 200
    if (Test-Path -LiteralPath $tempRoot) {
        try { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction Stop } catch {}
    }
}
