// Browser lifecycle observer loaded before Flutter and record_web.
//
// It reports bounded, non-identifying events only. AudioContext construction is
// proxied so contexts created later by record_web can be observed without
// replacing their methods or changing their constructor arguments.
class _VoiceTrainerLifecycleClient {
  constructor() {
    this._listeners = new Set();
    this._cleanups = [];
    this._initialized = false;
    this._permissionStatus = null;
    this._contexts = new WeakSet();
  }

  subscribe(listener) {
    if (typeof listener !== 'function') {
      throw new TypeError('Lifecycle listener must be a function.');
    }
    this._listeners.add(listener);
  }

  unsubscribe(listener) {
    this._listeners.delete(listener);
  }

  async initialize() {
    if (this._initialized) return;
    this._initialized = true;

    const onVisibility = () => this._emit(
      document.visibilityState === 'hidden' ? 'pageHidden' : 'pageVisible',
    );
    document.addEventListener('visibilitychange', onVisibility);
    this._cleanups.push(() => document.removeEventListener('visibilitychange', onVisibility));
    onVisibility();

    const mediaDevices = navigator.mediaDevices;
    if (mediaDevices && typeof mediaDevices.addEventListener === 'function') {
      const onDeviceChange = () => this._emit('inputDevicesChanged');
      mediaDevices.addEventListener('devicechange', onDeviceChange);
      this._cleanups.push(() => mediaDevices.removeEventListener('devicechange', onDeviceChange));
    }

    if (navigator.permissions && typeof navigator.permissions.query === 'function') {
      try {
        const status = await navigator.permissions.query({ name: 'microphone' });
        this._permissionStatus = status;
        const onPermission = () => this._emitPermission(status.state);
        status.addEventListener('change', onPermission);
        this._cleanups.push(() => status.removeEventListener('change', onPermission));
        onPermission();
      } catch (_) {
        // Safari and older browsers may not expose microphone in Permissions.
        // Permission remains owned by the capture adapter in that case.
      }
    }
  }

  observeAudioContext(context) {
    if (!context || this._contexts.has(context)) return;
    this._contexts.add(context);
    const onState = () => {
      const state = String(context.state || 'unknown');
      const kind = {
        running: 'audioContextRunning',
        suspended: 'audioContextSuspended',
        interrupted: 'audioContextInterrupted',
        closed: 'audioContextClosed',
      }[state];
      if (kind) this._emit(kind, state);
    };
    context.addEventListener('statechange', onState);
    onState();
  }

  reportWorkerState(kind) {
    if (kind !== 'workerInterrupted' && kind !== 'workerRecovered') {
      throw new TypeError('Unknown worker lifecycle state.');
    }
    this._emit(kind);
  }

  dispose() {
    for (const cleanup of this._cleanups.splice(0)) cleanup();
    this._permissionStatus = null;
    this._initialized = false;
  }

  _emitPermission(state) {
    const kind = {
      granted: 'microphonePermissionGranted',
      prompt: 'microphonePermissionPrompt',
      denied: 'microphonePermissionDenied',
    }[state];
    if (kind) this._emit(kind);
  }

  _emit(kind, detail) {
    const payload = JSON.stringify(detail === undefined ? { kind } : { kind, detail });
    for (const listener of this._listeners) listener(payload);
  }
}

const voiceTrainerLifecycleClient = new _VoiceTrainerLifecycleClient();

function proxyAudioContextConstructor(propertyName) {
  const NativeAudioContext = globalThis[propertyName];
  if (typeof NativeAudioContext !== 'function') return;
  globalThis[propertyName] = new Proxy(NativeAudioContext, {
    construct(target, argumentsList, newTarget) {
      const context = Reflect.construct(target, argumentsList, newTarget);
      voiceTrainerLifecycleClient.observeAudioContext(context);
      return context;
    },
  });
}

proxyAudioContextConstructor('AudioContext');
proxyAudioContextConstructor('webkitAudioContext');
globalThis.VoiceTrainerLifecycleClient = function () {
  return voiceTrainerLifecycleClient;
};
