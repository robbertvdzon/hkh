import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../collection/img_embed/img_embed.dart';
import '../theme/app_style.dart';

Future<void> showAnswerImage(
  BuildContext context, {
  required String imageUrl,
  String? description,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      AnswerImageDialog(imageUrl: imageUrl, description: description),
);

class AnswerImageDialog extends StatefulWidget {
  const AnswerImageDialog({
    required this.imageUrl,
    this.description,
    super.key,
  });

  final String imageUrl;
  final String? description;

  @override
  State<AnswerImageDialog> createState() => _AnswerImageDialogState();
}

class _AnswerImageDialogState extends State<AnswerImageDialog> {
  final _transformation = TransformationController();
  Size _viewport = Size.zero;
  Offset? _doubleTapPosition;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _reset() => _transformation.value = Matrix4.identity();

  void _zoom(double factor, {Offset? focalPoint}) {
    if (_viewport.isEmpty) return;
    final center = focalPoint ?? _viewport.center(Offset.zero);
    final sceneCenter = _transformation.toScene(center);
    final scale = (_transformation.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      12.0,
    );
    final offset = center - sceneCenter * scale;
    _transformation.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setEntry(0, 3, offset.dx.clamp(_viewport.width * (1 - scale), 0.0))
      ..setEntry(1, 3, offset.dy.clamp(_viewport.height * (1 - scale), 0.0));
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).pop(),
    },
    child: Focus(
      autofocus: true,
      child: Dialog.fullscreen(
        key: const Key('answer-image-dialog'),
        child: Scaffold(
          backgroundColor: appHeaderBackground,
          appBar: AppBar(
            backgroundColor: appHeaderBackground,
            foregroundColor: appHeaderForeground,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              key: const Key('answer-image-close'),
              tooltip: 'Foto sluiten',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
            title: const Text('Foto bekijken'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      if (_viewport != Size.zero && _viewport != size) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _reset();
                        });
                      }
                      _viewport = size;
                      return GestureDetector(
                        onDoubleTapDown: (details) =>
                            _doubleTapPosition = details.localPosition,
                        onDoubleTap: () {
                          if (_transformation.value.getMaxScaleOnAxis() > 1) {
                            _reset();
                          } else {
                            _zoom(2.5, focalPoint: _doubleTapPosition);
                          }
                        },
                        child: InteractiveViewer(
                          key: const Key('answer-image-viewer'),
                          transformationController: _transformation,
                          minScale: 1,
                          maxScale: 12,
                          trackpadScrollCausesScale: true,
                          child: SizedBox.expand(
                            child: Semantics(
                              image: true,
                              label: widget.description ?? 'Archieffoto',
                              child: buildNetworkImage(
                                widget.imageUrl,
                                fit: BoxFit.contain,
                                placeholder: (_) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'De foto is niet beschikbaar.',
                                      style: TextStyle(
                                        color: appHeaderForeground,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ColoredBox(
                  color: appBackground,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton.outlined(
                              key: const Key('answer-image-zoom-out'),
                              tooltip: 'Uitzoomen',
                              onPressed: () => _zoom(1 / 1.5),
                              icon: const Icon(Icons.remove),
                            ),
                            IconButton.outlined(
                              key: const Key('answer-image-zoom-in'),
                              tooltip: 'Inzoomen',
                              onPressed: () => _zoom(1.5),
                              icon: const Icon(Icons.add),
                            ),
                            TextButton.icon(
                              key: const Key('answer-image-reset'),
                              onPressed: _reset,
                              icon: const Icon(Icons.fit_screen),
                              label: const Text('Hele foto'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Zoom met twee vingers, dubbelklik of gebruik + en −.',
                          style: TextStyle(color: appMutedText),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
