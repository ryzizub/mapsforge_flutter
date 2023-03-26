import 'package:flutter/widgets.dart';
import 'package:mapsforge_flutter/core.dart';
import 'package:mapsforge_flutter/src/graphics/display.dart';

import '../../datastore.dart';
import '../paintelements/shape_paint_symbol.dart';
import '../rendertheme/nodeproperties.dart';
import '../rendertheme/shape/shape_symbol.dart';
import 'basicmarker.dart';
import 'markercallback.dart';

class PoiMarker<T> extends BasicPointMarker<T> {
  late ShapePaintSymbol shapePaint;

  late NodeProperties nodeProperties;

  late ShapeSymbol base;

  int _lastZoom = -1;

  ShapeSymbol? scaled;

  PoiMarker({
    Display display = Display.ALWAYS,
    required String src,
    double width = 20,
    double height = 20,
    required ILatLong latLong,
    int minZoomLevel = 0,
    int maxZoomLevel = 65535,
    int bitmapColor = 0xff000000,
    double rotation = 0,
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
    base = ShapeSymbol.base();
    setLatLong(latLong);
    base.bitmapSrc = src;
    base.setBitmapColorFromNumber(bitmapColor);
    base.setBitmapMinZoomLevel(DisplayModel.STROKE_MIN_ZOOMLEVEL_TEXT);
    //base.theta = ;
    base.setBitmapWidth((width * displayModel.getFontScaleFactor()).round());
    base.setBitmapHeight((height * displayModel.getFontScaleFactor()).round());
//    setBitmapColorFromNumber(bitmapColor);
    if (markerCaption != null) {
      markerCaption.latLong = latLong;
    }
    if (markerCaption != null) {
      // markerCaption
      //     .setDy(radius + strokeWidth + markerCaption.getFontSize() / 2);
      markerCaption.setSymbolBoundary(base.calculateBoundary());
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    super.dispose();
  }

  Future<void> initResources(SymbolCache symbolCache) async {
    if (scaled == null) {
      scaled = ShapeSymbol.scale(base, 0);
      _lastZoom = 0;
      shapePaint = ShapePaintSymbol(scaled!);
      await shapePaint.init(symbolCache);
    }

    // bitmap?.dispose();
    // bitmap = null;
    //
    // paint = createPaint(style: Style.FILL);
    // bitmap = await createBitmap(
    //     symbolCache: symbolCache,
    //     bitmapSrc: bitmapSrc!,
    //     bitmapWidth: getBitmapWidth(),
    //     bitmapHeight: getBitmapHeight());
    // if (markerCaption != null) {
    //   markerCaption!.latLong = latLong;
    // }
    // if (bitmap != null) {
    //   double centerX = bitmap!.getWidth() / 2;
    //   double centerY = bitmap!.getHeight() / 2;
    //
    //   _imageOffsetX = -(alignment.x * centerX + centerX);
    //   _imageOffsetY = -(alignment.y * centerY + centerY);
    //
    //   if (markerCaption != null) {
    //     // markerCaption!
    //     //     .setDy(bitmap!.getHeight() / 2 + markerCaption!.getFontSize() / 2);
    //     markerCaption!.setSymbolBoundary(MapRectangle(
    //         -bitmap!.getWidth() / 2,
    //         -bitmap!.getHeight() / 2,
    //         bitmap!.getWidth() / 2,
    //         bitmap!.getHeight() / 2));
    //   }
    // }
  }

  @override
  void setMarkerCaption(MarkerCaption? markerCaption) {
    if (markerCaption != null) {
      // if (bitmap != null) {
      //   // markerCaption
      //   //     .setDy(bitmap!.getHeight() / 2 + markerCaption.getFontSize() / 2);
      //   markerCaption.setSymbolBoundary(MapRectangle(
      //       -bitmap!.getWidth() / 2,
      //       -bitmap!.getHeight() / 2,
      //       bitmap!.getWidth() / 2,
      //       bitmap!.getHeight() / 2));
      // }
    }
    super.setMarkerCaption(markerCaption);
  }

  void set rotation(double rotation) {}

  void setBitmapColorFromNumber(int color) {
    base.setBitmapColorFromNumber(color);
  }

  Future<void> setAndLoadBitmapSrc(
      String bitmapSrc, SymbolCache symbolCache) async {
//    super.setBitmapSrc(bitmapSrc);
    await initResources(symbolCache);
  }

  @override
  void renderBitmap(MarkerCallback markerCallback) {
    if (scaled == null ||
        _lastZoom != markerCallback.mapViewPosition.zoomLevel) {
      scaled =
          ShapeSymbol.scale(base, markerCallback.mapViewPosition.zoomLevel);
      _lastZoom = markerCallback.mapViewPosition.zoomLevel;
      //shapePaint = ShapePaintSymbol(scaled!);
      //shapePaint.init(symbolCache).then((value) {});
    }
    // print(
    //     "renderCaption $caption for $minZoomLevel and $maxZoomLevel at ${markerCallback.mapViewPosition.zoomLevel}");
    shapePaint.renderNode(
      markerCallback.flutterCanvas,
      nodeProperties,
      markerCallback.mapViewPosition.projection,
      markerCallback.mapViewPosition
          .getLeftUpper(markerCallback.viewModel.mapDimension),
      markerCallback.mapViewPosition.rotationRadian,
    );
  }

  @override
  bool isTapped(TapEvent tapEvent) {
    double y = tapEvent.projection.latitudeToPixelY(latLong.latitude);
    double x = tapEvent.projection.longitudeToPixelX(latLong.longitude);
    return false;
    // x = x + _imageOffsetX;
    // y = y + _imageOffsetY;
    // return tapEvent.mapPixelMappoint.x >= x &&
    //     tapEvent.mapPixelMappoint.x <= x + getBitmapWidth() &&
    //     tapEvent.mapPixelMappoint.y >= y &&
    //     tapEvent.mapPixelMappoint.y <= y + getBitmapHeight();
  }

  @override
  void setLatLong(ILatLong latLong) {
    super.setLatLong(latLong);
    nodeProperties = NodeProperties(PointOfInterest(0, [], latLong));
  }

  @override
  void set latLong(ILatLong latLong) {
    super.latLong = latLong;
    nodeProperties = NodeProperties(PointOfInterest(0, [], latLong));
  }
}
