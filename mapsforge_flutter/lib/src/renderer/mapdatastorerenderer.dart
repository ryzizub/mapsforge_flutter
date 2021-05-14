import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:mapsforge_flutter/maps.dart';
import 'package:mapsforge_flutter/src/datastore/datastore.dart';
import 'package:mapsforge_flutter/src/datastore/datastorereadresult.dart';
import 'package:mapsforge_flutter/src/datastore/pointofinterest.dart';
import 'package:mapsforge_flutter/src/datastore/way.dart';
import 'package:mapsforge_flutter/src/graphics/bitmap.dart';
import 'package:mapsforge_flutter/src/graphics/display.dart';
import 'package:mapsforge_flutter/src/graphics/graphicfactory.dart';
import 'package:mapsforge_flutter/src/graphics/mappaint.dart';
import 'package:mapsforge_flutter/src/graphics/position.dart';
import 'package:mapsforge_flutter/src/graphics/tilebitmap.dart';
import 'package:mapsforge_flutter/src/labels/tilebasedlabelstore.dart';
import 'package:mapsforge_flutter/src/layer/job/job.dart';
import 'package:mapsforge_flutter/src/layer/job/jobrenderer.dart';
import 'package:mapsforge_flutter/src/mapelements/mapelementcontainer.dart';
import 'package:mapsforge_flutter/src/mapelements/pointtextcontainer.dart';
import 'package:mapsforge_flutter/src/mapelements/symbolcontainer.dart';
import 'package:mapsforge_flutter/src/model/mappoint.dart';
import 'package:mapsforge_flutter/src/model/tag.dart';
import 'package:mapsforge_flutter/src/model/tile.dart';
import 'package:mapsforge_flutter/src/renderer/polylinecontainer.dart';
import 'package:mapsforge_flutter/src/renderer/shapepaintcontainer.dart';
import 'package:mapsforge_flutter/src/renderer/tiledependencies.dart';
import 'package:mapsforge_flutter/src/renderer/waydecorator.dart';
import 'package:mapsforge_flutter/src/rendertheme/rendercallback.dart';
import 'package:mapsforge_flutter/src/rendertheme/rendercontext.dart';
import 'package:mapsforge_flutter/src/rendertheme/rule/rendertheme.dart';
import 'package:mapsforge_flutter/src/utils/layerutil.dart';
import 'package:rxdart/rxdart.dart';

import 'canvasrasterer.dart';
import 'circlecontainer.dart';

///
/// This renderer renders the bitmap for the tiles by using the given [MapDataStore].
///
class MapDataStoreRenderer extends JobRenderer implements RenderCallback {
  static final _log = new Logger('MapDataStoreRenderer');
  static final Tag TAG_NATURAL_WATER = new Tag("natural", "water");

  final Datastore datastore;

  final RenderTheme renderTheme;

  final GraphicFactory graphicFactory;

  final bool renderLabels;

  TileDependencies? tileDependencies;

  final TileBasedLabelStore labelStore;

  SendPort? _sendPort;

  Isolate? _isolate;

  PublishSubject<DatastoreReadResult> _subject = PublishSubject<DatastoreReadResult>();

  MapDataStoreRenderer(
    this.datastore,
    this.renderTheme,
    this.graphicFactory,
    this.renderLabels,
  )   : assert(renderLabels != null),
        labelStore = TileBasedLabelStore(100) {
    if (!renderLabels) {
      this.tileDependencies = null;
    } else {
      this.tileDependencies = new TileDependencies();
    }
  }

  void dispose() {
    if (_isolate != null) {
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }
  }

