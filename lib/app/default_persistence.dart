export 'default_persistence_stub.dart'
    if (dart.library.io) 'default_persistence_native.dart'
    if (dart.library.js_interop) 'default_persistence_web.dart';
