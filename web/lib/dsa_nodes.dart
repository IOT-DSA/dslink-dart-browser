@HtmlImport("package:core_elements/core_list_dart.html")
@HtmlImport("material_card.html")
@HtmlImport("package:paper_elements/paper_button.html")
@HtmlImport("package:paper_elements/paper_dialog.html")
library control_room.dsa_nodes;

import "dart:async";
import "dart:convert";

import "package:control_room/control_room.dart";
import "package:dslink/requester.dart";
import "package:paper_elements/paper_dialog.dart";
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

        var full = await getDSNode(child, child.remotePath);

        if (node.remotePath != path) { // It timed out.
          return null;
        }

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

  valueAsString(value) {
    if (value is Map || value is List) {
      return _jsonEncoder.convert(value);
    } else {
      return value == null ? "null" : value.toString();
    }
  }
}

JsonEncoder _jsonEncoder = new JsonEncoder.withIndent("  ");
