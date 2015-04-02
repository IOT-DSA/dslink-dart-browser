import "package:control_room/control_room.dart";

@CustomTag("dsa-links")
class DSLinksElement extends PolymerElement {
  @observable List<LinkModel> links = toObservable([]);

  DSLinksElement.created() : super.created();

  @override
  void attached() {
    super.attached();
    loadLinks();
  }

  loadLinks() async {
    requester.list("/conns").listen((e) {
      for (RemoteNode child in e.node.children.values) {
        links.add(new LinkModel(child));
      }
    });
  }
}

class LinkModel {
  final RemoteNode node;

  LinkModel(this.node);

  bool get hasIcon => node.attributes.containsKey("icon");
  String get icon => node.getAttribute("icon");
  String get name => node.name;
}
