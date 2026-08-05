export 'open_database_stub.dart'
    if (dart.library.ffi) 'open_database_native.dart'
    if (dart.library.js_interop) 'open_database_web.dart';
