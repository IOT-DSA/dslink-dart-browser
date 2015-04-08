import "dart:async";
import "dart:html";


import "package:dslink/browser_client.dart";
import "package:dslink/requester.dart";
import "package:dslink/src/crypto/pk.dart";

import "package:paper_elements/paper_tabs.dart";
import "package:core_elements/core_pages.dart";

export "package:polymer/polymer.dart";
export "package:dslink/requester.dart";
export "package:dslink/common.dart";

BrowserECDHLink link;
Requester requester;

initControlRoom() async {
  PrivateKey key;

  if (window.localStorage.containsKey("dsa_key")) {
    key = new PrivateKey.loadFromString(window.localStorage["dsa_key"]);
  } else {
    key = new PrivateKey.generate();
    window.localStorage["dsa_key"] = key.saveToString();
  }

  link = new BrowserECDHLink("http://127.0.0.1:8080/conn", "Control-Room-", key, isResponder: false);
  link.connect();
  await link.onRequesterReady;
  requester = link.requester;

  var tabs = querySelector("#tabs");
  var pages = querySelector("#pages");
  tabs.on["core-select"].listen((e) {
    pages.attributes["selected"] = tabs.attributes["selected"];
  });

  for (var h in onReadyHandlers) {
    h();
  }

  onReadyHandlers.clear();
}

List<Function> onReadyHandlers = [];
