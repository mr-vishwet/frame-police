import 'package:flutter/material.dart';

import 'app.dart';
import 'state/app_controller.dart';

void main() {
  final controller = AppController();
  runApp(FramePoliceApp(controller: controller));
}
