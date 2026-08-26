import { createHash } from 'node:crypto';

const [, , originArg = 'http://127.0.0.1:7397'] = process.argv;
const origin = new URL(originArg);
const manifestResponse = await fetch(new URL('deployment_manifest.json', origin));
if (!manifestResponse.ok) throw new Error('Deployment manifest is unavailable.');
const manifest = await manifestResponse.json();
const releaseId = manifest.releaseId;
if (!/^[a-f0-9]{64}$/.test(releaseId)) throw new Error('Invalid release id.');
if (manifest.runtimeMode !== 'single-thread' || manifest.requiresCrossOriginIsolation !== false) {
  throw new Error('Default release must remain single-thread without cross-origin isolation.');
}

let wasmCount = 0;
for (const [asset, expectedDigest] of Object.entries(manifest.assets)) {
  const response = await fetch(new URL(asset, origin), {
    headers: { 'If-None-Match': `"stale-${releaseId}"` },
  });
  if (response.status !== 200) throw new Error(`${asset} was cached or unavailable.`);
  if (response.headers.get('x-voice-trainer-release') !== releaseId) {
    throw new Error(`${asset} belongs to a different release.`);
  }
  if (!/^no-store(?:, max-age=0)?$/.test(response.headers.get('cache-control') || '')) {
    throw new Error(`${asset} may be reused across releases.`);
  }
  if (response.headers.has('cross-origin-opener-policy') ||
      response.headers.has('cross-origin-embedder-policy')) {
    throw new Error('Single-thread release was incorrectly coupled to COOP/COEP.');
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  const digest = createHash('sha256').update(bytes).digest('hex');
  if (digest !== expectedDigest) throw new Error(`${asset} digest mismatch.`);
  if (asset.endsWith('.wasm')) {
    wasmCount += 1;
    if (response.headers.get('content-type') !== 'application/wasm') {
      throw new Error(`${asset} has an invalid WASM MIME type.`);
    }
  }
}

const indexResponse = await fetch(origin);
const csp = indexResponse.headers.get('content-security-policy') || '';
for (const directive of [
  "default-src 'self'",
  "script-src 'self' 'wasm-unsafe-eval'",
  "worker-src 'self' blob:",
  "object-src 'none'",
]) {
  if (!csp.includes(directive)) throw new Error(`CSP is missing ${directive}.`);
}
const bootstrap = await fetch(new URL('flutter_bootstrap.js', origin)).then((r) => r.text());
if (!bootstrap.includes('"useLocalCanvasKit":true')) {
  throw new Error('Flutter release may load CanvasKit from an external CDN.');
}
const index = await indexResponse.text();
if (/<(script|link)[^>]+(?:src|href)=["']https?:\/\//i.test(index)) {
  throw new Error('Index contains an external runtime dependency.');
}

process.stdout.write(`${JSON.stringify({
  releaseId,
  criticalAssetCount: Object.keys(manifest.assets).length,
  wasmCount,
  cacheMixPrevented: true,
  wasmMime: true,
  csp: true,
  crossOriginIsolationRequired: false,
  selfContainedCanvasKit: true,
})}\n`);
