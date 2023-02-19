import 'package:flutter/widgets.dart';
import 'package:mapsforge_flutter/core.dart';
import 'package:mapsforge_flutter/src/graphics/display.dart';
import 'package:mapsforge_flutter/src/graphics/resourcebitmap.dart';
import 'package:mapsforge_flutter/src/rendertheme/shape/bitmapsrcmixin.dart';

import '../../special.dart';
import '../graphics/cap.dart';
import '../graphics/join.dart';
import 'basicmarker.dart';
import 'markercallback.dart';

class PoiMarker<T> extends BasicPointMarker<T> with BitmapSrcMixin {
  double _imageOffsetX = 0;

  double _imageOffsetY = 0;

  double rotation;

  ResourceBitmap? bitmap;

  MapPaint? paint;

  PoiMarker({
    Display display = Display.ALWAYS,
    required String src,
    double width = 20,
    double height = 20,
    required ILatLong latLong,
    int minZoomLevel = 0,
    int maxZoomLevel = 65535,
    int bitmapColor = 0xff000000,
    this.rotation = 0,
    T? item,
    MarkerCaption? markerCaption,
    required DisplayModel displayModel,
    Alignment alignment = Alignment.center,
  })  : assert(minZoomLevel >= 0),
        assert(maxZoomLevel <= 65535),
        assert(rotation >= 0 && rotation <= 360),
        assert(width > 0),
        assert(height > 0),
        super(
          markerCaption: markerCaption,
          display: display,
          minZoomLevel: minZoomLevel,
          maxZoomLevel: maxZoomLevel,
          item: item,
          latLong: latLong,
          alignment: alignment,
        ) {
    this.bitmapSrc = src;
    this.setBitmapWidth((width * displayModel.getFontScaleFactor()).round());
    this.setBitmapHeight((height * displayModel.getFontScaleFactor()).round());
    setBitmapColorFromNumber(bitmapColor);
  }

  @override
  @mustCallSuper
  void dispose() {
    bitmap?.dispose();
    bitmap = null;
    super.dispose();
  }

  Future<void> initResources(SymbolCache symbolCache) async {
    bitmap?.dispose();
    bitmap = null;
    setBitmapMinZoomLevel(DisplayModel.STROKE_MIN_ZOOMLEVEL_TEXT);
    paint = createPaint(style: Style.FILL);
    bitmap = await createBitmap(
        symbolCache: symbolCache,
        bitmapSrc: bitmapSrc!,
        bitmapWidth: getBitmapWidth(),
        bitmapHeight: getBitmapHeight());
    if (bitmap != null) {
      double centerX = bitmap!.getWidth() / 2;
      double centerY = bitmap!.getHeight() / 2;

      _imageOffsetX = -(alignment.x * centerX + centerX);
      _imageOffsetY = -(alignment.y * centerY + centerY);

      if (markerCaption != null) {
        markerCaption!
            .setDy(bitmap!.getHeight() / 2 + markerCaption!.getFontSize() / 2);
      }
    }
  }

  /// copied from ShapePaint
  Future<ResourceBitmap?> createBitmap(
      {required SymbolCache symbolCache,
      required String bitmapSrc,
      required int bitmapWidth,
      required int bitmapHeight}) async {
    ResourceBitmap? resourceBitmap = await symbolCache.getOrCreateSymbol(
        bitmapSrc, bitmapWidth, bitmapHeight);
    return resourceBitmap;
  }

  /// copie from ShapePaint
  MapPaint createPaint(
      {required Style style,

      /// The color of the paint. Default is black
      int color = 0xff000000,

      /// strokeWidth must be zero for fillers when used for text. See [ParagraphEntry]
      double? strokeWidth,
      Cap cap = Cap.ROUND,
      Join join = Join.ROUND,
      List<double>? strokeDashArray}) {
    MapPaint result = GraphicFactory().createPaint();
    result.setStyle(style);
    result.setColorFromNumber(color);
    result.setStrokeWidth(strokeWidth ?? (style == Style.STROKE ? 1 : 0));
    result.setStrokeCap(cap);
    result.setStrokeJoin(join);
    result.setStrokeDasharray(strokeDashArray);
    result.setAntiAlias(true);
    return result;
  }

  @override
  void setMarkerCaption(MarkerCaption? markerCaption) {
    if (markerCaption != null) {
      if (bitmap != null) {
        markerCaption
            .setDy(bitmap!.getHeight() / 2 + markerCaption.getFontSize() / 2);
      }
    }
    super.setMarkerCaption(markerCaption);
  }

  Future<void> setAndLoadBitmapSrc(
      String bitmapSrc, SymbolCache symbolCache) async {
    super.setBitmapSrc(bitmapSrc);
    await initResources(symbolCache);
  }

  @override
  void renderBitmap(MarkerCallback markerCallback) {
    if (bitmap != null) {
      markerCallback.renderBitmap(bitmap!, latLong.latitude, latLong.longitude,
          _imageOffsetX, _imageOffsetY, rotation, paint!);
    }
  }

  @override
  bool isTapped(TapEvent tapEvent) {
    double y = tapEvent.projection.latitudeToPixelY(latLong.latitude);
    double x = tapEvent.projection.longitudeToPixelX(latLong.longitude);
    x = x + _imageOffsetX;
    y = y + _imageOffsetY;
    return tapEvent.mapPixelMappoint.x >= x &&
        tapEvent.mapPixelMappoint.x <= x + getBitmapWidth() &&
        tapEvent.mapPixelMappoint.y >= y &&
        tapEvent.mapPixelMappoint.y <= y + getBitmapHeight();
  }
}
