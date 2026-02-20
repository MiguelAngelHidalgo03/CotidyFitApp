// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

String? tryDescribeJsError(Object error) {
  try {
    final name = _getString(error, 'name');
    final code = _getString(error, 'code');
    final message = _getString(error, 'message');
    final stack = _getString(error, 'stack');

    final hasAny = (name != null && name.trim().isNotEmpty) ||
        (code != null && code.trim().isNotEmpty) ||
        (message != null && message.trim().isNotEmpty) ||
        (stack != null && stack.trim().isNotEmpty);
    if (!hasAny) return null;

    final b = StringBuffer();
    if (name != null && name.trim().isNotEmpty) b.writeln('js.name: $name');
    if (code != null && code.trim().isNotEmpty) b.writeln('js.code: $code');
    if (message != null && message.trim().isNotEmpty) b.writeln('js.message: $message');
    if (stack != null && stack.trim().isNotEmpty) b.writeln('js.stack: $stack');
    return b.toString().trim();
  } catch (_) {
    return null;
  }
}

String? _getString(Object obj, String prop) {
  try {
    final jsObj = obj as JSObject;
    final key = prop.toJS;
    final v = jsObj.getProperty<JSAny?>(key);
    if (v == null) return null;
    final s = v.toString();
    if (s.trim().isEmpty || s == 'undefined' || s == 'null') return null;
    return s;
  } catch (_) {
    return null;
  }
}