  ///
  /// Executes a given job and returns a future with the bitmap of this job.
  /// @returns null if the datastore does not support the requested tile
  /// @returns the Bitmap for the requested tile
  @override
  Future<TileBitmap?> executeJob(Job job) async {
    bool showTiming = false;
    bool useIsolate = true;
    //_log.info("Executing ${job.toString()}");
    int time = DateTime.now().millisecondsSinceEpoch;
    if (!this.datastore.supportsTile(job.tile)) {
      // return if we do not have data for the requested tile in the datastore
      return null;
    }
    CanvasRasterer canvasRasterer =
        CanvasRasterer(graphicFactory, job.tileSize, job.tileSize, job.tileSize, "MapDatastoreRenderer ${job.tile.toString()}");
    RenderContext renderContext = RenderContext(job, renderTheme, graphicFactory);
    DatastoreReadResult? mapReadResult;
    if (useIsolate) {
      if (showTiming) _log.info("Before starting the isolate to read map data from file");
      // read the mapdata in an isolate which is flutter's way to create multithreaded processes
      await _startIsolateJob();
      _sendPort!.send(IsolateParam(datastore, job.tile));
      mapReadResult = await _subject.stream.first;
    } else {
      if (showTiming) _log.info("Before reading map data from file");
      // read the mapdata directly in this thread
      mapReadResult = await readMapDataInIsolate(IsolateParam(datastore, job.tile));
    }
    int diff = DateTime.now().millisecondsSinceEpoch - time;
    if (mapReadResult == null) {
      _log.info("Executing ${job.toString()} has no mapReadResult for tile ${job.tile.toString()}");
      return null;
    }
    if (diff > 100 && showTiming)
      _log.info("mapReadResult took $diff ms for ${mapReadResult.pointOfInterests!.length} pois and ${mapReadResult.ways!.length} ways");
    if ((mapReadResult.ways?.length ?? 0) > 100000) {
      _log.warning("Many ways (${mapReadResult.ways!.length}) in this readResult, consider shrinking your mapfile.");
    }
    await _processReadMapData(renderContext, mapReadResult);
    diff = DateTime.now().millisecondsSinceEpoch - time;
    if (diff > 100 && showTiming) _log.info("_processReadMapData took $diff ms");
    canvasRasterer.startCanvasBitmap();
    canvasRasterer.drawWays(renderContext);
    diff = DateTime.now().millisecondsSinceEpoch - time;
    if (diff > 100 && showTiming) _log.info("drawWays took $diff ms");

    if (this.renderLabels) {
      Set<MapElementContainer> labelsToDraw = await _processLabels(renderContext);
      //_log.info("Labels to draw: $labelsToDraw");
      // now draw the ways and the labels
      canvasRasterer.drawMapElements(labelsToDraw, job.tile, job.tileSize);
      diff = DateTime.now().millisecondsSinceEpoch - time;
      if (diff > 100 && showTiming) _log.info("drawMapElements took $diff ms");
    }
    if (this.labelStore != null) {
      // store elements for this tile in the label cache
      this.labelStore.storeMapItems(job.tile, renderContext.labels);
      diff = DateTime.now().millisecondsSinceEpoch - time;
      if (diff > 100 && showTiming) _log.info("storeMapItems took $diff ms");
    }

//    if (!job.labelsOnly && renderContext.renderTheme.hasMapBackgroundOutside()) {
//      // blank out all areas outside of map
//      Rectangle insideArea = this.mapDataStore.boundingBox().getPositionRelativeToTile(job.tile);
//      if (!job.hasAlpha) {
//        renderContext.canvasRasterer.fillOutsideAreas(renderContext.renderTheme.getMapBackgroundOutside(), insideArea);
//      } else {
//        renderContext.canvasRasterer.fillOutsideAreas(Color.TRANSPARENT, insideArea);
//      }
//    }

    TileBitmap? bitmap = (await canvasRasterer.finalizeCanvasBitmap() as TileBitmap?);
    canvasRasterer.destroy();
    diff = DateTime.now().millisecondsSinceEpoch - time;
    if (diff > 100 && showTiming) _log.info("finalizeCanvasBitmap took $diff ms");
    //_log.info("Executing ${job.toString()} returns ${bitmap.toString()}");
    return bitmap;
  }

  Future<void> _processReadMapData(final RenderContext renderContext, DatastoreReadResult mapReadResult) async {
    for (PointOfInterest pointOfInterest in mapReadResult.pointOfInterests!) {
      await _renderPointOfInterest(renderContext, pointOfInterest);
    }

    for (Way way in mapReadResult.ways!) {
      await _renderWay(renderContext, new PolylineContainer(way, renderContext.job.tile, renderContext.job.tile));
    }

    if (mapReadResult.isWater) {
      _renderWaterBackground(renderContext);
    }
  }

  Future<void> _renderPointOfInterest(final RenderContext renderContext, PointOfInterest pointOfInterest) async {
    renderContext.setDrawingLayers(pointOfInterest.layer);
    await renderContext.renderTheme.matchNode(this, renderContext, pointOfInterest);
  }

