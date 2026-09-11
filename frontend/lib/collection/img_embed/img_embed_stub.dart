import 'package:flutter/material.dart';

/// Op mobiel/desktop is er geen CORS-beperking voor netwerkafbeeldingen, dus
/// gewoon Image.network gebruiken.
Widget buildNetworkImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext)? placeholder,
}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : (placeholder?.call(context) ?? const SizedBox.shrink()),
    errorBuilder: (context, error, stack) =>
        placeholder?.call(context) ?? const SizedBox.shrink(),
  );
}
