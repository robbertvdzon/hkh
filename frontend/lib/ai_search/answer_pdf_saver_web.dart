import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: start een directe bestandsdownload via een Blob en een tijdelijke
/// downloadlink. Houd de URL beschikbaar totdat de browser de download heeft gestart.
Future<void> saveAnswerPdf(String fileName, Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
