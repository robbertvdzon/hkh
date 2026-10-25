import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Op mobiel/desktop is er geen CORS-beperking voor netwerkafbeeldingen, dus
/// gewoon Image.network gebruiken.
Widget buildNetworkImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext)? placeholder,
  String? linkUrl,
}) {
  final image = Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : (placeholder?.call(context) ?? const SizedBox.shrink()),
    errorBuilder: (context, error, stack) =>
        placeholder?.call(context) ?? const SizedBox.shrink(),
  );
  if (linkUrl == null) return image;
  return InkWell(
    onTap: () =>
        launchUrl(Uri.parse(linkUrl), mode: LaunchMode.externalApplication),
    child: image,
  );
}
