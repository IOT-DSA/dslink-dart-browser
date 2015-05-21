@HtmlImport("package:core_elements/core_list_dart.html")
@HtmlImport("material_card.html")
@HtmlImport("package:paper_elements/paper_button.html")
@HtmlImport("package:paper_elements/paper_dialog.html")
@HtmlImport("package:paper_elements/paper_input.html")
library dsa_browser.dsa_nodes;

import "dart:async";
import "dart:html";
import "dart:convert";

import "package:dsa_browser/dsa_browser.dart";
import "package:dslink/requester.dart";
import "package:paper_elements/paper_dialog.dart";
import "package:paper_elements/paper_input.dart";
import "package:core_elements/core_menu.dart";
import "package:core_elements/core_list_dart.dart";
import "package:paper_elements/paper_item.dart";

@CustomTag("dsa-nodes")
class DSNodesElement extends PolymerElement with Observable {
  @observable List<NodeModel> nodez = toObservable([]);
  @published @observable String path = "/";
  @observable NodeModel topNode;

  Map<String, NodeModel> nmap = {};
  Map<String, ReqSubscribeListener> listeners = {};

  DSNodesElement.created() : super.created();

  bool loaded = false;

  @override
  void attached() {
    super.attached();

    list = $["node-list"];

    print("DSA Nodes Element Attached");

    onReadyHandlers.add(() {
      loaded = true;
      loadNodes();
    });

    onPropertyChange(this, #path, () {
      ignoreHashChange = true;
      window.location.hash = "#${path}";
      ignoreHashChange = false;
      _pathController.add(path);
      if (loaded) {
        loadNodes();
      }
    });

    $["topnode-meta-table"].columns = ["Key", "Value"];
  }

  Stream<RequesterListUpdate> _listUpdate;
  Stream<ValueUpdate> _valueUpdates;
  StreamSubscription<RequesterListUpdate> _listSub;

  CoreList list;

  loadNodes() async {
    toggleSpinner(true);
    nodez.clear();
    if (_listSub != null) {
      await _listSub.cancel();
    }

    refreshAction = () {
      print("Refresh");
      loadNodes();
    };

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

    viewAction = () {
      print("View Top Node");
      PaperDialog dialog = $["view-top-node"];
      dialog.open();
    };

    _listUpdate = requester.list(path);
    _listSub = _listUpdate.listen((e) async {
      print("List Update: ${e.node.remotePath}");

      if (e.streamStatus == StreamStatus.initialize) {
        return null;
      }

      var node = e.node;
      topNode = new NodeModel(node);

      var futures = [];

      for (var c in _ttc) {
        c.cancel();
      }

      _ttc.clear();

      for (RemoteNode child in node.children.values) {
        futures.add(new Future(() async {
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

          var m = new NodeModel(child);

          nodez.add(m);
          nmap[child.remotePath] = m;

          RemoteNode full = await getDSNode(child, child.remotePath);

          if (full.children.isNotEmpty) {
            m.hasChildren = true;
          }

          if (full.getConfig(r"$invokable") != null) {
            m.isInvokable = true;
          }

          if (full.getConfig(r"$disconnectedTs") != null) {
            m.offline = true;
            m.offlineTime = DateTime.parse(full.getConfig(r"$disconnectedTs"));

            var t = new Timer.periodic(new Duration(seconds: 1), (timer) {
              var now = new DateTime.now();
              var off = m.offlineTime;
              var diff = now.difference(off);
              m.offlineTimeString = getDurationString(diff);
            });

            _ttc.add(t);
          } else {
            m.offline = false;
          }

          if (full.getConfig(r"$type") != null) {
            m.hasValue = true;
          }

          print("Loading Node: ${child.remotePath}");

          if (m.node.getConfig(r"$type") != null) {
            print("Subscribing to ${child.remotePath}");
            listeners[child.remotePath] = requester.subscribe(child.remotePath, (ValueUpdate update) {
              m.value = update.value;
            });
          }
          m.ready = true;
        }));
      }

      Future.wait(futures).then((_) {
        if (node.remotePath != path) {
          return;
        }
        toggleSpinner(false);
      });
    });
  }

  List<Timer> _ttc = [];

  Future<RemoteNode> getDSNode(RemoteNode xnode, String path) async {
    RemoteNode n = await requester
    .list(path)
    .where((it) => it.streamStatus != StreamStatus.initialize)
    .map((it) => it.node)
    .first
    .timeout(new Duration(milliseconds: 1500), onTimeout: () {
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
    //dialog.querySelector("#node-meta-table").columns = ["Key", "Value"];
    dialog.notifyResize();
  }

  onClicked(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent;
    var p = x.attributes["path"];

    var dialog = x.querySelector("#dialog") as PaperDialog;
    dialog.open();
    dialog.notifyResize();
  }

  onInvokeClicked(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent;
    var p = x.attributes["path"];
    var dialog = x.querySelector("#invoke-dialog") as PaperDialog;
    dialog.open();
    dialog.notifyResize();
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
    a.notifyResize();
  }

  onWatchValueClicked(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent;
    var p = x.attributes["path"];

    var dialog = x.querySelector("#watch-dialog") as PaperDialog;
    dialog.open();
    dialog.notifyResize();
  }

  closeDialog(Event event, var detail, var target) {
    var x = (event.target as HtmlElement).parent.parent as PaperDialog;
    x.toggle();
  }

  Stream<String> get pathStream => _pathController.stream;
  StreamController<String> _pathController = new StreamController<String>();
}

String getDurationString(Duration duration) {
  if (duration.inMilliseconds < 1000) {
    return "${duration.inMilliseconds} millisecond${duration.inMilliseconds == 1 ? '' : 's'}";
  } else if (duration.inSeconds < 60) {
    return "${duration.inSeconds} second${duration.inSeconds == 1 ? '' : 's'}";
  } else if (duration.inMinutes < 60) {
    return "${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}";
  } else if (duration.inHours < 24) {
    return "${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}";
  } else {
    return "${duration.inDays} day${duration.inDays == 1 ? '' : 's'}";
  }
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
  String get displayName => node.configs.containsKey(r"$name") ? node.getConfig(r"$name") : node.name;
  String get path => node.remotePath;
  @observable
  bool hasValue = false;
  String get type => node.getConfig(r"$type");
  @observable
  bool hasChildren = false;
  @observable dynamic value;
  Map<String, dynamic> get attributes => node.attributes;
  Map<String, dynamic> get configs => node.configs;
  Map<String, dynamic> get meta => {}..addAll(attributes)..addAll(configs);
  @observable
  bool isInvokable = false;
  @observable
  bool ready = false;

  @observable
  DateTime offlineTime;

  @observable
  String offlineTimeString;

  @observable
  bool offline = false;

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
    String str;
    if (value is Map || value is List) {
      str = _jsonEncoder.convert(value);
    } else {
      str = value == null ? "null" : value.toString();
    }

    if (str.length > 400) {
      str = str.substring(0, 400) + "...";
    }
    return str;
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
