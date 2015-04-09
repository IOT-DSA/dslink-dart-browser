import "dart:async";
import "dart:html";


import "package:dslink/browser_client.dart";
import "package:dslink/requester.dart";
import "package:dslink/src/crypto/pk.dart";

import "package:paper_elements/paper_icon_button.dart";

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

  var arrow = querySelector("#arrow") as PaperIconButton;

  arrow.onClick.listen((_) {
    if (goBack != null) {
      goBack();
    }
  });

  for (var h in onReadyHandlers) {
    h();
  }

  onReadyHandlers.clear();
}

Function goBack;

List<Function> onReadyHandlers = [];
