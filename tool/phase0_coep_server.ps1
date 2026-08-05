param(
    [int]$Port = 7358
)

# Phase 0 test harness only. The accepted Web baseline is single-threaded and
# does not require cross-origin isolation. Keep this server to validate the
# response headers needed by a future SharedArrayBuffer/threaded experiment.
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\build\web')).Path
$prefix = "http://127.0.0.1:$Port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()

$contentTypes = @{
    '.css' = 'text/css; charset=utf-8'
    '.html' = 'text/html; charset=utf-8'
    '.ico' = 'image/x-icon'
    '.js' = 'text/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.png' = 'image/png'
    '.svg' = 'image/svg+xml'
    '.wasm' = 'application/wasm'
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace($relative)) {
                $relative = 'index.html'
            }

            $candidate = [IO.Path]::GetFullPath((Join-Path $root $relative))
            if (-not $candidate.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $context.Response.StatusCode = 404
                $context.Response.Close()
                continue
            }

            $extension = [IO.Path]::GetExtension($candidate).ToLowerInvariant()
            $context.Response.ContentType = $contentTypes[$extension]
            if ([string]::IsNullOrWhiteSpace($context.Response.ContentType)) {
                $context.Response.ContentType = 'application/octet-stream'
            }
            $context.Response.Headers['Cross-Origin-Opener-Policy'] = 'same-origin'
            $context.Response.Headers['Cross-Origin-Embedder-Policy'] = 'require-corp'
            $bytes = [IO.File]::ReadAllBytes($candidate)
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.Close()
        }
        catch {
            $bytes = [Text.Encoding]::UTF8.GetBytes($_.Exception.ToString())
            $context.Response.StatusCode = 500
            $context.Response.ContentType = 'text/plain; charset=utf-8'
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.Close()
        }
    }
}
finally {
    $listener.Close()
}
