const [, , portArg = '9224', urlArg = 'http://127.0.0.1:7394', settingArg = 'granted'] = process.argv;
const debugPort = Number(portArg);
const url = new URL(urlArg);
const permissionSetting = settingArg;
const expectedSentinel = permissionSetting === 'denied'
  ? 'P4_09_WEB_PERMISSION_DENIED_OK'
  : 'P4_09_WEB_CAPTURE_OK';
const acceptedGrantedSentinels = [
  'P4_09_WEB_CAPTURE_OK',
  'P4_09_WEB_CAPTURE_UNSUPPORTED_OK',
];

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

await command('Runtime.enable');
await command('Page.enable');
await command('Browser.grantPermissions', {
  origin: url.origin,
  permissions: permissionSetting === 'granted' ? ['audioCapture'] : [],
});
await command('Page.navigate', { url: url.href });

const deadline = Date.now() + 30_000;
let status = '';
while (Date.now() < deadline) {
  const result = await command('Runtime.evaluate', {
    returnByValue: true,
    expression: 'window.voiceTrainerP409Status || ""',
  });
  status = result.result.value || '';
  const accepted = permissionSetting === 'denied'
    ? status.startsWith(expectedSentinel)
    : acceptedGrantedSentinels.some((sentinel) => status.startsWith(sentinel));
  if (accepted) break;
  if (status.startsWith('P4_09_WEB_CAPTURE_FAILED')) {
    throw new Error(status);
  }
  await new Promise((resolve) => setTimeout(resolve, 100));
}

await command('Browser.resetPermissions');
socket.close();
const accepted = permissionSetting === 'denied'
  ? status.startsWith(expectedSentinel)
  : acceptedGrantedSentinels.some((sentinel) => status.startsWith(sentinel));
if (!accepted) {
  throw new Error(`Timed out waiting for ${expectedSentinel}; last status: ${status}`);
}
process.stdout.write(`${status}\n`);
