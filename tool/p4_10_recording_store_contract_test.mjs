import '../web/recording_store_client.js';

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function opfsScope({ writeFailure = null } = {}) {
  const files = new Map();
  const directory = {
    async getFileHandle(locator, options = {}) {
      if (!options.create && !files.has(locator)) {
        throw new DOMException('Missing file.', 'NotFoundError');
      }
      return {
        async createWritable() {
          let pending = null;
          return {
            async write(bytes) {
              if (writeFailure) throw writeFailure;
              pending = new Uint8Array(bytes);
            },
            async close() { files.set(locator, pending); },
            async abort() { pending = null; },
          };
        },
      };
    },
    async removeEntry(locator) {
      if (!files.delete(locator)) {
        throw new DOMException('Missing file.', 'NotFoundError');
      }
    },
  };
  return {
    navigator: {
      storage: {
        async getDirectory() {
          return {
            async getDirectoryHandle() { return directory; },
          };
        },
      },
    },
    files,
  };
}

function indexedDbScope() {
  const rows = new Map();
  const database = {
    createObjectStore() {},
    transaction() {
      const transaction = {
        error: null,
        objectStore() {
          return {
            put(bytes, locator) {
              rows.set(locator, new Uint8Array(bytes));
              setTimeout(() => transaction.oncomplete?.(), 0);
            },
            delete(locator) {
              rows.delete(locator);
              setTimeout(() => transaction.oncomplete?.(), 0);
            },
            getKey(locator) {
              const request = {};
              setTimeout(() => {
                request.result = rows.has(locator) ? locator : undefined;
                request.onsuccess?.();
              }, 0);
              return request;
            },
          };
        },
      };
      return transaction;
    },
  };
  return {
    indexedDB: {
      open() {
        const request = {};
        setTimeout(() => {
          request.result = database;
          request.onupgradeneeded?.();
          request.onsuccess?.();
        }, 0);
        return request;
      },
    },
    rows,
  };
}

const opfs = opfsScope();
const first = new VoiceTrainerRecordingStore(opfs);
assert(await first.write('reload.wav', new Uint8Array([1, 2])) === 'opfs', 'OPFS not selected.');
const reloaded = new VoiceTrainerRecordingStore(opfs);
assert(await reloaded.exists('reload.wav', 'opfs'), 'OPFS blob did not survive a client reload.');
await reloaded.remove('reload.wav', 'opfs');
assert(!(await first.exists('reload.wav', 'opfs')), 'OPFS delete did not persist.');
await reloaded.remove('reload.wav', 'opfs');

const idb = indexedDbScope();
const quotaOpfs = opfsScope({
  writeFailure: new DOMException('Quota exhausted.', 'QuotaExceededError'),
});
const idbScope = { navigator: quotaOpfs.navigator, indexedDB: idb.indexedDB };
const fallback = new VoiceTrainerRecordingStore(idbScope);
assert(await fallback.write('fallback.wav', new Uint8Array([3])) === 'indexedDb', 'IndexedDB fallback not selected.');
assert(await new VoiceTrainerRecordingStore(idbScope).exists('fallback.wav', 'indexedDb'), 'IndexedDB blob did not survive a client reload.');
await fallback.remove('fallback.wav', 'indexedDb');
assert(!idb.rows.has('fallback.wav'), 'IndexedDB delete did not commit.');
assert(quotaOpfs.files.size === 0, 'Failed OPFS append left a partial file.');

const privateScope = {
  navigator: { storage: { async getDirectory() { throw new DOMException('Denied.', 'SecurityError'); } } },
};
assert(
  await new VoiceTrainerRecordingStore(privateScope).write('private.wav', new Uint8Array([4])) === 'privateMode',
  'Private-mode storage did not return a typed result.',
);

const quotaScope = opfsScope({
  writeFailure: new DOMException('Quota exhausted.', 'QuotaExceededError'),
});
assert(
  await new VoiceTrainerRecordingStore(quotaScope).write('quota.wav', new Uint8Array([5])) === 'quotaExceeded',
  'Quota failure did not return a typed result.',
);

process.stdout.write(JSON.stringify({
  opfsReloadDelete: true,
  indexedDbFallbackReloadDelete: true,
  appendFailureCleanup: true,
  privateModeTyped: true,
  quotaTyped: true,
}) + '\n');
