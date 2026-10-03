import 'package:flutter/material.dart';

import '../theme/app_style.dart';

Future<void> showAerialBookPhotos(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const AerialBookPhotoDialog(),
);

class _BookPhoto {
  const _BookPhoto(this.number, this.year, this.area, this.partlyOnMap);

  final String number;
  final int year;
  final String area;
  final bool partlyOnMap;

  String get asset => 'assets/aerial/book/$year-$number.jpeg';
}

const _photos = [
  _BookPhoto('62057', 1963, 'Dorpskerk, Zaalberglaan en Poelenburg', true),
  _BookPhoto(
    '62058',
    1963,
    'Dorpskerk, Ruysdaelstraat en Cornelis Groenlandstraat',
    true,
  ),
  _BookPhoto(
    '62059',
    1963,
    'Maerelaan, Laurentiuskerk en Dr. Prinsensporthal',
    false,
  ),
  _BookPhoto('64797', 1964, 'Dorpskern, Neksloot en omgeving', true),
  _BookPhoto('67781', 1965, 'Kerkbeek, Mariakerk en Jhr. Geverslaan', true),
  _BookPhoto('67782', 1965, 'Kasteel Assumburg, Tolweg en Hoflaan', false),
  _BookPhoto(
    '67783',
    1965,
    'Wijk Assumburg en Gerrit van Assendelftstraat',
    false,
  ),
];

/// Shows the supplied book pages intact; this viewer does not georeference them.
class AerialBookPhotoDialog extends StatefulWidget {
  const AerialBookPhotoDialog({super.key});

  @override
  State<AerialBookPhotoDialog> createState() => _AerialBookPhotoDialogState();
}

class _AerialBookPhotoDialogState extends State<AerialBookPhotoDialog> {
  final _transformation = TransformationController();
  int _selected = 0;
  Size _viewport = Size.zero;

  _BookPhoto get _photo => _photos[_selected];

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _selected || index < 0 || index >= _photos.length) return;
    setState(() => _selected = index);
    _reset();
  }

  void _reset() => _transformation.value = Matrix4.identity();

  void _zoom(double factor) {
    if (_viewport.isEmpty) return;
    final center = _viewport.center(Offset.zero);
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
  Widget build(BuildContext context) => Theme(
    data: appSurfaceTheme(context),
    child: Dialog.fullscreen(
      key: const Key('aerial-book-dialog'),
      child: Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          backgroundColor: appHeaderBackground,
          foregroundColor: appHeaderForeground,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            key: const Key('aerial-book-close'),
            tooltip: 'Bronfoto’s sluiten',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          title: const Text('Bronfoto’s', maxLines: 1),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewerHeight = (constraints.maxHeight * 0.62).clamp(
                280.0,
                720.0,
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Bronfoto',
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              key: const Key('aerial-book-select'),
                              value: _selected,
                              isExpanded: true,
                              isDense: true,
                              itemHeight: null,
                              menuMaxHeight: 420,
                              selectedItemBuilder: (context) => [
                                for (var i = 0; i < _photos.length; i++)
                                  Text('${i + 1} / 7 · ${_photos[i].number}'),
                              ],
                              items: [
                                for (var i = 0; i < _photos.length; i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        '${_photos[i].year} · ${_photos[i].number}',
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (index) {
                                if (index != null) _select(index);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_photo.year} · Boekfoto ${_photo.number}',
                          key: const Key('aerial-book-title'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontFamily: 'HkhSerif',
                                color: appGreen,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(_photo.area, key: const Key('aerial-book-area')),
                        const SizedBox(height: 8),
                        Text(
                          _photo.partlyOnMap
                              ? 'Deels op de kaart'
                              : 'Nog niet betrouwbaar uitgelijnd',
                          key: const Key('aerial-book-status'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _photo.partlyOnMap
                              ? 'Alleen het geplaatste deel is opgenomen in de kaart.'
                              : 'Deze foto staat nog niet op de kaart. Je kunt het origineel hier bekijken en inzoomen.',
                          style: const TextStyle(color: appMutedText),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(appCardRadius),
                          child: SizedBox(
                            height: viewerHeight,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = constraints.biggest;
                                if (_viewport != Size.zero &&
                                    _viewport != size) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) _reset();
                                  });
                                }
                                _viewport = size;
                                return ColoredBox(
                                  color: Colors.white,
                                  child: InteractiveViewer(
                                    key: const Key('aerial-book-viewer'),
                                    transformationController: _transformation,
                                    minScale: 1,
                                    maxScale: 12,
                                    child: SizedBox.expand(
                                      child: Image.asset(
                                        _photo.asset,
                                        key: ValueKey(_photo.asset),
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        semanticLabel:
                                            'Originele boekfoto ${_photo.number}, ${_photo.year}',
                                        errorBuilder:
                                            (
                                              context,
                                              error,
                                              stackTrace,
                                            ) => const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16),
                                                child: Text(
                                                  'Deze bronfoto kon niet worden geladen.',
                                                  textAlign: TextAlign.center,
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
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('aerial-book-previous'),
                              onPressed: _selected == 0
                                  ? null
                                  : () => _select(_selected - 1),
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Vorige'),
                            ),
                            OutlinedButton.icon(
                              key: const Key('aerial-book-next'),
                              onPressed: _selected == _photos.length - 1
                                  ? null
                                  : () => _select(_selected + 1),
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Volgende'),
                            ),
                            IconButton.outlined(
                              key: const Key('aerial-book-zoom-in'),
                              tooltip: 'Bronfoto inzoomen',
                              onPressed: () => _zoom(1.5),
                              icon: const Icon(Icons.add),
                            ),
                            IconButton.outlined(
                              key: const Key('aerial-book-zoom-out'),
                              tooltip: 'Bronfoto uitzoomen',
                              onPressed: () => _zoom(1 / 1.5),
                              icon: const Icon(Icons.remove),
                            ),
                            OutlinedButton.icon(
                              key: const Key('aerial-book-reset'),
                              onPressed: _reset,
                              icon: const Icon(Icons.fit_screen),
                              label: const Text('Hele foto'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Ongewijzigde foto’s van de boekpagina’s. Jaartallen volgens de boekonderschriften; HKH vermeldt voor de drie foto’s uit 1963 het jaar 1962.',
                          style: TextStyle(color: appMutedText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
