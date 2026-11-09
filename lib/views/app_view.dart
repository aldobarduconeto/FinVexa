import 'app_theme.dart';
import 'welcome_gate.dart';
import 'workspace_view.dart';
import 'preferences_scope.dart';
import 'package:flutter/material.dart';
import '../controllers/preferences_controller.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final preferences = PreferencesController();
  @override
  void initState() {
    super.initState();
    preferences.load();
  }

  @override
  void dispose() {
    preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PreferencesScope(
    controller: preferences,
    child: AnimatedBuilder(
      animation: preferences,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FinVexa',
        theme: buildAppTheme(preferences.value, Brightness.light),
        darkTheme: buildAppTheme(preferences.value, Brightness.dark),
        themeMode: preferences.value.themeMode,
        home: preferences.loaded
            ? const WelcomeGate(child: Dashboard())
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    ),
  );
}
