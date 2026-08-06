const [, , portArg = '9222', originArg = 'http://localhost:7390'] = process.argv;
const debugPort = Number(portArg);
const origin = originArg;
const sampleRate = 48_000;
const batchSize = 1_024;
const totalSamples = sampleRate;

const targets = await fetch(`http://127.0.0.1:${debugPort}/json/list`).then((response) => response.json());
const target = targets.find((item) => item.type === 'page' && item.url.startsWith(origin));
if (!target) throw new Error(`No page target for ${origin} on CDP port ${debugPort}`);

const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});

let nextId = 1;
const pending = new Map();
const exceptions = [];
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const operation = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) operation.reject(new Error(JSON.stringify(message.error)));
    else operation.resolve(message.result);
    return;
  }
  if (message.method === 'Runtime.exceptionThrown') exceptions.push(message.params.exceptionDetails.text);
});

function command(method, params = {}) {
  const id = nextId++;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

await command('Runtime.enable');
const result = await command('Runtime.evaluate', {
  awaitPromise: true,
  returnByValue: true,
  expression: `
    (async () => {
      if (typeof VoiceTrainerAnalysisWorker !== 'function') throw new Error('Dedicated worker facade is unavailable.');
      const worker = new VoiceTrainerAnalysisWorker();
      try {
        await worker.initialize(${sampleRate});
        const frames = [];
        for (let start = 0; start < ${totalSamples}; start += ${batchSize}) {
          const count = Math.min(${batchSize}, ${totalSamples} - start);
          const pcm = new Int16Array(count);
          for (let offset = 0; offset < count; offset += 1) {
            pcm[offset] = Math.trunc(16000 * Math.sin(2 * Math.PI * 220 * (start + offset) / ${sampleRate}));
          }
          frames.push(...JSON.parse(await worker.pushPcm(new Uint8Array(pcm.buffer))));
        }
        if (!frames.length) throw new Error('No analysis frames returned.');
        for (const frame of frames) {
          if (!Array.isArray(frame.bandPowersDbfs) || frame.bandPowersDbfs.length !== 8) throw new Error('Bridge did not return exactly eight band powers.');
          if (frame.voiced !== (frame.pitchHz !== null)) throw new Error('Voiced DTO disagrees with optional F0.');
          if ('spectrumBinsDb' in frame || 'uiBinsDbfs' in frame) throw new Error('Large spectrum crossed the bridge.');
          if (!Number.isInteger(frame.qualityFlags) || frame.qualityFlags < 0 || frame.qualityFlags > 0x1f) throw new Error('Invalid quality bitset.');
        }
        let oversizeRejected = false;
        try {
          await worker.pushPcm(new Uint8Array(new Int16Array(1025).buffer));
        } catch (error) {
          oversizeRejected = String(error).includes('1024');
        }
        if (!oversizeRejected) throw new Error('Worker accepted an oversized bridge batch.');
        return {
          sampleRate: ${sampleRate}, totalSamples: ${totalSamples}, batchSize: ${batchSize},
          frameCount: frames.length,
          startSampleChecksum: frames.reduce((sum, frame) => sum + frame.startSample, 0),
          rmsChecksum: frames.reduce((sum, frame) => sum + frame.rmsDbfs, 0),
          pitchChecksum: frames.reduce((sum, frame) => sum + (frame.pitchHz ?? 0), 0),
          maxBandPowers: Math.max(...frames.map((frame) => frame.bandPowersDbfs.length)),
          qualityMaskOr: frames.reduce((mask, frame) => mask | frame.qualityFlags, 0),
          oversizeRejected,
        };
      } finally {
        worker.terminate();
      }
    })()
  `,
});
socket.close();
if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
if (exceptions.length) throw new Error(`Browser exceptions: ${JSON.stringify(exceptions)}`);
process.stdout.write(`${JSON.stringify(result.result.value)}\n`);
