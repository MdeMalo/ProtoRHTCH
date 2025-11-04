import 'package:flutter/material.dart';

/// Displays a summary of the completed exercise session.  Shows the total
/// repetition count and offers a way to return to the home screen.  In a
/// production application you might extend this page with graphs, charts,
/// durations or options to save the results.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.count});

  /// The number of completed repetitions.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen del ejercicio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¡Buen trabajo!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '$count',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            const Text('Repeticiones completadas', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.popUntil(context, ModalRoute.withName('/'));
              },
              icon: const Icon(Icons.home),
              label: const Text('Regresar al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}