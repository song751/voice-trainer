const [, , portArg = '9226', originArg = 'http://127.0.0.1:7396'] = process.argv;
const debugPort = Number(portArg);
const origin = new URL(originArg);

const targets = await fetch(`http://127.0.0.1:${debugPort}/json/list`).then(
  (response) => response.json(),
);
const target = targets.find((item) => item.type === 'page');
if (!target) throw new Error(`No page target on CDP port ${debugPort}`);

const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});
let nextId = 1;
const pending = new Map();
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (!message.id || !pending.has(message.id)) return;
  const operation = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) operation.reject(new Error(JSON.stringify(message.error)));
  else operation.resolve(message.result);
});
function command(method, params = {}) {
  const id = nextId++;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}
async function waitFor(prefix) {
  const deadline = Date.now() + 30_000;
  let status = '';
  while (Date.now() < deadline) {
    const result = await command('Runtime.evaluate', {
      returnByValue: true,
      expression: 'globalThis.voiceTrainerP410Status || ""',
    });
    status = result.result.value || '';
    if (status.startsWith(prefix)) return status;
    if (status.startsWith('P4_10_WEB_PERSISTENCE_FAILED') ||
        status.startsWith('P4_10_WEB_PERSISTENCE_TYPED_FAILURE')) {
      throw new Error(status);
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Timed out waiting for ${prefix}; last status: ${status}`);
}
function report(status) {
  const value = JSON.parse(status.slice(status.indexOf('{')));
  if (!value.persistent || value.structuredStorageKind === 'inMemory' ||
      value.recordingStorageKind === 'none') {
    throw new Error(`Non-persistent storage was accepted: ${status}`);
  }
  return value;
}

await command('Runtime.enable');
await command('Page.enable');
await command('Page.navigate', { url: origin.href });
const created = report(await waitFor('P4_10_WEB_CREATED_OK'));
const wavSizeResult = await command('Runtime.evaluate', {
  awaitPromise: true,
  returnByValue: true,
  expression: `(async () => {
    const root = await navigator.storage.getDirectory();
    const directory = await root.getDirectoryHandle('voice-trainer-recordings');
    const handle = await directory.getFileHandle('p4-10-web-persistence-gate.wav');
    return (await handle.getFile()).size;
  })()`,
});
const wavSize = wavSizeResult.result.value;
if (wavSize !== 96_044) {
  throw new Error(`Expected a one-second PCM16 WAV (96044 bytes), got ${wavSize}.`);
}

await command('Page.reload', { ignoreCache: true });
const restored = report(await waitFor('P4_10_WEB_RESTORED_OK'));

const deleteUrl = new URL(origin.href);
deleteUrl.searchParams.set('action', 'delete');
await command('Page.navigate', { url: deleteUrl.href });
const deleted = report(await waitFor('P4_10_WEB_DELETE_OK'));

await command('Page.navigate', { url: origin.href });
const recreated = report(await waitFor('P4_10_WEB_CREATED_OK'));
socket.close();

process.stdout.write(`${JSON.stringify({
  evidenceType: 'synthetic_browser_storage',
  realMicrophone: false,
  structuredStorageKind: created.structuredStorageKind,
  recordingStorageKind: created.recordingStorageKind,
  finalizedWavBytes: wavSize,
  reload: restored.historyCount >= 1,
  delete: deleted.historyCount === 0,
  recreateAfterDelete: recreated.persistent,
  pauseWallClockIgnored: created.pauseWallClockIgnored,
})}\n`);
