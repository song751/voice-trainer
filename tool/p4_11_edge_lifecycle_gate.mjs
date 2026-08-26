const [, , portArg = '9227', originArg = 'http://127.0.0.1:7397'] = process.argv;
const debugPort = Number(portArg);
const origin = new URL(originArg);

const targets = await fetch(`http://127.0.0.1:${debugPort}/json/list`).then(
  (response) => response.json(),
);
const target = targets.find(
  (item) => item.type === 'page' &&
    (item.url === 'about:blank' || item.url.startsWith(origin.origin)),
);
if (!target) throw new Error(`No page target on CDP port ${debugPort}`);

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
  } else if (message.method === 'Runtime.exceptionThrown') {
    exceptions.push(message.params.exceptionDetails.text);
  }
});
function command(method, params = {}) {
  const id = nextId++;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

await command('Runtime.enable');
await command('Page.enable');
await command('Browser.grantPermissions', {
  origin: origin.origin,
  permissions: ['audioCapture'],
});
await command('Page.navigate', { url: origin.href });
await new Promise((resolve) => setTimeout(resolve, 1500));

const result = await command('Runtime.evaluate', {
  awaitPromise: true,
  returnByValue: true,
  expression: `
    (async () => {
      if (typeof VoiceTrainerLifecycleClient !== 'function') {
        throw new Error('Lifecycle facade is unavailable.');
      }
      const lifecycle = new VoiceTrainerLifecycleClient();
      const events = [];
      const listener = (event) => events.push(JSON.parse(event));
      lifecycle.subscribe(listener);
      await lifecycle.initialize();

      Object.defineProperty(document, 'visibilityState', {
        configurable: true,
        value: 'hidden',
      });
      document.dispatchEvent(new Event('visibilitychange'));
      Object.defineProperty(document, 'visibilityState', {
        configurable: true,
        value: 'visible',
      });
      document.dispatchEvent(new Event('visibilitychange'));
      delete document.visibilityState;

      if (navigator.mediaDevices) {
        navigator.mediaDevices.dispatchEvent(new Event('devicechange'));
      }

      let audioContextObserved = false;
      if (typeof AudioContext === 'function') {
        const context = new AudioContext();
        try {
          await Promise.race([
            context.suspend(),
            new Promise((resolve) => setTimeout(resolve, 500)),
          ]);
          audioContextObserved = events.some((event) =>
            event.kind === 'audioContextRunning' ||
            event.kind === 'audioContextSuspended');
        } finally {
          await Promise.race([
            context.close(),
            new Promise((resolve) => setTimeout(resolve, 500)),
          ]);
        }
      }

      const worker = new VoiceTrainerAnalysisWorker();
      await worker.initialize(48000);
      worker.terminate();
      const replacement = new VoiceTrainerAnalysisWorker();
      try {
        await replacement.initialize(48000);
      } finally {
        replacement.terminate();
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
      lifecycle.unsubscribe(listener);

      const kinds = events.map((event) => event.kind);
      for (const expected of [
        'pageHidden',
        'pageVisible',
        'inputDevicesChanged',
        'workerInterrupted',
        'workerRecovered',
      ]) {
        if (!kinds.includes(expected)) {
          throw new Error('Lifecycle event missing: ' + expected + '; observed=' + JSON.stringify(kinds));
        }
      }
      const permissionState = await navigator.permissions
        .query({ name: 'microphone' })
        .then((status) => status.state)
        .catch(() => 'unsupported');
      return {
        evidenceType: 'synthetic_browser_lifecycle',
        realMicrophone: false,
        crossOriginIsolated,
        lifecycleKinds: [...new Set(kinds)],
        permissionState,
        audioContextObserved,
        workerInterruptionRecovery: true,
      };
    })()
  `,
});
await command('Browser.resetPermissions');
socket.close();
if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
if (exceptions.length) throw new Error(`Browser exceptions: ${JSON.stringify(exceptions)}`);
const evidence = result.result.value;
if (evidence.crossOriginIsolated !== false) {
  throw new Error('Default single-thread release unexpectedly requires COOP/COEP.');
}
if (!evidence.audioContextObserved) {
  throw new Error('AudioContext lifecycle was not observed.');
}
process.stdout.write(`${JSON.stringify(evidence)}\n`);
