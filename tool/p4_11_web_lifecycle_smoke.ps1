param(
    [int]$ServerPort = 7397,
    [int]$DebugPort = 9227,
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

$tempRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('voice-trainer-p4-11-' + [Guid]::NewGuid().ToString('N'))))
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $tempRoot.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or
    -not ([IO.Path]::GetFileName($tempRoot)).StartsWith('voice-trainer-p4-11-', [StringComparison]::Ordinal)) {
    throw 'Refusing to use an unverified temporary directory.'
}
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$server = $null
$serverListenerPid = $null
$edge = $null
try {
    Push-Location $repoRoot
    if (-not $SkipBuild) {
        & flutter build web --release --no-web-resources-cdn --csp
        if ($LASTEXITCODE -ne 0) { throw "Self-contained Flutter Web release failed with exit code $LASTEXITCODE." }
    }
    & dart run tool/p4_11_prepare_web_release.dart build/web
    if ($LASTEXITCODE -ne 0) { throw 'Release manifest preparation failed.' }
    & node --check web/lifecycle_client.js
    if ($LASTEXITCODE -ne 0) { throw 'Lifecycle client syntax validation failed.' }
    & node --check web/analysis_worker_client.js
    if ($LASTEXITCODE -ne 0) { throw 'Worker client syntax validation failed.' }

    if (Get-NetTCPConnection -LocalPort $ServerPort -State Listen -ErrorAction SilentlyContinue) {
        throw "Server port $ServerPort is already in use."
    }
    $server = Start-Process -FilePath 'dart' -ArgumentList @(
        'run', 'tool/p4_11_web_server.dart', $ServerPort, 'build/web'
    ) -WorkingDirectory $repoRoot -RedirectStandardOutput (Join-Path $tempRoot 'server.stdout.log') -RedirectStandardError (Join-Path $tempRoot 'server.stderr.log') -WindowStyle Hidden -PassThru
    for ($attempt = 0; $attempt -lt 100; $attempt += 1) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$ServerPort/" -TimeoutSec 1
            if ($response.StatusCode -eq 200) { break }
        } catch {}
        if ($attempt -eq 99) { throw 'P4-11 local server did not become ready.' }
        Start-Sleep -Milliseconds 100
    }
    $serverListenerPid = (Get-NetTCPConnection -LocalPort $ServerPort -State Listen -ErrorAction Stop | Select-Object -First 1).OwningProcess

    & node tool/p4_11_deployment_validator.mjs "http://127.0.0.1:$ServerPort/"
    if ($LASTEXITCODE -ne 0) { throw 'Deployment header/cache validator failed.' }

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

    & node tool/p4_11_edge_lifecycle_gate.mjs $DebugPort "http://127.0.0.1:$ServerPort/"
    if ($LASTEXITCODE -ne 0) { throw 'Edge lifecycle/deployment gate failed.' }
}
finally {
    Pop-Location
    if ($edge -and -not $edge.HasExited) { Stop-Process -Id $edge.Id -Force -ErrorAction SilentlyContinue }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    if ($serverListenerPid) {
        $listenerProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$serverListenerPid" -ErrorAction SilentlyContinue
        if ($listenerProcess -and $listenerProcess.CommandLine -like '*tool\p4_11_web_server.dart*') {
            Stop-Process -Id $serverListenerPid -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Milliseconds 200
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
