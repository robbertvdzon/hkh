import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../collection/img_embed/img_embed.dart';

class AnswerHtml extends StatelessWidget {
  const AnswerHtml(this.html, {super.key});
  final String html;
  @override
  Widget build(BuildContext context) => HtmlWidget(
    html,
    customWidgetBuilder: (element) {
      if (element.localName != 'img') return null;
      final imageUrl = element.attributes['src'];
      if (imageUrl == null || imageUrl.isEmpty) return null;
      final linkUrl = element.parent?.localName == 'a'
          ? element.parent?.attributes['href']
          : null;
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 640.0;
          final height = (width * 0.72).clamp(220.0, 520.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: buildNetworkImage(
                  imageUrl,
                  fit: BoxFit.contain,
                  linkUrl: linkUrl,
                ),
              ),
            ),
          );
        },
      );
    },
    onTapUrl: (url) =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    textStyle: Theme.of(context).textTheme.bodyLarge,
  );
}
