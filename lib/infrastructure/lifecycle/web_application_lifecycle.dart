import 'dart:async';
import 'dart:js_interop';

import '../../core/platform/application_lifecycle.dart';
import 'web_lifecycle_event_decoder.dart';

@JS('VoiceTrainerLifecycleClient')
extension type _WebLifecycleClient._(JSObject _) implements JSObject {
  external factory _WebLifecycleClient();

  external JSPromise<JSAny?> initialize();
  external void subscribe(JSFunction listener);
  external void unsubscribe(JSFunction listener);
  external void dispose();
}

final class WebApplicationLifecycle implements ApplicationLifecycle {
  WebApplicationLifecycle({WebLifecycleEventDecoder? decoder})
    : _decoder = decoder ?? const WebLifecycleEventDecoder();

  final WebLifecycleEventDecoder _decoder;
  final _controller = StreamController<ApplicationLifecycleEvent>.broadcast(
    sync: true,
  );
  _WebLifecycleClient? _client;
  JSFunction? _listener;

  @override
  Stream<ApplicationLifecycleEvent> get events => _controller.stream;

  @override
  Future<void> initialize() async {
    if (_client != null) return;
    final client = _WebLifecycleClient();
    final listener = ((JSString encoded) {
      try {
        _controller.add(_decoder.decode(encoded.toDart));
      } on FormatException catch (error, stackTrace) {
        _controller.addError(error, stackTrace);
      }
    }).toJS;
    _client = client;
    _listener = listener;
    client.subscribe(listener);
    await client.initialize().toDart;
  }

  @override
  Future<void> dispose() async {
    final client = _client;
    final listener = _listener;
    _client = null;
    _listener = null;
    if (client != null && listener != null) {
      client.unsubscribe(listener);
      client.dispose();
    }
    await _controller.close();
  }
}
