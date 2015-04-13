@HtmlImport("package:core_elements/core_list_dart.html")
@HtmlImport("material_card.html")
@HtmlImport("package:paper_elements/paper_button.html")
@HtmlImport("package:paper_elements/paper_dialog.html")
@HtmlImport("package:paper_elements/paper_input.html")
library control_room.dsa_nodes;

import "dart:async";
import "dart:convert";

import "package:control_room/control_room.dart";
import "package:dslink/requester.dart";
import "package:paper_elements/paper_dialog.dart";
import "package:paper_elements/paper_input.dart";
import "package:core_elements/core_menu.dart";
import "package:paper_elements/paper_item.dart";
import "dart:html";

@CustomTag("dsa-nodes")
class DSNodesElement extends PolymerElement with Observable {
  @observable List<NodeModel> nodez = toObservable([]);
  @published @observable String path = "/";

  Map<String, NodeModel> nmap = {};
  Map<String, ReqSubscribeListener> listeners = {};

  DSNodesElement.created() : super.created();

  bool loaded = false;

  @override
  void attached() {
    super.attached();
    print("DSA Nodes Element Attached");

    onReadyHandlers.add(() {
      loaded = true;
      loadNodes();
    });

    onPropertyChange(this, #path, () {
      _pathController.add(path);
      if (loaded) {
        loadNodes();
      }
    });
  }

  Stream<RequesterListUpdate> _listUpdate;
  Stream<ValueUpdate> _valueUpdates;
  StreamSubscription<RequesterListUpdate> _listSub;

  loadNodes() async {
    nodez.clear();
    if (_listSub != null) {
      await _listSub.cancel();
    }

    goBack = () {
      print("Go Back");
      if (path == "/") {
        return;
      }

      var s = path.split("/");
      var p =  s.take(s.length - 1).join("/");
      if (!p.startsWith("/")) {
        p = "/${p}";
      }
      path = p;
    };

    _listUpdate = requester.list(path);
    _listSub = _listUpdate.listen((e) async {
      if (e.streamStatus == StreamStatus.initialize) {
        return null;
      }

      var node = e.node;

      for (RemoteNode child in node.children.values) {
        var existing = nodez.where((it) => it.node.remotePath == child.remotePath);

        if (existing.isNotEmpty) {
          for (var x in existing.toList()) {
            if (listeners.containsKey(x.path)) {
              var listener = listeners.remove(x.path);
              listener.cancel();
            }
            nodez.remove(x);
            nmap.remove(x.path);
          }
        }

        if (node.remotePath != path) { // It timed out.
          return null;
        }

        var full = await getDSNode(child, child.remotePath);

        print("Loading Node: ${child.remotePath}");

        var m = new NodeModel(child);
        nodez.add(m);
        nmap[child.remotePath] = m;
        if (m.node.getConfig(r"$type") != null) {
          print("Subscribing to ${child.remotePath}");
          listeners[child.remotePath] = requester.subscribe(child.remotePath, (ValueUpdate update) {
            m.value = update.value;
          });
        }
      }
    });
  }

  Future<RemoteNode> getDSNode(RemoteNode xnode, String path) async {
    RemoteNode n = await requester.list(path).where((it) => it.streamStatus != StreamStatus.initialize).map((it) => it.node).first.timeout(new Duration(seconds: 3), onTimeout: () {
      return xnode;
    });
    return n;
  }

  onNodeClicked(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent;
    var p = x.attributes["path"];
    path = p;
  }

  onViewNodeClicked(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent;
    var p = x.attributes["path"];

    var dialog = x.querySelector("#dialog") as PaperDialog;
    dialog.open();
  }

  onClicked(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent;
    var p = x.attributes["path"];

    var dialog = x.querySelector("#dialog") as PaperDialog;
    dialog.open();
  }

  onInvokeClicked(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent;
    var p = x.attributes["path"];
    var dialog = x.querySelector("#invoke-dialog") as PaperDialog;
    dialog.open();
  }

  invokeAction(Event event, var detail, var target) async {
    var dialog = (event.target as HtmlElement).parent.parent as PaperDialog;
    var map = {};
    var parames = dialog.querySelectorAll(".action-param");

    for (var x in parames) {
      var key = x.attributes["data-key"];
      if (x is PaperInput) {
        map[key] = x.value;
      } else if (x is CoreMenu) {
        map[key] = ((x as CoreMenu).selectedItem as PaperItem).text.trim().toLowerCase() == "true";
      }
    }

    var stream = requester.invoke(dialog.attributes["data-path"], map);
    var update = await stream.first;
    var result = update.updates.first;
    if (result is Map && result.keys.length == 1) {
      result = result[result.keys.first];
    }
    var a = dialog.querySelector("#invoke-value-dialog");
    a.querySelector("#value").text = valueAsString(result);
    a.open();
  }

  onWatchValueClicked(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent;
    var p = x.attributes["path"];

    var dialog = x.querySelector("#watch-dialog") as PaperDialog;
    dialog.open();
  }

  closeDialog(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent as PaperDialog;
    x.toggle();
  }

  Stream<String> get pathStream => _pathController.stream;
  StreamController<String> _pathController = new StreamController<String>();
}

class ActionParameter {
  String name;
  Object defaultValue;
  String type;

  ActionParameter(Map map) {
    name = map["name"];
    defaultValue = map["default"];
    type = map["type"];
  }

  bool get isString => !isBoolean;
  bool get isBoolean => type.toLowerCase().contains("bool");

  String get label => "${name}${defaultValue != null ? ' (${defaultValue})' : ''}";
}

class NodeModel extends Observable {
  final RemoteNode node;

  NodeModel(this.node);

  bool get hasIcon => node.attributes.containsKey("icon");
  String get icon => node.getAttribute("icon");
  String get name => node.name;
  String get path => node.remotePath;
  bool get hasValue => node.getConfig(r"$type") != null;
  String get type => node.getConfig(r"$type");
  bool get hasChildren => node.children.isNotEmpty;
  @observable dynamic value;
  Map<String, dynamic> get attributes => node.attributes;
  Map<String, dynamic> get configs => node.configs;
  bool get isInvokable => node.getConfig(r"$invokable") != null;

  List<ActionParameter> _params;

  List<ActionParameter> get params {
    if (_params != null) return _params;

    _params = [];

    if (node.getConfig(r"$params") == null) {
      return _params;
    }

    for (var o in node.getConfig(r"$params")) {
      _params.add(new ActionParameter(o));
    }

    return _params;
  }

  valueAsString(value) {
    if (value is Map || value is List) {
      return _jsonEncoder.convert(value);
    } else {
      return value == null ? "null" : value.toString();
    }
  }
}

JsonEncoder _jsonEncoder = new JsonEncoder.withIndent("  ");

valueAsString(value) {
  if (value is Map || value is List) {
    return _jsonEncoder.convert(value);
  } else {
    return value == null ? "null" : value.toString();
  }
}
