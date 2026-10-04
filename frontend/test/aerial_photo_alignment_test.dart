import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/aerial/aerial_photo_alignment.dart';

void main() {
  test(
    'church tip, tower foot and far roof corner occupy identical points',
    () {
      for (final anchor in AerialPhotoAlignment.churchAnchors) {
        final current = MatrixUtils.transformPoint(
          AerialPhotoAlignment.currentToScene,
          anchor.current,
        );
        final historical = MatrixUtils.transformPoint(
          AerialPhotoAlignment.historicalToScene,
          anchor.historical,
        );
        expect((current - historical).distance, lessThan(1e-9));
        expect(AerialPhotoAlignment.churchBounds.contains(current), isTrue);
      }
    },
  );

  test('both source images cover every corner of the common crop', () {
    final sceneRect = Offset.zero & AerialPhotoAlignment.sceneSize;
    expect(
      AerialPhotoAlignment.sceneSize,
      AerialPhotoAlignment.commonCrop.size,
    );
    for (final source in [
      (AerialPhotoAlignment.currentSize, AerialPhotoAlignment.currentToScene),
      (
        AerialPhotoAlignment.historicalSize,
        AerialPhotoAlignment.historicalToScene,
      ),
    ]) {
      final inverse = Matrix4.inverted(source.$2);
      for (final point in [
        sceneRect.topLeft,
        sceneRect.topRight,
        sceneRect.bottomRight,
        sceneRect.bottomLeft,
      ]) {
        final sourcePoint = MatrixUtils.transformPoint(inverse, point);
        expect(sourcePoint.dx, inInclusiveRange(0, source.$1.width));
        expect(sourcePoint.dy, inInclusiveRange(0, source.$1.height));
      }
    }
  });
}
