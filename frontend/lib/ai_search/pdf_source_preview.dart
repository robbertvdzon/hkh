import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_style.dart';

/// A first-page image works on mobile browsers without an embedded PDF viewer.
class PdfSourcePreview extends StatefulWidget {
  const PdfSourcePreview({required this.pdfUrl, this.thumbnailUrl, super.key});

  final String pdfUrl;
  final String? thumbnailUrl;

  @override
  State<PdfSourcePreview> createState() => _PdfSourcePreviewState();
}

class _PdfSourcePreviewState extends State<PdfSourcePreview> {
  bool _openFailed = false;

  Future<void> _openPdf() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(widget.pdfUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      // Keep the preview and source popup open when the browser refuses a tab.
    }
    if (mounted) setState(() => _openFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = widget.thumbnailUrl?.trim();
    return SelectionContainer.disabled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(appCardRadius),
              side: const BorderSide(color: appCardBorder),
            ),
            child: Semantics(
              button: true,
              label: 'Eerste pagina van de PDF. Open de volledige PDF.',
              child: InkWell(
                key: const Key('source-pdf-preview'),
                onTap: _openPdf,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      width: double.infinity,
                      height: (constraints.maxWidth * 1.3).clamp(240.0, 560.0),
                      child: thumbnail == null || thumbnail.isEmpty
                          ? const _UnavailablePreview()
                          : Image.network(
                              thumbnail,
                              key: const Key('source-pdf-thumbnail'),
                              fit: BoxFit.contain,
                              semanticLabel: 'Eerste pagina van de PDF',
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                              errorBuilder: (context, error, stack) =>
                                  const _UnavailablePreview(),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Eerste pagina · klik om de volledige PDF te openen.',
            style: TextStyle(color: appMutedText),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('source-pdf-open'),
              onPressed: _openPdf,
              icon: const Icon(Icons.open_in_new),
              label: const Text('PDF openen'),
            ),
          ),
          if (_openFailed) ...[
            const SizedBox(height: 8),
            const Text(
              'De PDF kon niet worden geopend. Probeer het opnieuw.',
              style: TextStyle(color: appErrorForeground),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnavailablePreview extends StatelessWidget {
  const _UnavailablePreview();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.picture_as_pdf_outlined, size: 40, color: appMutedText),
        SizedBox(height: 12),
        Text(
          'Voorbeeld niet beschikbaar.\nDe volledige PDF kunt u wel openen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: appMutedText),
        ),
      ],
    ),
  );
}
