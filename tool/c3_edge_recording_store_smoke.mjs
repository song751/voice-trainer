const [, , portArg = '9222', originArg = 'http://127.0.0.1:7390'] = process.argv;
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
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const operation = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) operation.reject(new Error(JSON.stringify(message.error)));
    else operation.resolve(message.result);
  }
});
function command(method, params = {}) {
  const id = nextId++;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

const result = await command('Runtime.evaluate', {
  awaitPromise: true,
  returnByValue: true,
  expression: `
    (async () => {
      if (typeof VoiceTrainerRecordingStore !== 'function') {
        throw new Error('VoiceTrainerRecordingStore was not loaded.');
      }
      const store = new VoiceTrainerRecordingStore();
      const locator = 'c3-smoke-' + Date.now() + '.wav';
      const storageKind = await store.write(locator, new Uint8Array([82, 73, 70, 70]));
      const existsBeforeDelete = await store.exists(locator, storageKind);
      await store.remove(locator, storageKind);
      const existsAfterDelete = await store.exists(locator, storageKind);
      return { storageKind, existsBeforeDelete, existsAfterDelete };
    })()
  `,
});
socket.close();
if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
process.stdout.write(`${JSON.stringify(result.result.value)}\n`);
