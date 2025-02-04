import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart';
import 'package:mapsforge_flutter/src/graphics/implementation/fluttertilepicture.dart';
import 'package:mapsforge_flutter/src/layer/job/job.dart';
import 'package:mapsforge_flutter/src/layer/job/jobresult.dart';
import 'package:mapsforge_flutter/src/renderer/jobrenderer.dart';

import '../graphics/tilepicture.dart';

///
/// This renderer fetches the desired bitmap from openstreetmap website. Since the bitmaps are 256 pixels in size the same size must be
/// configured in the displayModel.
///
class MapOnlineRendererWeb extends JobRenderer {
  static final String uriPrefix = "https://a.tile.openstreetmap.org";

  MapOnlineRendererWeb();

  @override
  Future<JobResult> executeJob(Job job) async {
    Uri uri = Uri.parse(
        "$uriPrefix/${job.tile.zoomLevel}/${job.tile.tileX}/${job.tile.tileY}.png");

    Request req = Request('GET', uri);
    StreamedResponse response = await req.send();

    final _Uint8ListBuilder builder = await response.stream.fold(
      new _Uint8ListBuilder(),
      (_Uint8ListBuilder buffer, List<int> bytes) => buffer..add(bytes),
    );
    final Uint8List content = builder.data;

    var codec = await ui.instantiateImageCodec(content.buffer.asUint8List());
    // add additional checking for number of frames etc here
    var frame = await codec.getNextFrame();
    ui.Image img = frame.image;

    TilePicture result = FlutterTilePicture.fromBitmap(img);
    return JobResult(result, JOBRESULT.NORMAL);
  }

  @override
  Future<JobResult> retrieveLabels(Job job) {
    return Future.value(JobResult(null, JOBRESULT.NORMAL));
  }

  @override
  String getRenderKey() {
    return "osmweb";
  }
}

/////////////////////////////////////////////////////////////////////////////

/// An indefinitely growing builder of a [Uint8List].
class _Uint8ListBuilder {
  static const int _kInitialSize = 100000; // 100KB-ish

  int _usedLength = 0;
  Uint8List _buffer = new Uint8List(_kInitialSize);

  Uint8List get data => new Uint8List.view(_buffer.buffer, 0, _usedLength);

  void add(List<int> bytes) {
    _ensureCanAdd(bytes.length);
    _buffer.setAll(_usedLength, bytes);
    _usedLength += bytes.length;
  }

  void _ensureCanAdd(int byteCount) {
    final int totalSpaceNeeded = _usedLength + byteCount;

    int newLength = _buffer.length;
    while (totalSpaceNeeded > newLength) {
      newLength *= 2;
    }

    if (newLength != _buffer.length) {
      final Uint8List newBuffer = new Uint8List(newLength);
      newBuffer.setAll(0, _buffer);
      newBuffer.setRange(0, _usedLength, _buffer);
      _buffer = newBuffer;
    }
  }
}
