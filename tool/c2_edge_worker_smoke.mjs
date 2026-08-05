const [, , portArg = '9222', originArg = 'http://localhost:7390'] = process.argv;
const debugPort = Number(portArg);
const origin = originArg;

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
        throw new Error('VoiceTrainerAnalysisWorker was not loaded.');
      }
      const worker = new VoiceTrainerAnalysisWorker();
      try {
        await worker.initialize(48000);
        const pcm = new Int16Array(1024);
        for (let index = 0; index < pcm.length; index += 1) {
          pcm[index] = Math.round(0.5 * 32767 * Math.sin(2 * Math.PI * 220 * index / 48000));
        }
        const frames = JSON.parse(await worker.pushPcm(new Uint8Array(pcm.buffer)));
        return {
          frameCount: frames.length,
          startSampleChecksum: frames.reduce((sum, frame) => sum + frame.startSample, 0),
          rmsChecksum: frames.reduce((sum, frame) => sum + frame.rmsDbfs, 0),
          pitchChecksum: frames.reduce((sum, frame) => sum + (frame.pitchHz ?? 0), 0),
        };
      } finally {
        worker.terminate();
      }
    })()
  `,
});
socket.close();
if (result.exceptionDetails) {
  throw new Error(result.exceptionDetails.text);
}
if (exceptions.length) {
  throw new Error(`Browser exceptions: ${JSON.stringify(exceptions)}`);
}
process.stdout.write(`${JSON.stringify(result.result.value)}\n`);
