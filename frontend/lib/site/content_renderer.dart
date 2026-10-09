import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../content/content_models.dart';
import '../theme/app_style.dart';
import 'site_widgets.dart';

/// Toont de inhoudsblokken van een pagina in leesvolgorde.
class ContentBlocks extends StatelessWidget {
  const ContentBlocks(this.blocks, {super.key});
  final List<ContentBlock> blocks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in blocks)
        Padding(
          padding: EdgeInsets.only(bottom: block is ImageBlock ? 20 : 14),
          child: switch (block) {
            HeadingBlock(:final text, :final level) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: appSerifFont,
                  fontSize: level <= 2 ? 24 : 20,
                  color: appGreen,
                  height: 1.3,
                ),
              ),
            ),
            ParagraphBlock(:final strong) when strong => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                block.text,
                style: const TextStyle(
                  fontFamily: appSerifFont,
                  fontSize: 20,
                  color: appGreen,
                  height: 1.3,
                ),
              ),
            ),
            ParagraphBlock() => LinkedText(block.text, links: block.links),
            ImageBlock(:final src, :final caption) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SiteImage(
                  src,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  borderRadius: BorderRadius.circular(12),
                ),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      caption,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        color: appMutedText,
                      ),
                    ),
                  ),
              ],
            ),
            ListBlock(:final items, :final ordered) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            ordered ? '${i + 1}.' : '•',
                            style: const TextStyle(color: appGreen),
                          ),
                        ),
                        Expanded(child: Text(items[i], style: _bodyStyle)),
                      ],
                    ),
                  ),
              ],
            ),
          },
        ),
    ],
  );
}

const _bodyStyle = TextStyle(fontSize: 16.5, height: 1.55);

/// Alinea waarin de linkteksten aanklikbaar zijn.
class LinkedText extends StatefulWidget {
  const LinkedText(this.text, {this.links = const [], super.key});
  final String text;
  final List<ContentLink> links;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    if (widget.links.isEmpty) {
      return SelectableText(widget.text, style: _bodyStyle);
    }
    final spans = <InlineSpan>[];
    var rest = widget.text;
    final links = [...widget.links]
      ..sort((a, b) => widget.text.indexOf(a.text).compareTo(widget.text.indexOf(b.text)));
    for (final link in links) {
      final index = rest.indexOf(link.text);
      if (index < 0 || link.text.isEmpty) continue;
      if (index > 0) spans.add(TextSpan(text: rest.substring(0, index)));
      final recognizer = TapGestureRecognizer()
        ..onTap = () => openLink(context, link.href);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: link.text,
          style: const TextStyle(
            color: appGreen,
            decoration: TextDecoration.underline,
            decorationColor: appGreen,
          ),
          recognizer: recognizer,
        ),
      );
      rest = rest.substring(index + link.text.length);
    }
    if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
    return Text.rich(
      TextSpan(style: _bodyStyle.copyWith(color: appHeaderBackground), children: spans),
    );
  }
}
