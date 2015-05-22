library dsa_browser;

import "dart:html";

import "package:dslink/browser.dart";

import "package:paper_elements/paper_icon_button.dart";
import "package:paper_elements/paper_dialog.dart";
import "package:paper_elements/paper_spinner.dart";

export "package:polymer/polymer.dart";
export "package:dslink/requester.dart";
export "package:dslink/common.dart";

String DEFAULT_BROKER;

BrowserECDHLink link;
Requester requester;

bool truncateValues = true;

initBrowser() async {
  DEFAULT_BROKER = await BrowserUtils.fetchBrokerUrlFromPath("broker_url", "http://127.0.0.1:8080/conn");

  PrivateKey key;

  if (window.localStorage.containsKey("dsa_key")) {
    key = new PrivateKey.loadFromString(window.localStorage["dsa_key"]);
  } else {
    key = new PrivateKey.generate();
    window.localStorage["dsa_key"] = key.saveToString();
  }

  if (window.localStorage.containsKey("setting.truncate-values")) {
    truncateValues = window.localStorage["setting.truncate-values"] == "1";
  }

  link = new BrowserECDHLink(DEFAULT_BROKER, "Node-Browser-", key, isResponder: false);
  link.connect();
  await link.onRequesterReady;
  requester = link.requester;

  var arrow = querySelector("#arrow") as PaperIconButton;
  var refresh = querySelector("#refresh-btn") as PaperIconButton;
  var view = querySelector("#view-top-node-btn") as PaperIconButton;
  var settings = querySelector("#settings-btn") as PaperIconButton;
  var settingTruncateValues = querySelector("#setting-truncate-values");

  if (truncateValues) {
    settingTruncateValues.checked = true;
  }

  arrow.onClick.listen((_) {
    if (goBack != null) {
      goBack();
    }
  });

  settingTruncateValues.on["core-change"].listen((e) {
    var checked = settingTruncateValues.checked;
    window.localStorage["setting.truncate-values"] = checked ? "1" : "0";
    truncateValues = checked;
  });

  refresh.onClick.listen((_) {
    if (refreshAction != null) {
      refreshAction();
    }
  });

  view.onClick.listen((_) {
    if (viewAction != null) {
      viewAction();
    }
  });

  settings.onClick.listen((_) {
    if (settingsAction != null) {
      settingsAction();
    } else {
      openDefaultSettings();
    }
  });

  var hash = window.location.hash;
  if (hash != null && hash.length > 1) {
    var path = hash.substring(1);
    var p = querySelector("dsa-nodes");
    p.attributes["path"] = path;
  }

  for (var h in onReadyHandlers) {
    h();
  }

  onReadyHandlers.clear();
}

void toggleSpinner([bool on]) {
  PaperSpinner spinner = querySelector("#spinner");
  if (on != null) {
    spinner.active = on;
  } else {
    spinner.active = !spinner.active;
  }
}

void openDefaultSettings() {
  PaperDialog dialog = querySelector("#settings-dialog");
  dialog.open();
}

Function goBack;
Function viewAction;
Function refreshAction;
Function settingsAction;

List<Function> onReadyHandlers = [];
bool ignoreHashChange = false;
