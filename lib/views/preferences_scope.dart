import 'package:flutter/material.dart';

import '../controllers/preferences_controller.dart';

class PreferencesScope extends InheritedNotifier<PreferencesController> {
  const PreferencesScope({
    super.key,
    required PreferencesController controller,
    required super.child,
  }) : super(notifier: controller);
  static PreferencesController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()!.notifier!;
  static PreferencesController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PreferencesScope>()!.notifier!;
}