  Future<void> _renderWay(final RenderContext renderContext, PolylineContainer way) async {
    renderContext.setDrawingLayers(way.getLayer());
    //_log.info("drawing way " + way.toString());
    if (way.isClosedWay) {
      await renderContext.renderTheme.matchClosedWay(this, renderContext, way);
    } else {
      await renderContext.renderTheme.matchLinearWay(this, renderContext, way);
    }
  }

  void _renderWaterBackground(final RenderContext renderContext) {
    renderContext.setDrawingLayers(0);
    List<Mappoint> coordinates = getTilePixelCoordinates(renderContext.job.tileSize);
    Mappoint? tileOrigin = renderContext.job.tile.getLeftUpper(renderContext.job.tileSize);
    for (int i = 0; i < coordinates.length; i++) {
      coordinates[i] = coordinates[i].offset(tileOrigin!.x, tileOrigin.y);
    }
    PolylineContainer way =
        new PolylineContainer.fromList(coordinates, renderContext.job.tile, renderContext.job.tile, [TAG_NATURAL_WATER]);
    //renderContext.renderTheme.matchClosedWay(databaseRenderer, renderContext, way);
  }

  static List<Mappoint> getTilePixelCoordinates(double tileSize) {
    List<Mappoint> result = [];
    result.add(Mappoint(0, 0));
    result.add(Mappoint(tileSize.toDouble(), 0));
    result.add(Mappoint(tileSize.toDouble(), tileSize.toDouble()));
    result.add(Mappoint(0, tileSize.toDouble()));
    result.add(result[0]);
    return result;
  }

  @override
  void renderArea(RenderContext renderContext, MapPaint? fill, MapPaint stroke, int level, PolylineContainer way) {
    if (!stroke.isTransparent()) renderContext.addToCurrentDrawingLayer(level, new ShapePaintContainer(way, stroke, 0));
    if (!fill!.isTransparent()) renderContext.addToCurrentDrawingLayer(level, new ShapePaintContainer(way, fill, 0));
  }

  @override
  void renderAreaCaption(RenderContext renderContext, Display? display, int priority, String caption, double horizontalOffset,
      double verticalOffset, MapPaint fill, MapPaint stroke, Position? position, int maxTextWidth, PolylineContainer way) {
    if (renderLabels) {
      Mappoint centerPoint = way.getCenterAbsolute()!.offset(horizontalOffset, verticalOffset);
      //_log.info("centerPoint is ${centerPoint.toString()}, position is ${position.toString()} for $caption");
      PointTextContainer label =
          this.graphicFactory.createPointTextContainer(centerPoint, display, priority, caption, fill, stroke, null, position, maxTextWidth);
      assert(label != null);
      renderContext.labels.add(label);
    }
  }

  @override
  void renderAreaSymbol(
      RenderContext renderContext, Display? display, int priority, Bitmap? symbol, PolylineContainer way, MapPaint? symbolPaint) {
    if (renderLabels && !symbolPaint!.isTransparent()) {
      Mappoint? centerPosition = way.getCenterAbsolute();
      renderContext.labels.add(new SymbolContainer(centerPosition, display, priority, symbol, paint: symbolPaint));
    }
  }

  @override
  void renderPointOfInterestCaption(RenderContext renderContext, Display? display, int priority, String caption, double horizontalOffset,
      double verticalOffset, MapPaint fill, MapPaint stroke, Position? position, int maxTextWidth, PointOfInterest poi) {
    if (renderLabels) {
      //Mappoint poiPosition = renderContext.job.tile.mercatorProjection.getPixelRelativeToTile(poi.position, renderContext.job.tile);
      //MercatorProjectionImpl mercatorProjection = MercatorProjectionImpl(renderContext.job.tileSize, renderContext.job.tile.zoomLevel);
      Mappoint poiPosition = renderContext.mercatorProjection!.getPixel(poi.position);

      renderContext.labels.add(this.graphicFactory.createPointTextContainer(
          poiPosition.offset(horizontalOffset, verticalOffset), display, priority, caption, fill, stroke, null, position, maxTextWidth));
    }
  }

