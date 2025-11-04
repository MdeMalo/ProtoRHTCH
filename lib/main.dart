import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/result_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RehabTechApp());
}

/// Root widget for the prototype.  Sets up named routes and a basic theme.
class RehabTechApp extends StatelessWidget {
  const RehabTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RehabTech Prototype',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/exercise': (context) => const ExerciseScreen(),
        '/result': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int count = 0;
          if (args is int) count = args;
          return ResultScreen(count: count);
        },
      },
    );
  }
}