import 'package:mapsforge_flutter/core.dart';
import 'package:mapsforge_flutter/marker.dart';
import 'package:mapsforge_flutter/src/graphics/display.dart';
import 'package:mapsforge_flutter/src/graphics/mappaint.dart';
import 'package:mapsforge_flutter/src/graphics/mappath.dart';
import 'package:mapsforge_flutter/src/graphics/style.dart';
import 'package:mapsforge_flutter/src/model/mappoint.dart';

/// Draws an normally open path as marker. Note that isTapped() returns
/// always false.
class PathMarker<T> extends Marker<T> {
  List<ILatLong> path = [];

  MapPaint? stroke;

  final double strokeWidth;

  final int strokeColor;

  MapPath? mapPath;

  List<Mappoint> _points = [];

  int _zoom = -1;

  double _leftUpperX = -1;

  double _leftUpperY = -1;

  PathMarker({
    display = Display.ALWAYS,
    minZoomLevel = 0,
    maxZoomLevel = 65535,
    item,
    this.strokeWidth = 1.0,
    this.strokeColor = 0xff000000,
  })  : assert(display != null),
        assert(minZoomLevel >= 0),
        assert(maxZoomLevel <= 65535),
        assert(strokeWidth >= 0),
        super(
          display: display,
          minZoomLevel: minZoomLevel,
          maxZoomLevel: maxZoomLevel,
          item: item,
        );

  Future<void> initResources() async {
    if (stroke == null && strokeWidth > 0) {
      this.stroke = GraphicFactory().createPaint();
      this.stroke!.setColorFromNumber(strokeColor);
      this.stroke!.setStyle(Style.STROKE);
      this.stroke!.setStrokeWidth(strokeWidth);
      //this.stroke.setTextSize(fontSize);
      mapPath = GraphicFactory().createPath();
    }
  }

  void addLatLong(ILatLong latLong) {
    path.add(latLong);
    mapPath?.clear();
    _zoom = -1;
  }

  @override
  bool shouldPaint(BoundingBox boundary, int zoomLevel) {
    return minZoomLevel <= zoomLevel && maxZoomLevel >= zoomLevel;
  }

  @override
  void render(MarkerCallback markerCallback) {
    if (stroke == null) return;

    if (_zoom == markerCallback.mapViewPosition.zoomLevel) {
      markerCallback.flutterCanvas.uiCanvas.save();
      markerCallback.flutterCanvas.uiCanvas.translate(
          _leftUpperX - markerCallback.mapViewPosition.leftUpper!.x,
          _leftUpperY - markerCallback.mapViewPosition.leftUpper!.y);
      //if (fill != null) markerCallback.renderPath(mapPath!, fill!);
      if (stroke != null) markerCallback.renderPath(mapPath!, stroke!);
      markerCallback.flutterCanvas.uiCanvas.restore();
      // _points.forEach((mappoint) {
      //   double y = mappoint.y - markerCallback.mapViewPosition.leftUpper!.y;
      //   double x = mappoint.x - markerCallback.mapViewPosition.leftUpper!.x;
      //   if (mapPath!.isEmpty())
      //     mapPath!.moveTo(x, y);
      //   else
      //     mapPath!.lineTo(x, y);
      // });
    } else {
      mapPath?.clear();
      _points.clear();
      _zoom = markerCallback.mapViewPosition.zoomLevel;
      path.forEach((latLong) {
        Mappoint mappoint = Mappoint(
            markerCallback.mapViewPosition.projection!
                .longitudeToPixelX(latLong.longitude),
            markerCallback.mapViewPosition.projection!
                .latitudeToPixelY(latLong.latitude));
        double y = mappoint.y - markerCallback.mapViewPosition.leftUpper!.y;
        double x = mappoint.x - markerCallback.mapViewPosition.leftUpper!.x;

        _points.add(mappoint);

        if (mapPath!.isEmpty())
          mapPath!.moveTo(x, y);
        else
          mapPath!.lineTo(x, y);
      });
      _leftUpperX = markerCallback.mapViewPosition.leftUpper!.x;
      _leftUpperY = markerCallback.mapViewPosition.leftUpper!.y;
      markerCallback.renderPath(mapPath!, stroke!);
    }
  }
}
