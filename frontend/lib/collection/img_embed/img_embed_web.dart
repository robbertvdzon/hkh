import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViewTypes = {};

/// De HKH-webserver stuurt geen CORS-headers mee. Flutter web's Image.network
/// gebruikt fetch()/XHR om de bytes zelf te decoderen (voor CanvasKit/Skwasm) en
/// dat wordt daardoor stil geblokkeerd - de afbeelding verdwijnt zonder foutmelding.
/// Een gewoon `<img>`-element heeft dat probleem niet (geen JS-leestoegang tot de
/// pixels nodig om te tonen), dus die gebruiken we hier in plaats daarvan.
Widget buildNetworkImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext)? placeholder,
  String? linkUrl,
}) {
  final objectFit = switch (fit) {
    BoxFit.cover => 'cover',
    BoxFit.contain => 'contain',
    BoxFit.fill => 'fill',
    _ => 'contain',
  };
  final viewType =
      'hkh-img-embed-${url.hashCode}-${linkUrl.hashCode}-$objectFit';
  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = web.HTMLImageElement()
        ..src = url
        ..alt = 'Archieffoto'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = objectFit
        ..style.pointerEvents = linkUrl == null ? 'none' : 'auto';
      if (linkUrl == null) return img;
      final link = web.HTMLAnchorElement()
        ..href = linkUrl
        ..target = '_blank'
        ..rel = 'noopener'
        ..style.display = 'block'
        ..style.width = '100%'
        ..style.height = '100%';
      link.append(img);
      return link;
    });
  }
  return HtmlElementView(viewType: viewType);
}
