import "package:polymer/polymer.dart";
import "dart:html";
import "lib/dsa_nodes.dart";

import "package:dsa_browser/dsa_browser.dart";

export "package:polymer/init.dart";

@initMethod
startup() async {
  await initBrowser();

  var e = querySelector("dsa-nodes") as DSNodesElement;
  e.pathStream.listen((path) {
    querySelector("#path").text = path;
  });

  var csdbtn = querySelector("#close-settings-dialog");
  csdbtn.onClick.listen((e) {
    csdbtn.parent.parent.close();
  });
}
