import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Simple entry screen for the ExoRehab AI prototype.  Presents a single
/// button that starts the exercise.  Additional navigation options could be
/// added here later (e.g. settings or exercise selection).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RehabTech Prototype'),
        actions: [
          IconButton(
            onPressed: () async {
              // Quick diagnostic: list available cameras and show in a dialog.
              List<CameraDescription> cameras = <CameraDescription>[];
              try {
                cameras = await availableCameras();
              } catch (e) {
                // ignore
              }
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Diagnóstico de cámara'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: cameras.isEmpty
                        ? const Text('No se encontraron cámaras.')
                        : ListView(
                            shrinkWrap: true,
                            children: cameras
                                .map((c) => ListTile(
                                      title: Text(c.name),
                                      subtitle: Text(c.lensDirection.toString()),
                                    ))
                                .toList(),
                          ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.settings),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 96, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'ExoRehab AI',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuenta repeticiones usando la cámara y ML Kit. Mantente frente a la cámara y realiza el ejercicio.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/exercise');
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar ejercicio'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}