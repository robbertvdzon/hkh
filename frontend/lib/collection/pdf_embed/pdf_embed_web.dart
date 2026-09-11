import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const bool supportsEmbeddedPdf = true;

final Set<String> _registeredViewTypes = {};

/// Rendert de PDF ingesloten in de pagina via een `<iframe>` naar de bron-URL
/// (de HKH-website levert zelf al een pdf.js-viewer op die URL, compleet met
/// eigen zoom/pagina-navigatie). Werkt alleen op Flutter web.
Widget buildEmbeddedPdf(String url) {
  final viewType = 'hkh-pdf-embed-${url.hashCode}';
  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
