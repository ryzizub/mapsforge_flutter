import 'dart:math';

import 'package:mapsforge_flutter/src/model/maprectangle.dart';
import 'package:mapsforge_flutter/src/rendertheme/shape/shape.dart';

import '../../graphics/position.dart';
import '../../renderer/paintmixin.dart';
import '../renderinstruction/textkey.dart';
import '../xml/rulebuilder.dart';
import 'paintsrcmixin.dart';
import 'textsrcmixin.dart';

class ShapeCaption extends Shape with PaintSrcMixin, TextSrcMixin {
  double _horizontalOffset = 0;

  double _verticalOffset = 0;

  int level = 0;

  late double gap;

  /// The position of this caption relative to the corresponding symbol. If the symbol is not set
  /// the position is always center
  Position position = Position.CENTER;

  String? symbolId;

  SymbolHolder? symbolHolder;

  TextKey? textKey;

  double dy = 0;

  /// The width of the caption. Since we cannot calculate the width in an isolate (ui calls are not allowed)
  /// we need to set it later on in the ShapePaintCaption
  double _boxWidth = 0;

  /// The height of the caption. Since we cannot calculate the height in an isolate (ui calls are not allowed)
  /// we need to set it later on in the ShapePaintCaption
  double _boxHeight = 0;

  ShapeCaption.base() : super.base();

  ShapeCaption.scale(ShapeCaption base, int zoomLevel)
      : super.scale(base, zoomLevel) {
    paintSrcMixinScale(base, zoomLevel);
    textSrcMixinScale(base, zoomLevel);
    _horizontalOffset = base._horizontalOffset;
    _verticalOffset = base._verticalOffset;
    gap = base.gap;
    position = base.position;
    priority = base.priority;
    symbolId = base.symbolId;
    textKey = base.textKey;
    dy = base.dy;
    level = base.level;
// do NOT copy symbolHolder. It is dependent on the zoomLevel

    if (zoomLevel >= strokeMinZoomLevel) {
      int zoomLevelDiff = zoomLevel - strokeMinZoomLevel + 1;
      double scaleFactor =
          pow(PaintMixin.STROKE_INCREASE, zoomLevelDiff) as double;
      gap = gap * scaleFactor;
      dy = dy * scaleFactor;
    }
  }

  void setDy(double dy) {
    this.dy = dy;
  }

  @override
  MapRectangle calculateBoundary() {
    if (boundary != null) return boundary!;
    boundary = MapRectangle(
        -_boxWidth / 2 + _horizontalOffset,
        -_boxHeight / 2 + _verticalOffset,
        _boxWidth / 2 + _horizontalOffset,
        _boxHeight / 2 + _verticalOffset);

    return boundary!;
  }

  void calculateOffsets() {
    _verticalOffset = 0;
    _horizontalOffset = 0;
    // print(
    //     "shapeCaption in calculateOffsets pos $position, symbolHolder: $symbolHolder, captionBoundary: $_boxWidth, $_boxHeight");

    if (position == Position.CENTER &&
        symbolHolder?.shapeSymbol?.bitmapSrc != null) {
      // sensible defaults: below if symbolContainer is present, center if not
      position = Position.BELOW;
    }
    MapRectangle? symbolBoundary =
        symbolHolder?.shapeSymbol?.calculateBoundary();
    if (symbolBoundary == null) {
      position = Position.CENTER;
      return;
    }

    switch (position) {
      case Position.CENTER:
        break;
      case Position.BELOW:
        _verticalOffset += symbolBoundary.bottom + _boxHeight / 2 + this.gap;
        break;
      case Position.ABOVE:
        _verticalOffset += symbolBoundary.top - _boxHeight / 2 - this.gap;
        break;
      case Position.BELOW_LEFT:
        _horizontalOffset += symbolBoundary.left - _boxWidth / 2 - this.gap;
        _verticalOffset += symbolBoundary.bottom + _boxHeight / 2 + this.gap;
        break;
      case Position.ABOVE_LEFT:
        _horizontalOffset += symbolBoundary.left - _boxWidth / 2 - this.gap;
        _verticalOffset += symbolBoundary.top - _boxHeight / 2 - this.gap;
        break;
      case Position.LEFT:
        _horizontalOffset += symbolBoundary.left - _boxWidth / 2 - this.gap;
        break;
      case Position.BELOW_RIGHT:
        _horizontalOffset += symbolBoundary.right + _boxWidth / 2 + this.gap;
        _verticalOffset += symbolBoundary.bottom + _boxHeight / 2 + this.gap;
        break;
      case Position.ABOVE_RIGHT:
        _horizontalOffset += symbolBoundary.right + _boxWidth / 2 + this.gap;
        _verticalOffset += symbolBoundary.top - _boxHeight / 2 - this.gap;
        break;
      case Position.RIGHT:
        _horizontalOffset += symbolBoundary.right + _boxWidth / 2 + this.gap;
        break;
      default:
        throw new Exception("Position invalid");
    }
    boundary = null;
  }

  @override
  String getShapeType() {
    return "Caption";
  }

  void setTextBoundary(double width, double height) {
    _boxWidth = width;
    _boxHeight = height;
    calculateOffsets();
  }
}
