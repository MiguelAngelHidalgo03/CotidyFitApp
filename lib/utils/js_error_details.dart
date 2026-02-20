// Exposes JS error details (web only) via conditional export.
// On non-web platforms this returns null.

export 'js_error_details_stub.dart' if (dart.library.html) 'js_error_details_web.dart';
