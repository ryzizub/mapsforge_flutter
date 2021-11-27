import 'package:mapsforge_example/mapfileanalyze/blockpage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapsforge_flutter/maps.dart';
import 'package:mapsforge_flutter/src/mapfile/subfileparameter.dart';

class SubfileParamsPage extends StatelessWidget {
  final MapFile mapFile;

  final List<SubFileParameter?> subFileParameters;

  const SubfileParamsPage(
      {Key? key, required this.mapFile, required this.subFileParameters})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    //List<SubFileParameter> newList = List();
    // subFileParameters.forEach((element) {
    //   if (newList.contains(element)) {
    //   } else {
    //     newList.add(element);
    //   }
    // });
    // print("analyzing ${subFileParameters.length} subfileParameter items, ${newList.length} different items");
    return ListView(
      children: subFileParameters
          .map((e) => Card(
                child: e == null
                    ? Text(
                        "SubfileParam for ZoomLevel ${subFileParameters.indexOf(e)} and more",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            "SubfileParam for ZoomLevel ${subFileParameters.indexOf(e)} and more",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Wrap(
                            children: <Widget>[
                              Text("BaseZoomLevel ${e.baseZoomLevel}, "),
                              Text(
                                  "Zoomlevel ${e.zoomLevelMin} - ${e.zoomLevelMax}, "),
                            ],
                          ),
                          Wrap(
                            children: <Widget>[
                              Text(
                                  "boundaryTileVertical ${e.boundaryTileTop} - ${e.boundaryTileBottom}, "),
                              Text(
                                  "boundaryTileHorizontal ${e.boundaryTileLeft} - ${e.boundaryTileRight}, "),
                            ],
                          ),
                          Wrap(
                            children: <Widget>[
                              Text("blocksHeight ${e.blocksHeight}, "),
                              Text("blocksWidth ${e.blocksWidth}, "),
                              Text("numberOfBlocks ${e.numberOfBlocks}, "),
                            ],
                          ),
                          Wrap(
                            children: <Widget>[
                              Text(
                                  "Index Start - End ${e.indexStartAddress} - ${e.indexEndAddress}, "),
                              Text("startAddress ${e.startAddress}, "),
                              Text("subFileSize ${e.subFileSize}, "),
                            ],
                          ),
                          InkWell(
                            child: Row(
                              children: <Widget>[
                                const Text("Blocks"),
                                const Icon(Icons.more_horiz),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (BuildContext context) => BlockPage(
                                    mapFile: mapFile,
                                    subFileParameter: e,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ))
          .toList(),
    );
  }
}
