@HtmlImport("package:core_elements/core_list_dart.html")
@HtmlImport("material_card.html")
@HtmlImport("package:paper_elements/paper_button.html")
library control_room.dsa_nodes;

import "dart:async";

import "package:control_room/control_room.dart";
import "package:dslink/requester.dart";
import "package:core_elements/core_list_dart.dart";
import "dart:html";

@CustomTag("dsa-nodes")
class DSNodesElement extends PolymerElement with Observable {
  @observable List<NodeModel> nodez = toObservable([]);
  @published @observable String path = "/";

  Map<String, NodeModel> nmap = {};

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
      if (loaded) {
        loadNodes();
      }
    });

    var list = $["list"] as CoreList;
    list.addEventListener("core-activate", (e) {
      var item = e.detail.item;
      print(item);
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

    _listUpdate = requester.list(path);
    _listSub = _listUpdate.listen((e) {
      for (RemoteNode child in e.node.children.values) {
        var existing = nodez.where((it) => it.node.remotePath == child.remotePath);

        if (existing.isNotEmpty) {
          for (var x in existing.toList()) {
            nodez.remove(x);
            nmap.remove(x.path);
          }
        }

        print("Loading Node: ${child.remotePath}");

        var m = new NodeModel(child);
        nodez.add(m);
        nmap[child.remotePath] = m;
      }
    });
  }

  onNodeClicked(Event event, var detail, var target) {
    print("Material Card Clicked");
    var x = event.target as HtmlElement;
    var p = x.attributes["path"];
    attributes["path"] = p;
  }
}

class NodeModel {
  final RemoteNode node;

  NodeModel(this.node);

  bool get hasIcon => node.attributes.containsKey("icon");
  String get icon => node.getAttribute("icon");
  String get name => node.name;
  String get path => node.remotePath;
  bool get hasValue => node.attributes.containsKey("value");
  dynamic get value => node.getAttribute("value");
}
