class VoiceTrainerRecordingStore {
  constructor() {
    this._memory = new Map();
    this._databasePromise = null;
  }

  async write(locator, bytes) {
    const copy = new Uint8Array(bytes);
    try {
      const root = await navigator.storage?.getDirectory?.();
      if (root) {
        const directory = await root.getDirectoryHandle('voice-trainer-recordings', { create: true });
        const file = await directory.getFileHandle(locator, { create: true });
        const writer = await file.createWritable();
        await writer.write(copy);
        await writer.close();
        return 'opfs';
      }
    } catch (_) {
      // Fall through to IndexedDB. Storage quota and private-mode failures are
      // surfaced by the selected storage kind rather than hidden from callers.
    }
    try {
      const database = await this._database();
      await new Promise((resolve, reject) => {
        const transaction = database.transaction('recordings', 'readwrite');
        transaction.objectStore('recordings').put(copy, locator);
        transaction.oncomplete = resolve;
        transaction.onerror = () => reject(transaction.error);
        transaction.onabort = () => reject(transaction.error);
      });
      return 'indexedDb';
    } catch (_) {
      this._memory.set(locator, copy);
      return 'none';
    }
  }

  async exists(locator, storageKind) {
    if (storageKind === 'opfs') {
      try {
        const root = await navigator.storage?.getDirectory?.();
        const directory = await root.getDirectoryHandle('voice-trainer-recordings');
        await directory.getFileHandle(locator);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (storageKind === 'indexedDb') {
      try {
        const database = await this._database();
        return await new Promise((resolve, reject) => {
          const request = database.transaction('recordings').objectStore('recordings').getKey(locator);
          request.onsuccess = () => resolve(request.result !== undefined);
          request.onerror = () => reject(request.error);
        });
      } catch (_) {
        return false;
      }
    }
    return this._memory.has(locator);
  }

  async remove(locator, storageKind) {
    if (storageKind === 'opfs') {
      const root = await navigator.storage?.getDirectory?.();
      const directory = await root.getDirectoryHandle('voice-trainer-recordings');
      await directory.removeEntry(locator);
      return;
    }
    if (storageKind === 'indexedDb') {
      const database = await this._database();
      await new Promise((resolve, reject) => {
        const transaction = database.transaction('recordings', 'readwrite');
        transaction.objectStore('recordings').delete(locator);
        transaction.oncomplete = resolve;
        transaction.onerror = () => reject(transaction.error);
        transaction.onabort = () => reject(transaction.error);
      });
      return;
    }
    this._memory.delete(locator);
  }

  _database() {
    this._databasePromise ??= new Promise((resolve, reject) => {
      const request = indexedDB.open('voice-trainer-recordings-v1', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('recordings');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    return this._databasePromise;
  }
}

window.VoiceTrainerRecordingStore = VoiceTrainerRecordingStore;
