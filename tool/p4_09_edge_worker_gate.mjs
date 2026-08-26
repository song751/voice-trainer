const [, , portArg = '9224', originArg = 'http://127.0.0.1:7394'] = process.argv;
const debugPort = Number(portArg);
const origin = originArg;
const sampleRate = 48_000;
const batchSize = 1_024;
const totalSamples = sampleRate;

const targets = await fetch(`http://127.0.0.1:${debugPort}/json/list`).then(
  (response) => response.json(),
);
const target = targets.find(
  (item) => item.type === 'page' && item.url.startsWith(origin),
);
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
  if (message.method === 'Runtime.exceptionThrown') {
    exceptions.push(message.params.exceptionDetails.text);
  }
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
      if (typeof VoiceTrainerAnalysisWorker !== 'function') {
        throw new Error('Dedicated worker facade is unavailable.');
      }
      const makePcm = (start, count) => {
        const pcm = new Int16Array(count);
        for (let offset = 0; offset < count; offset += 1) {
          pcm[offset] = Math.trunc(
            16000 * Math.sin(2 * Math.PI * 220 * (start + offset) / ${sampleRate}),
          );
        }
        return new Uint8Array(pcm.buffer);
      };

      const worker = new VoiceTrainerAnalysisWorker();
      let unknownOperationRejected = false;
      try {
        await worker.initialize(${sampleRate});
        const frames = [];
        for (let start = 0; start < ${totalSamples}; start += ${batchSize}) {
          const count = Math.min(${batchSize}, ${totalSamples} - start);
          frames.push(...JSON.parse(await worker.pushPcm(
            makePcm(start, count), start, 0, false,
          )));
        }
        const summary = JSON.parse(await worker.finish());
        try {
          await worker._request('unknown-operation');
        } catch (error) {
          unknownOperationRejected = String(error).includes('Unknown analysis worker operation');
        }
        if (!unknownOperationRejected) {
          throw new Error('Worker accepted an unknown operation.');
        }

        await worker.reset();
        const resetFrames = JSON.parse(await worker.pushPcm(
          makePcm(0, ${batchSize}), 0, 0, false,
        ));
        if (resetFrames.length && resetFrames[0].startSample < 0) {
          throw new Error('Worker reset returned an invalid timeline.');
        }
        if (frames.length !== 94) throw new Error('Unexpected production frame count.');
        if (frames.reduce((sum, frame) => sum + frame.startSample, 0) !== 2098080) {
          throw new Error('Unexpected production sample checksum.');
        }
        for (const frame of frames) {
          if (!Array.isArray(frame.bandPowersDbfs) || frame.bandPowersDbfs.length !== 8) {
            throw new Error('Worker returned an unbounded band payload.');
          }
          if (frame.voiced !== (frame.pitchHz !== null)) {
            throw new Error('Worker voiced flag disagrees with optional pitch.');
          }
          if ('spectrumBinsDb' in frame || 'uiBinsDbfs' in frame) {
            throw new Error('Large spectrum crossed the worker boundary.');
          }
        }

        const crashed = new VoiceTrainerAnalysisWorker();
        await crashed.initialize(${sampleRate});
        const crashPcm = makePcm(0, ${batchSize});
        const pendingPush = crashed.pushPcm(crashPcm, 0, 0, false);
        crashed.terminate();
        let crashRejected = false;
        try {
          await pendingPush;
        } catch (_) {
          crashRejected = true;
        }
        if (!crashRejected) throw new Error('Worker crash did not reject pending work.');

        const replacement = new VoiceTrainerAnalysisWorker();
        try {
          await replacement.initialize(${sampleRate});
          await replacement.pushPcm(makePcm(0, ${batchSize}), 0, 0, false);
        } finally {
          replacement.terminate();
        }

        return {
          evidenceType: 'synthetic_browser',
          realMicrophone: false,
          dedicatedWorker: true,
          singleThreadFallbackUsed: false,
          crossOriginIsolated,
          frameCount: frames.length,
          startSampleChecksum: frames.reduce((sum, frame) => sum + frame.startSample, 0),
          validFrameCount: summary.validFrameCount,
          unknownOperationRejected,
          crashRejected,
          replacementStarted: true,
        };
      } finally {
        worker.terminate();
      }
    })()
  `,
});
socket.close();
if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
if (exceptions.length) {
  throw new Error(`Browser exceptions: ${JSON.stringify(exceptions)}`);
}
if (result.result.value.crossOriginIsolated !== false) {
  throw new Error('P4-09 gate must prove the single-thread path without COOP/COEP.');
}
process.stdout.write(`${JSON.stringify(result.result.value)}\n`);
