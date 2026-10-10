import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'aerial_book_photo_dialog.dart';
import 'aerial_photo_alignment.dart';

/// The photos are registered on the church before sharing one pan/zoom plane.
/// Changing the date never changes the view or the registration.
class AerialPhotoPage extends StatefulWidget {
  const AerialPhotoPage({super.key});

  @override
  State<AerialPhotoPage> createState() => _AerialPhotoPageState();
}

class _AerialPhotoPageState extends State<AerialPhotoPage> {
  static final _imageSize = AerialPhotoAlignment.sceneSize;
  static final _churchArea = AerialPhotoAlignment.churchBounds;
  static const _currentAsset = 'assets/aerial/heemskerk-62057-nu-ai.png';
  static const _historicalAsset = 'assets/aerial/heemskerk-62057-toen.png';

  final _transformation = TransformationController();
  AssetBundle? _bundle;
  ui.Image? _currentImage, _historicalImage;
  Size _viewport = Size.zero;
  bool _loading = true, _failed = false, _constraining = false;
  double _historicalOpacity = 0;
  int _loadRequest = 0, _layoutRequest = 0;

  double _fitScale(Size size) =>
      math.min(size.width / _imageSize.width, size.height / _imageSize.height);
  double get _minScale => _fitScale(_viewport);
  double get _maxScale => _minScale * 32;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_constrainTransformation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (!identical(bundle, _bundle)) {
      _bundle = bundle;
      _loadImages();
    }
  }

  Future<ui.Image> _decode(
    AssetBundle bundle,
    String path,
    Size expectedSize,
  ) async {
    final data = await bundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (image.width != expectedSize.width ||
          image.height != expectedSize.height) {
        image.dispose();
        throw StateError('The aerial photo does not match its registration.');
      }
      return image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _loadImages() async {
    final request = ++_loadRequest;
    final bundle = _bundle!;
    setState(() {
      _loading = true;
      _failed = false;
    });
    ui.Image? current, historical;
    try {
      current = await _decode(
        bundle,
        _currentAsset,
        AerialPhotoAlignment.currentSize,
      );
      historical = await _decode(
        bundle,
        _historicalAsset,
        AerialPhotoAlignment.historicalSize,
      );
      if (!mounted || request != _loadRequest) {
        current.dispose();
        historical.dispose();
        return;
      }
      final oldCurrent = _currentImage, oldHistorical = _historicalImage;
      setState(() {
        _currentImage = current;
        _historicalImage = historical;
        _loading = false;
      });
      oldCurrent?.dispose();
      oldHistorical?.dispose();
    } catch (_) {
      current?.dispose();
      historical?.dispose();
      if (mounted && request == _loadRequest) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _loadRequest++;
    _layoutRequest++;
    _transformation.removeListener(_constrainTransformation);
    _transformation.dispose();
    _currentImage?.dispose();
    _historicalImage?.dispose();
    super.dispose();
  }

  /// Keep letterboxed axes centered, and never pan beyond the image on axes
  /// that fill the viewport. This also bounds direct gestures and mouse zoom.
  void _constrainTransformation() {
    if (_constraining || _viewport.isEmpty) return;
    final matrix = _transformation.value;
    final scale = matrix.getMaxScaleOnAxis().clamp(_minScale, _maxScale);
    final x = _boundedTranslation(
      matrix.storage[12],
      _viewport.width,
      _imageSize.width * scale,
    );
    final y = _boundedTranslation(
      matrix.storage[13],
      _viewport.height,
      _imageSize.height * scale,
    );
    if ((matrix.storage[0] - scale).abs() < 0.000001 &&
        (matrix.storage[12] - x).abs() < 0.000001 &&
        (matrix.storage[13] - y).abs() < 0.000001) {
      return;
    }
    _constraining = true;
    _transformation.value = _matrix(scale, Offset(x, y));
    _constraining = false;
  }

  double _boundedTranslation(double value, double viewport, double image) =>
      image <= viewport
      ? (viewport - image) / 2
      : value.clamp(viewport - image, 0.0);

  Matrix4 _matrix(double scale, Offset offset) => Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(2, 2, scale)
    ..setEntry(0, 3, offset.dx)
    ..setEntry(1, 3, offset.dy);

  void _setView(double scale, Offset sceneCenter) {
    if (_viewport.isEmpty) return;
    final boundedScale = scale.clamp(_minScale, _maxScale);
    _transformation.value = _matrix(
      boundedScale,
      _viewport.center(Offset.zero) - sceneCenter * boundedScale,
    );
  }

  void _updateViewport(Size size) {
    if (size.isEmpty || size == _viewport) return;
    final oldSize = _viewport;
    final center = oldSize.isEmpty
        ? _imageSize.center(Offset.zero)
        : _transformation.toScene(oldSize.center(Offset.zero));
    final relativeScale = oldSize.isEmpty
        ? 1.0
        : _transformation.value.getMaxScaleOnAxis() / _fitScale(oldSize);
    _viewport = size;
    final request = ++_layoutRequest;
    // The controller also notifies InteractiveViewer. Notify after layout so
    // resizing cannot mark an ancestor dirty while it is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && request == _layoutRequest) {
        _setView(_minScale * relativeScale, center);
      }
    });
  }

  void _zoom(double factor) {
    if (_viewport.isEmpty) return;
    _setView(
      _transformation.value.getMaxScaleOnAxis() * factor,
      _transformation.toScene(_viewport.center(Offset.zero)),
    );
  }

  void _pan(Offset direction) {
    if (_viewport.isEmpty) return;
    final scale = _transformation.value.getMaxScaleOnAxis();
    final matrix = _transformation.value;
    _transformation.value = _matrix(
      scale,
      Offset(
        matrix.storage[12] - direction.dx * _viewport.width * 0.2,
        matrix.storage[13] - direction.dy * _viewport.height * 0.2,
      ),
    );
  }

  void _reset() => _setView(_minScale, _imageSize.center(Offset.zero));

  void _showChurch() => _setView(
    math.min(
          _viewport.width / _churchArea.width,
          _viewport.height / _churchArea.height,
        ) *
        0.88,
    _churchArea.center,
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: appSurfaceTheme(context),
    child: Scaffold(
      backgroundColor: appBackground,
      appBar: HkhAppBar(context: context, title: const Text('Luchtfoto')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewerHeight = (constraints.maxHeight * 0.62).clamp(
              260.0,
              620.0,
            );
            return SingleChildScrollView(
              padding: EdgeInsets.all(isNarrowLayout(context) ? 16 : 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Heemskerk van nu en toen',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontFamily: 'HkhSerif', color: appGreen),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Verschuif de foto en zoom in. Met de schuifbalk '
                        'laat je nu en toen in elkaar overvloeien.',
                      ),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: appCardBorder),
                          borderRadius: BorderRadius.circular(appCardRadius),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(appCardRadius),
                          child: SizedBox(
                            height: viewerHeight,
                            child: _buildViewer(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildControls(),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: Text('Nu · AI-bewerking')),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text('Rond 1963', textAlign: TextAlign.end),
                          ),
                        ],
                      ),
                      Slider(
                        key: const Key('aerial-slider'),
                        value: _historicalOpacity,
                        label: '${(_historicalOpacity * 100).round()}% toen',
                        semanticFormatterCallback: (value) =>
                            '${(value * 100).round()} procent historisch beeld',
                        onChanged: _loading || _failed
                            ? null
                            : (value) =>
                                  setState(() => _historicalOpacity = value),
                      ),
                      const Text(
                        'De foto’s zijn uitgelijnd op de Dorpskerk. '
                        'De moderne foto is met AI aangepast aan de oude '
                        'kijkhoek; details in de omgeving kunnen afwijken.',
                        style: TextStyle(color: appMutedText),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bronnen: aangeleverde historische foto (rond 1963) '
                        'en AI-bewerking van een Google Earth-opname.',
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
  );

  Widget _buildViewer() {
    if (_loading) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Luchtfoto’s laden'),
        ),
      );
    }
    if (_failed) {
      return ColoredBox(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined, color: appMutedText),
                const SizedBox(height: 8),
                const Text(
                  'De luchtfoto’s konden niet worden geladen.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loadImages,
                  child: const Text('Opnieuw proberen'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _updateViewport(size);
        return ColoredBox(
          color: Colors.white,
          child: Semantics(
            label: 'Luchtfoto van Heemskerk, verschuifbaar en zoombaar',
            image: true,
            // Slepen moet de foto verschuiven, geen tekst selecteren.
            child: SelectionContainer.disabled(
              child: InteractiveViewer(
                key: const Key('aerial-viewer'),
                transformationController: _transformation,
                constrained: false,
                alignment: Alignment.topLeft,
                minScale: _fitScale(size),
                maxScale: _fitScale(size) * 32,
                // The shared controller applies exact image/viewport bounds,
                // including centering on axes with unused white space.
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  width: _imageSize.width,
                  height: _imageSize.height,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: AerialPhotoAlignment.currentSize.width,
                        height: AerialPhotoAlignment.currentSize.height,
                        child: Transform(
                          alignment: Alignment.topLeft,
                          transform: AerialPhotoAlignment.currentToScene,
                          child: RawImage(
                            image: _currentImage,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        width: AerialPhotoAlignment.historicalSize.width,
                        height: AerialPhotoAlignment.historicalSize.height,
                        child: Opacity(
                          key: const Key('aerial-historical-layer'),
                          opacity: _historicalOpacity,
                          child: Transform(
                            alignment: Alignment.topLeft,
                            transform: AerialPhotoAlignment.historicalToScene,
                            child: RawImage(
                              image: _historicalImage,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.medium,
                            ),
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
      },
    );
  }

  Widget _buildControls() {
    final enabled = !_loading && !_failed;
    Widget control(
      String key,
      String label,
      IconData icon,
      VoidCallback action,
    ) => IconButton.outlined(
      key: Key(key),
      tooltip: label,
      onPressed: enabled ? action : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const Key('aerial-book-photos'),
          onPressed: () => showAerialBookPhotos(context),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Bronfoto’s (7)'),
        ),
        control('aerial-zoom-in', 'Inzoomen', Icons.add, () => _zoom(1.5)),
        control(
          'aerial-zoom-out',
          'Uitzoomen',
          Icons.remove,
          () => _zoom(1 / 1.5),
        ),
        control('aerial-pan-left', 'Naar links', Icons.arrow_back, () {
          _pan(const Offset(-1, 0));
        }),
        control('aerial-pan-right', 'Naar rechts', Icons.arrow_forward, () {
          _pan(const Offset(1, 0));
        }),
        control('aerial-pan-up', 'Omhoog', Icons.arrow_upward, () {
          _pan(const Offset(0, -1));
        }),
        control('aerial-pan-down', 'Omlaag', Icons.arrow_downward, () {
          _pan(const Offset(0, 1));
        }),
        OutlinedButton.icon(
          key: const Key('aerial-reset'),
          onPressed: enabled ? _reset : null,
          icon: const Icon(Icons.fit_screen),
          label: const Text('Hele foto'),
        ),
        OutlinedButton.icon(
          key: const Key('aerial-church'),
          onPressed: enabled ? _showChurch : null,
          icon: const Icon(Icons.church_outlined),
          label: const Text('Dorpskerk'),
        ),
      ],
    );
  }
}
