const [, , portArg = '9222', originArg = 'http://localhost:7370'] = process.argv;
const debugPort = Number(portArg);
const origin = originArg;

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
let report;
const exceptions = [];

socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) reject(new Error(JSON.stringify(message.error)));
    else resolve(message.result);
    return;
  }
  if (message.method === 'Runtime.exceptionThrown') {
    exceptions.push(message.params.exceptionDetails.text);
  }
  if (message.method === 'Runtime.consoleAPICalled') {
    for (const arg of message.params.args ?? []) {
      if (typeof arg.value === 'string' && arg.value.startsWith('PHASE0_CAPTURE_REPORT=')) {
        report = arg.value.slice('PHASE0_CAPTURE_REPORT='.length);
      }
      if (typeof arg.value === 'string' && arg.value.startsWith('PHASE0_CAPTURE_ERROR=')) {
        exceptions.push(arg.value);
      }
    }
  }
});

function command(method, params = {}) {
  const id = nextId++;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

await command('Runtime.enable');
await command('Page.enable');
await command('Browser.grantPermissions', {
  origin,
  permissions: ['audioCapture'],
});
await command('Runtime.evaluate', {
  expression: `document.querySelector('flt-semantics-placeholder')?.click()`,
});
let button;
const buttonDeadline = Date.now() + 10_000;
while (!button?.result.value && Date.now() < buttonDeadline) {
  await delay(250);
  await command('Runtime.evaluate', {
    expression: `document.querySelector('flt-semantics-placeholder')?.click()`,
  });
  button = await command('Runtime.evaluate', {
    expression: `(() => {
      const element = [...document.querySelectorAll('[role="button"]')]
        .find((candidate) => candidate.textContent.includes('Start capture'));
      if (!element) return null;
      const box = element.getBoundingClientRect();
      return { x: box.left + box.width / 2, y: box.top + box.height / 2, text: element.textContent };
    })()`,
    returnByValue: true,
  });
}
if (!button?.result.value) {
  throw new Error('Flutter Start capture semantics button was not found.');
}
const { x, y } = button.result.value;
await command('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
await command('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });

const deadline = Date.now() + 100_000;
while (!report && Date.now() < deadline) await delay(250);

const state = await command('Runtime.evaluate', {
  expression: `({ body: document.body.innerText, crossOriginIsolated })`,
  returnByValue: true,
});
socket.close();

if (!report) {
  throw new Error(`Timed out waiting for report. State: ${JSON.stringify(state.result.value)}`);
}
if (exceptions.length) {
  throw new Error(`Browser exceptions: ${JSON.stringify(exceptions)}`);
}
process.stdout.write(`${report}\n`);
