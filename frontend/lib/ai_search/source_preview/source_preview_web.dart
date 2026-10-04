import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// External pages stay inside their preview and cannot navigate the answer.
Widget buildSourcePreview(String url) => HtmlElementView.fromTagName(
  tagName: 'iframe',
  onElementCreated: (element) {
    final iframe = element as web.HTMLIFrameElement;
    iframe
      ..src = url
      ..title = 'Voorbeeld van de bron'
      ..referrerPolicy = 'no-referrer'
      ..setAttribute('sandbox', 'allow-scripts')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
  },
);
