class VoiceTrainerRecordingStore {
  constructor(scope = globalThis) {
    this._scope = scope;
    this._databasePromise = null;
  }

  async probe() {
    const locator = `.probe-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const storageKind = await this.write(locator, new Uint8Array([0]));
    if (storageKind === 'opfs' || storageKind === 'indexedDb') {
      await this.remove(locator, storageKind);
    }
    return storageKind;
  }

  async write(locator, bytes) {
    const copy = new Uint8Array(bytes);
    let opfsFailure = null;
    try {
      const root = await this._scope.navigator?.storage?.getDirectory?.();
      if (root) {
        const directory = await root.getDirectoryHandle('voice-trainer-recordings', { create: true });
        const file = await directory.getFileHandle(locator, { create: true });
        const writer = await file.createWritable();
        try {
          await writer.write(copy);
          await writer.close();
        } catch (error) {
          try { await writer.abort?.(); } catch (_) { /* Best-effort cleanup. */ }
          try { await directory.removeEntry(locator); } catch (_) { /* No durable DB reference exists. */ }
          throw error;
        }
        return 'opfs';
      }
    } catch (error) {
      opfsFailure = error;
    }
    let indexedDbFailure = null;
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
    } catch (error) {
      indexedDbFailure = error;
    }
    return this._failureKind(opfsFailure, indexedDbFailure);
  }

  async exists(locator, storageKind) {
    if (storageKind === 'opfs') {
      try {
        const root = await this._scope.navigator?.storage?.getDirectory?.();
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
    return false;
  }

  async remove(locator, storageKind) {
    if (storageKind === 'opfs') {
      try {
        const root = await this._scope.navigator?.storage?.getDirectory?.();
        const directory = await root.getDirectoryHandle('voice-trainer-recordings');
        await directory.removeEntry(locator);
      } catch (error) {
        // A crash can happen after physical deletion and before the database
        // tombstone is finalized. Missing is therefore already-successful.
        if (error?.name !== 'NotFoundError') throw error;
      }
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
    throw new DOMException('Recording storage is unavailable.', 'NotSupportedError');
  }

  _database() {
    this._databasePromise ??= new Promise((resolve, reject) => {
      const indexedDb = this._scope.indexedDB;
      if (!indexedDb) {
        reject(new DOMException('IndexedDB is unavailable.', 'NotSupportedError'));
        return;
      }
      const request = indexedDb.open('voice-trainer-recordings-v1', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('recordings');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      request.onblocked = () => reject(new DOMException('IndexedDB open was blocked.', 'InvalidStateError'));
    });
    return this._databasePromise;
  }

  _failureKind(...failures) {
    const names = failures.filter(Boolean).map((failure) => failure?.name);
    if (names.includes('QuotaExceededError')) return 'quotaExceeded';
    if (names.some((name) =>
      name === 'SecurityError' ||
      name === 'InvalidStateError' ||
      name === 'NotAllowedError')) {
      return 'privateMode';
    }
    return 'unavailable';
  }
}

globalThis.VoiceTrainerRecordingStore = VoiceTrainerRecordingStore;
