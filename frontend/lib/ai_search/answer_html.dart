import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../collection/collection_search.dart';
import '../collection/img_embed/img_embed.dart';
import 'answer_image_dialog.dart';
import 'answer_source_dialog.dart';

class AnswerHtml extends StatelessWidget {
  const AnswerHtml(this.html, {this.source, super.key});
  final String html;
  final CollectionSearchSource? source;
  @override
  Widget build(BuildContext context) => HtmlWidget(
    html,
    customWidgetBuilder: (element) {
      if (element.localName != 'img') return null;
      final imageUrl = element.attributes['src'];
      if (imageUrl == null || imageUrl.isEmpty) return null;
      final description = element.attributes['alt']?.trim();
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
                child: Tooltip(
                  message: 'Foto vergroten',
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.zoomIn,
                    onTap: () => showAnswerImage(
                      context,
                      imageUrl: imageUrl,
                      description: description?.isNotEmpty == true
                          ? description
                          : null,
                    ),
                    child: buildNetworkImage(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
    onTapUrl: (url) async {
      if (url.startsWith('#') && !url.startsWith('#/')) return false;
      await showAnswerSource(
        context,
        url: url,
        source: source ?? AnswerSourceScope.maybeOf(context),
      );
      return true;
    },
    textStyle: Theme.of(context).textTheme.bodyLarge,
  );
}
