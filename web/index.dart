import "package:polymer/polymer.dart";

import "package:control_room/control_room.dart";

export "package:polymer/init.dart";

@initMethod
startup() async {
  await initControlRoom();
}