  @override
  void renderPointOfInterestCircle(
      RenderContext renderContext, double radius, MapPaint? fill, MapPaint stroke, int level, PointOfInterest poi) {
    // ShapePaintContainers does not shift the position relative to the tile by themself. In case of ways this is done in the [PolylineContainer], but
    // in case of cirles this is not done at all so do it here for now
    Mappoint poiPosition = renderContext.mercatorProjection!.getPixelRelativeToTile(poi.position, renderContext.job.tile);
    //_log.info("Adding circle $poiPosition with $radius");
    if (stroke != null && !stroke.isTransparent())
      renderContext.addToCurrentDrawingLayer(level, new ShapePaintContainer(new CircleContainer(poiPosition, radius), stroke, 0));
    if (fill != null && !fill.isTransparent())
      renderContext.addToCurrentDrawingLayer(level, new ShapePaintContainer(new CircleContainer(poiPosition, radius), fill, 0));
  }

  @override
  void renderPointOfInterestSymbol(
      RenderContext renderContext, Display? display, int priority, Bitmap? symbol, PointOfInterest poi, MapPaint? symbolPaint) {
    if (renderLabels && !symbolPaint!.isTransparent()) {
      Mappoint poiPosition = renderContext.mercatorProjection!.getPixel(poi.position);
      renderContext.labels.add(new SymbolContainer(poiPosition, display, priority, symbol, paint: symbolPaint, alignCenter: true));
    }
  }

  @override
  void renderWay(RenderContext renderContext, MapPaint stroke, double dy, int level, PolylineContainer way) {
    if (!stroke.isTransparent()) renderContext.addToCurrentDrawingLayer(level, new ShapePaintContainer(way, stroke, dy));
  }

  @override
  void renderWaySymbol(RenderContext renderContext, Display? display, int priority, Bitmap? symbol, double dy, bool alignCenter,
      bool repeat, double? repeatGap, double? repeatStart, bool? rotate, PolylineContainer way, MapPaint? symbolPaint) {
    if (renderLabels && !symbolPaint!.isTransparent()) {
      WayDecorator.renderSymbol(symbol, display, priority, dy, alignCenter, repeat, repeatGap!.toInt(), repeatStart!.toInt(), rotate,
          way.getCoordinatesAbsolute(), renderContext.labels, symbolPaint);
    }
  }

  @override
  void renderWayText(RenderContext renderContext, Display? display, int priority, String text, double dy, MapPaint fill, MapPaint stroke,
      bool? repeat, double? repeatGap, double? repeatStart, bool? rotate, PolylineContainer way) {
    if (renderLabels) {
      WayDecorator.renderText(graphicFactory, way.getUpperLeft(), way.getLowerRight(), text, display, priority, dy, fill, stroke, repeat,
          repeatGap!, repeatStart!, rotate, way.getCoordinatesAbsolute(), renderContext.labels);
    }
  }

  Future<Set<MapElementContainer>> _processLabels(RenderContext renderContext) async {
    //return renderContext.labels.toSet();
    // if we are drawing the labels per tile, we need to establish which tile-overlapping
    // elements need to be drawn.
    Set<MapElementContainer> labelsToDraw = new Set();

    // first we need to get the labels from the adjacent tiles if they have already been drawn
    // as those overlapping items must also be drawn on the current tile. They must be drawn regardless
    // of priority clashes as a part of them has alread been drawn.
    Set<Tile> neighbours = renderContext.job.tile.getNeighbours();
    Set<MapElementContainer> undrawableElements = new Set();

    tileDependencies!.addTileInProgress(renderContext.job.tile);
    List toRemove = [];
    neighbours.forEach((Tile neighbour) {
      if (tileDependencies!.isTileInProgress(neighbour) //||
//            tileCache
//                .containsKey(renderContext.rendererJob.otherTile(neighbour))
          ) {
        // if a tile has already been drawn, the elements drawn that overlap onto the
        // current tile should be in the tile dependencies, we add them to the labels that
        // need to be drawn onto this tile. For the multi-threaded renderer we also need to take
        // those tiles into account that are not yet in the TileCache: this is taken care of by the
        // set of tilesInProgress inside the TileDependencies.
        labelsToDraw.addAll(tileDependencies!.getOverlappingElements(neighbour, renderContext.job.tile)!);

        // but we need to remove the labels for this tile that overlap onto a tile that has been drawn
        for (MapElementContainer current in renderContext.labels) {
          if (current.intersects(neighbour.getBoundaryAbsolute(renderContext.job.tileSize))) {
            undrawableElements.add(current);
          }
        }
        // since we already have the data from that tile, we do not need to get the data for
        // it, so remove it from the neighbours list.
        //neighbours.remove(neighbour);
        toRemove.add(neighbour);
      } else {
        tileDependencies!.removeTileData(neighbour);
      }
    });
    //_log.info("undrawable: $undrawableElements");
    //_log.info("toRemove: $toRemove");
    neighbours.removeWhere((tile) => toRemove.contains(tile));
    // now we remove the elements that overlap onto a drawn tile from the list of labels
    // for this tile
    renderContext.labels.removeWhere((toTest) => undrawableElements.contains(toTest));

    // at this point we have two lists: one is the list of labels that must be drawn because
    // they already overlap from other tiles. The second one is currentLabels that contains
    // the elements on this tile that do not overlap onto a drawn tile. Now we sort this list and
    // remove those elements that clash in this list already.
    List<MapElementContainer> currentElementsOrdered = LayerUtil.collisionFreeOrdered(renderContext.labels);
    // now we go through this list, ordered by priority, to see which can be drawn without clashing.
    List<MapElementContainer> toRemove2 = [];
    currentElementsOrdered.forEach((MapElementContainer current) {
      for (MapElementContainer label in labelsToDraw) {
        if (label.clashesWith(current)) {
          toRemove2.add(current);
          //currentElementsOrdered.remove(current);
          break;
        }
      }
    });
    currentElementsOrdered.removeWhere((item) => toRemove2.contains(item));

    labelsToDraw.addAll(currentElementsOrdered);

    // update dependencies, add to the dependencies list all the elements that overlap to the
    // neighbouring tiles, first clearing out the cache for this relation.
    for (Tile tile in neighbours) {
      tileDependencies!.removeTileData(renderContext.job.tile, to: tile);
      for (MapElementContainer element in labelsToDraw) {
        if (element.intersects(tile.getBoundaryAbsolute(renderContext.job.tileSize))) {
          tileDependencies!.addOverlappingElement(renderContext.job.tile, tile, element);
        }
      }
    }
    return labelsToDraw;
  }

