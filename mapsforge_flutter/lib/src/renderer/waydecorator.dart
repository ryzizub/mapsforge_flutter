import 'dart:math';

import 'package:mapsforge_flutter/src/graphics/maptextpaint.dart';

import '../graphics/bitmap.dart';
import '../graphics/display.dart';
import '../graphics/mappaint.dart';
import '../mapelements/mapelementcontainer.dart';
import '../mapelements/symbolcontainer.dart';
import '../mapelements/waytextcontainer.dart';
import '../model/linesegment.dart';
import '../model/linestring.dart';
import '../model/mappoint.dart';
import '../model/tile.dart';
import '../renderer/rendererutils.dart';

class WayDecorator {
  static final double MAX_LABEL_CORNER_ANGLE = 10;

  static void renderSymbol(
      Bitmap symbolBitmap,
      Display display,
      int priority,
      double dy,
      bool alignCenter,
      bool repeatSymbol,
      int repeatGap,
      int repeatStart,
      bool? rotate,
      List<List<Mappoint>?>? coordinates,
      List<MapElementContainer> currentItems,
      MapPaint? symbolPaint) {
    int skipPixels = repeatStart;

    List<Mappoint?>? c;
    if (dy == 0) {
      c = coordinates![0];
    } else {
      c = RendererUtils.parallelPath(coordinates![0]!, dy);
    }

    // get the first way point coordinates
    double previousX = c![0]!.x;
    double previousY = c[0]!.y;

    // draw the symbolContainer on each way segment
    int segmentLengthRemaining;
    double segmentSkipPercentage;
    double theta = 0;

    for (int i = 1; i < c.length; ++i) {
      // get the current way point coordinates
      double currentX = c[i]!.x;
      double currentY = c[i]!.y;

      // calculate the length of the current segment (Euclidian distance)
      double diffX = currentX - previousX;
      double diffY = currentY - previousY;
      double segmentLengthInPixel = sqrt(diffX * diffX + diffY * diffY);
      segmentLengthRemaining = segmentLengthInPixel.round();

      while (segmentLengthRemaining - skipPixels > repeatStart) {
        // calculate the percentage of the current segment to skip
        segmentSkipPercentage = skipPixels / segmentLengthRemaining;

        // move the previous point forward towards the current point
        previousX += diffX * segmentSkipPercentage;
        previousY += diffY * segmentSkipPercentage;
        if (rotate!) {
          // if we do not rotate theta will be 0, which is correct
          theta = atan2(currentY - previousY, currentX - previousX);
        }

        Mappoint point = new Mappoint(previousX, previousY);

        currentItems.add(new SymbolContainer(
            point, display, priority, symbolBitmap,
            theta: theta, alignCenter: alignCenter, paint: symbolPaint!));

        // check if the symbolContainer should only be rendered once
        if (!repeatSymbol) {
          return;
        }

        // recalculate the distances
        diffX = currentX - previousX;
        diffY = currentY - previousY;

        // recalculate the remaining length of the current segment
        segmentLengthRemaining -= skipPixels;

        // set the amount of pixels to skip before repeating the symbolContainer
        skipPixels = repeatGap;
      }

      skipPixels -= segmentLengthRemaining;
      if (skipPixels < repeatStart) {
        skipPixels = repeatStart;
      }

      // set the previous way point coordinates for the next loop
      previousX = currentX;
      previousY = currentY;
    }
  }

  /**
   * Finds the segments of a line along which a name can be drawn and then adds WayTextContainers
   * to the list of drawable items.
   *
   * @param upperLeft     the tile in the upper left corner of the drawing pane
   * @param lowerRight    the tile in the lower right corner of the drawing pane
   * @param text          the text to draw
   * @param priority      priority of the text
   * @param dy            if 0, then a line  parallel to the coordinates will be calculated first
   * @param fill          fill paint for text
   * @param stroke        stroke paint for text
   * @param coordinates   the list of way coordinates
   * @param currentLabels the list of labels to which a new WayTextContainer will be added
   */
  static void renderText(
      Tile upperLeft,
      String text,
      Display display,
      int priority,
      double dy,
      MapPaint fill,
      MapPaint stroke,
      MapTextPaint textPaint,
      bool? repeat,
      double repeatGap,
      double repeatStart,
      bool? rotate,
      List<List<Mappoint>> coordinates,
      List<MapElementContainer> currentLabels) {
    if (coordinates.length == 0) {
      return;
    }

    List<Mappoint>? c;
    if (dy == 0) {
      c = coordinates[0];
    } else {
      c = RendererUtils.parallelPath(coordinates[0], dy);
    }

    if (c.length < 2) {
      return;
    }

    LineString fullPath = new LineString();
    for (int i = 1; i < c.length; i++) {
      LineSegment segment = new LineSegment(c[i - 1], c[i]);
      fullPath.segments.add(segment);
    }

    double textWidth = textPaint.getTextWidth(text);
    double textHeight = textPaint.getTextHeight(text);

    fullPath = reducePathForText(fullPath, textWidth);
    if (fullPath.segments.isNotEmpty)
      currentLabels.add(new WayTextContainer(fullPath, display, priority, text,
          fill, stroke, textHeight, textPaint));
  }

  static LineString reducePathForText(LineString fullPath, double textWidth) {
    LineString result = LineString();
    LineString path = LineString();
    for (LineSegment segment in fullPath.segments) {
      if (segment.length() > textWidth) {
        // we found a segment which is long enough so use this instead of all the small segments before
        result.segments.add(segment);
        path = LineString();
        // todo split very long segments to several small segments and draw the text in each
        continue;
      }
      if (path.segments.isNotEmpty) {
        double cornerAngle = path.segments.last.angleTo(segment);
        if ((cornerAngle).abs() > MAX_LABEL_CORNER_ANGLE) {
          path = LineString();
          continue;
        }
      }
      path.segments.add(segment);
      if (path.length() > textWidth) {
        result.segments.add(
            LineSegment(path.segments.first.start, path.segments.last.end));
        path = LineString();
      }
    }
    return result;
  }
}
