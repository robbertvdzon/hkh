import 'package:flutter/widgets.dart';

/// Registers the supplied, unmodified oblique aerial photos on one image plane.
///
/// The historical photo is the reference plane. An affine transform pins three
/// visible points of the church: the spire tip, the foot of the tower at its
/// junction with the nave, and the far right roof eave. This also compensates
/// for the different horizontal scale and slight shear in the modern AI view.
/// The surveyed image points are approximate to the source pixels; the transform
/// places each selected pair at exactly the same scene coordinate. Perspective,
/// altered buildings, trees, and AI reconstruction prevent a survey-grade match
/// across the entire neighbourhood.
abstract final class AerialPhotoAlignment {
  static const currentSize = Size(1390, 1132);
  static const historicalSize = Size(1370, 1116);

  /// Source-pixel coordinates, measured from each original image's top left.
  static const churchAnchors = <({Offset current, Offset historical})>[
    (current: Offset(738, 182), historical: Offset(745, 194)),
    (current: Offset(740, 359), historical: Offset(755, 370)),
    (current: Offset(800, 342), historical: Offset(841, 345)),
  ];

  /// Largest whole-pixel vertical interval shared across the historical width.
  /// The transformed modern image's top is at y=81.43 on the left, and its
  /// bottom at y=1085.44 on the right. Cropping inward avoids empty corners.
  static const commonCrop = Rect.fromLTRB(0, 82, 1370, 1085);
  static const sceneSize = Size(1370, 1003);

  /// Church and immediate surroundings, expressed in the cropped scene plane.
  static const churchBounds = Rect.fromLTRB(690, 82, 900, 355);

  /// Modern source pixels to the cropped historical plane. Returning a fresh
  /// matrix keeps zoom/pan or painting callers from changing the registration.
  static Matrix4 get currentToScene => Matrix4.identity()
    ..setEntry(0, 0, 1.444715599774733)
    ..setEntry(0, 1, 0.04017270508729116)
    ..setEntry(0, 3, -328.5115449596396 - commonCrop.left)
    ..setEntry(1, 0, -0.1345034728740379)
    ..setEntry(1, 1, 0.9958700957386897)
    ..setEntry(1, 3, 112.0152055565985 - commonCrop.top);

  static Matrix4 get historicalToScene => Matrix4.identity()
    ..setEntry(0, 3, -commonCrop.left)
    ..setEntry(1, 3, -commonCrop.top);
}
