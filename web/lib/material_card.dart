import "package:polymer/polymer.dart";
import "package:paper_elements/paper_shadow.dart";

@CustomTag("material-card")
class MaterialCard extends PolymerElement {
  MaterialCard.created() : super.created();

  int z_mouseout = 1;
  int z_mouseover = 5;
  @published bool autoraise = false;

  @override
  attached() {
    super.attached();

    if (autoraise) {
      onMouseOver.listen((e) {
        var shadow = $["shadow"] as PaperShadow;
        shadow.setZ(z_mouseover);
      });

      onMouseOut.listen((e) {
        var shadow = $["shadow"] as PaperShadow;
        shadow.setZ(z_mouseout);
      });
    }
  }
}
