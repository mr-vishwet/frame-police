import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'state/app_controller.dart';

void main() {
  final controller = AppController();
  runApp(FramePoliceApp(controller: controller));
}