  @override
  String getRenderKey() {
    return "${renderTheme.hashCode}";
  }

  ///
  /// Isolates currently not suitable for our purpose. Most UI canvas calls are not accessible from isolates
  /// so we cannot produce the bitmap.
  Future<void> _startIsolateJob() async {
    if (_sendPort != null) return;
    ReceivePort receivePort = new ReceivePort();
    _isolate = await Isolate.spawn(entryPoint, receivePort.sendPort);
    PublishSubject<SendPort?> subject = PublishSubject<SendPort?>();
    // let the listener run in background
    _listenToIsolate(receivePort, subject);
    // wait for the _sendPort
    await subject.stream.first;
    subject.close();
  }

  void _listenToIsolate(ReceivePort receivePort, PublishSubject<SendPort?> subject) async {
    await for (var data in receivePort) {
      //tileCache.addTileBitmap(job.tile, tileBitmap);
      //print("received from isolate: ${data.toString()}");
      if (data is SendPort) {
        // Receive the SendPort from the Isolate
        _sendPort = data;
        // inform waiting method that we have a stable connection now
        subject.add(_sendPort);
      } else if (data is DatastoreReadResult) {
        DatastoreReadResult result = data;
        _subject.add(result);
      }
    }
  }
}

/////////////////////////////////////////////////////////////////////////////

/// see https://github.com/flutter/flutter/issues/13937
// Entry point for your Isolate
entryPoint(SendPort sendPort) async {
  // Open the ReceivePort to listen for incoming messages
  var receivePort = new ReceivePort();

  // Send messages to other Isolates
  sendPort.send(receivePort.sendPort);

  // Listen for messages
  await for (IsolateParam isolateParam in receivePort) {
    //print("hello, we received $isolateParam in the isolate");
    DatastoreReadResult? result = await readMapDataInIsolate(isolateParam);
    sendPort.send(result);
  }
}

/////////////////////////////////////////////////////////////////////////////

///
/// The parameters needed to execute the reading of the mapdata.
///
class IsolateParam {
  final Datastore mapDataStore;

  final Tile tile;

  const IsolateParam(this.mapDataStore, this.tile);
}

/////////////////////////////////////////////////////////////////////////////

///
/// This is the execution of reading the mapdata. If called directly the execution is done in the main thread. If called
/// via [entryPoint] the execution is done in an isolate.
///
Future<DatastoreReadResult?> readMapDataInIsolate(IsolateParam isolateParam) async {
  DatastoreReadResult? mapReadResult = await isolateParam.mapDataStore.readMapDataSingle(isolateParam.tile);
  return mapReadResult;
}
