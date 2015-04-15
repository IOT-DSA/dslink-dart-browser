import "package:polymer/polymer.dart";
import "dart:html";
import "lib/dsa_nodes.dart";

import "package:control_room/control_room.dart";

export "package:polymer/init.dart";

@initMethod
startup() async {
  await initControlRoom();

  var e = querySelector("dsa-nodes") as DSNodesElement;
  e.pathStream.listen((path) {
    querySelector("#path").text = path;
  });

  var csdbtn = querySelector("#close-settings-dialog");
  csdbtn.onClick.listen((e) {
    csdbtn.parent.parent.close();
  });
}
