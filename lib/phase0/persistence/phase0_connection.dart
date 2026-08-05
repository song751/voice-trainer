export 'phase0_connection_stub.dart'
    if (dart.library.ffi) 'phase0_connection_native.dart'
    if (dart.library.js_interop) 'phase0_connection_web.dart';
