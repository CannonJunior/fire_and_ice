import 'package:flutter/material.dart';
import 'game/game_widget.dart';

/// Entry point for the Fire & Ice aviation game.
///
/// Sets up a dark Material theme and mounts the game screen.
/// No Riverpod or state management framework - plain Flutter setState.
void main() {
  runApp(const FireAndIceApp());
}

/// Root application widget with dark game theme.
class FireAndIceApp extends StatelessWidget {
  const FireAndIceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire & Ice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90D9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
          ),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

/// Full-screen game container.
///
/// Provides a Scaffold with a black background and mounts the
/// main game widget which manages WebGL + HUD.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: FireAndIceGame(),
    );
  }
}
