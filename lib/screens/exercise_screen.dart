import 'dart:async';

import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import '../services/pose_utils.dart';
import '../widgets/pose_painter.dart';
import 'package:flutter/foundation.dart';

// Helper container so we can return both the created InputImage and the
// associated metadata (size + rotation). This avoids relying on
// `inputImage.inputImageData` which isn't available in the installed
// version of the ML Kit packages.
class _ConvertedCameraImage {
  final InputImage image;
  final Size imageSize;
  final InputImageRotation rotation;

  _ConvertedCameraImage(this.image, this.imageSize, this.rotation);
}
 



/// The main screen responsible for capturing live camera frames, running the
/// ML Kit pose detector and counting repetitions.  It presents a camera
/// preview with an overlaid skeletal drawing and simple textual feedback.
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late List<CameraDescription> _cameras;
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _noCameras = false;

  late PoseDetector _poseDetector;
  final RepetitionCounter _repetitionCounter =
      RepetitionCounter(joint: PoseLandmarkType.leftKnee);

  bool _isBusy = false;
  CustomPaint? _customPaint;
  int _repCount = 0;
  double? _lastAngle;
  bool _isStreaming = false;
  // Debug overrides for rotation (degrees) and mirror. Use null to keep
  // device-provided values. These are toggled from on-screen debug buttons.
  int? _debugRotationDegrees;
  bool? _debugMirror;

  @override
  void initState() {
    super.initState();
    _initializeDetector();
    // Request camera permission and initialize the camera only when
    // permission is granted.
    _checkAndInitCamera();
  }

  Future<void> _checkAndInitCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
      // Mark that we do have camera(s) available after successful init.
      _noCameras = false;
      if (mounted) setState(() {});
      return;
    }

    if (status.isPermanentlyDenied) {
      // Show a dialog guiding the user to app settings.
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permiso requerido'),
          content: const Text(
              'La aplicación necesita permiso de cámara para funcionar. Abre los ajustes de la aplicación para habilitarlo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );
      return;
    }

    // Denied (but not permanently): show an explanation and do not start camera.
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso denegado'),
        content: const Text(
            'Sin permiso de cámara no se puede iniciar el flujo de imagen. Por favor concede el permiso y vuelve a intentarlo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Initialise the ML Kit pose detector with default options.
  void _initializeDetector() {
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
  }

  /// Fetch the available cameras and start streaming from the selected one.
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e, st) {
      debugPrint('Error calling availableCameras(): $e\n$st');
      _cameras = <CameraDescription>[];
    }
    debugPrint('Available cameras: ${_cameras.map((c) => c.name + " (" + c.lensDirection.toString() + ")").toList()}');
    if (_cameras.isEmpty) {
      _noCameras = true;
      if (mounted) {
        setState(() {});
        // Show a dialog offering guidance and a retry button.
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cámara no detectada'),
            content: const Text(
                'No se detectó ninguna cámara. Comprueba que el dispositivo tiene cámara, que la app tiene permisos y que no estás usando un emulador sin cámara.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Try again
                  _noCameras = false;
                  setState(() {});
                  _initializeCamera();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
      }
      return;
    }
    // Default to the back camera if present; otherwise use the first camera.
    _cameraIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back);
    if (_cameraIndex < 0) _cameraIndex = 0;
    await _startCameraStream();
  }

  /// Start streaming images from the current camera and attach a listener to
  /// process each frame.
  Future<void> _startCameraStream() async {
    final description = _cameras[_cameraIndex];
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      // Force YUV420 frames which ML Kit expects on Android devices.
      // This helps avoid `ImageFormat is not supported` errors on some phones.
      imageFormatGroup: ImageFormatGroup.yuv420,
      enableAudio: false,
    );
    _controller = controller;
    try {
      await controller.initialize();
      // Lock capture orientation to reduce reconfiguration churn on some
      // devices (e.g., MIUI) that triggers session restarts.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
  await controller.startImageStream(_processCameraImage);
  _isStreaming = true;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Stop the current stream and dispose the controller.
  Future<void> _stopCameraStream() async {
    if (_controller != null) {
      try {
        // Only stop the image stream if it's currently running.
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
      } catch (e) {
        debugPrint('Error while stopping image stream: $e');
      }
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint('Error while disposing camera controller: $e');
      }
      _controller = null;
      _isStreaming = false;
    }
  }

  Future<void> _pauseCameraStream() async {
    if (_controller != null && _isStreaming) {
      await _controller!.stopImageStream();
      _isStreaming = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _resumeCameraStream() async {
    if (_controller != null && !_isStreaming) {
      await _controller!.startImageStream(_processCameraImage);
      _isStreaming = true;
      if (mounted) setState(() {});
    }
  }

  /// Switch between available cameras (front/back).
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopCameraStream();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCameraStream();
  }

  /// Convert a [CameraImage] in YUV format into an [InputImage] that can be
  /// consumed by ML Kit.  Adapted from the official ML Kit sample.
  /// Convierte la imagen de la cámara (YUV) a un InputImage compatible con ML Kit.
  _ConvertedCameraImage _convertCameraImage(CameraImage image, CameraDescription description) {
    // On Android, camera frames are typically YUV_420_888 (3 planes). On iOS,
    // frames are typically BGRA8888 (1 plane). Convert accordingly.
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    Uint8List bytes;
    InputImageFormat format;
    int bytesPerRow;

    if (image.planes.length == 1) {
      // iOS (BGRA8888) path.
      final plane = image.planes.first;
      bytes = plane.bytes;
      format = InputImageFormat.bgra8888;
      bytesPerRow = plane.bytesPerRow;
    } else {
      // Android (YUV420) -> NV21 path.
      try {
        final width = image.width;
        final height = image.height;
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];

        final int frameSize = width * height;
        final nv21 = Uint8List(frameSize + (frameSize ~/ 2));

        // Copy Y plane
        int dstIndex = 0;
        for (int row = 0; row < height; row++) {
          final int srcOffset = row * yPlane.bytesPerRow;
          nv21.setRange(dstIndex, dstIndex + width, yPlane.bytes, srcOffset);
          dstIndex += width;
        }

        // Interleave V and U (NV21 uses VU ordering)
        final uvHeight = (height / 2).floor();
        final uvWidth = (width / 2).floor();
        // Estimate pixel stride for U/V planes from bytesPerRow and width.
        final int uPixelStrideEstimate = (uPlane.bytesPerRow / uvWidth).round();
        final int vPixelStrideEstimate = (vPlane.bytesPerRow / uvWidth).round();
        for (int row = 0; row < uvHeight; row++) {
          final int uRowStart = row * uPlane.bytesPerRow;
          final int vRowStart = row * vPlane.bytesPerRow;
          for (int col = 0; col < uvWidth; col++) {
            final int uIndex = uRowStart + col * uPixelStrideEstimate;
            final int vIndex = vRowStart + col * vPixelStrideEstimate;
            nv21[dstIndex++] = vPlane.bytes[vIndex];
            nv21[dstIndex++] = uPlane.bytes[uIndex];
          }
        }

        bytes = nv21;
        format = InputImageFormat.nv21;
        bytesPerRow = image.planes.first.bytesPerRow;
      } catch (e, st) {
        // Fallback: concatenate planes and try anyway.
        debugPrint('NV21 conversion failed, falling back to concatenating planes: $e\n$st');
        final WriteBuffer allBytes = WriteBuffer();
        for (final plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        bytes = allBytes.done().buffer.asUint8List();
        format = InputImageFormat.nv21;
        bytesPerRow = image.planes.first.bytesPerRow;
      }
    }

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );

    return _ConvertedCameraImage(inputImage, imageSize, rotation);
  }

  // Track consecutive conversion errors so we can pause the stream if the
  // device is producing frames ML Kit can't handle. This avoids a tight
  // error loop that can make the app unstable on some devices.
  int _conversionErrorCount = 0;
  DateTime? _firstConversionErrorAt;


  /// Called for every camera frame.  Runs pose detection, updates the state
  /// variables and redraws the overlay.
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy || _controller == null) return;
    _isBusy = true;
    final description = _controller!.description;
    _ConvertedCameraImage? converted;
    InputImage? inputImage;
    try {
      // Log a little metadata for debugging in case of conversion issues.
      debugPrint('CameraImage format.raw=${image.format.raw} planes=${image.planes.length} w=${image.width} h=${image.height}');
      converted = _convertCameraImage(image, description);
      inputImage = converted.image;
    } catch (e, st) {
      debugPrint('Exception converting CameraImage -> InputImage: $e\n$st');
      // Treat this as a conversion error and count it below via the same
      // handling used for processing-time conversion failures.
      _handleConversionError();
      _isBusy = false;
      return;
    }
    try {
  final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        final pose = poses.first;
        // Compute angle and update repetition count.
        double? angle;
        PoseLandmark? hip = pose.landmarks[PoseLandmarkType.leftHip];
        PoseLandmark? knee = pose.landmarks[PoseLandmarkType.leftKnee];
        PoseLandmark? ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
        if (hip != null && knee != null && ankle != null) {
          angle = PoseUtils.calculateAngle(hip, knee, ankle);
          _lastAngle = angle;
        }
        _repCount = _repetitionCounter.process(pose);
        // Generate a new painter for the current pose.
        final painter = PosePainter(
          pose: pose,
          imageSize: converted.imageSize,
          rotation: converted.rotation,
          cameraLensDirection: description.lensDirection,
          jointType: _repetitionCounter.joint,
          currentAngle: _lastAngle,
          repetitionCount: _repCount,
          // Pass debug overrides from UI
          debugRotationDegrees: _debugRotationDegrees,
          debugMirror: _debugMirror,
        );
        _customPaint = CustomPaint(painter: painter);
      } else {
        _customPaint = null;
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      // Detect ML Kit conversion errors (different devices produce different
      // native messages). If we see the conversion error, track it so we can
      // temporarily pause the stream and avoid a tight failure loop.
      final message = e.toString();
      if (message.contains('InputImageConverterError') || message.contains('ImageFormat is not supported')) {
        _handleConversionError();
      }
    } finally {
      _isBusy = false;
    }
  }

  void _handleConversionError() {
    final now = DateTime.now();
    if (_firstConversionErrorAt == null || now.difference(_firstConversionErrorAt!) > const Duration(seconds: 5)) {
      _firstConversionErrorAt = now;
      _conversionErrorCount = 1;
    } else {
      _conversionErrorCount++;
    }

    debugPrint('Conversion error count=$_conversionErrorCount since=$_firstConversionErrorAt');

    // If several conversion errors happen quickly, pause the stream and
    // inform the user to try a different camera or a lower resolution.
    if (_conversionErrorCount >= 8) {
      debugPrint('Pausing camera stream due to repeated unsupported image format');
      _pauseCameraStream();
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Formato de imagen no soportado'),
            content: const Text(
                'Parece que la cámara está entregando un formato que ML Kit no puede procesar en este dispositivo. Intenta cambiar la cámara, bajar la resolución o reiniciar la app.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Try restarting the stream at a lower resolution.
                  _stopCameraStream().then((_) async {
                    // start again with a lower preset
                    final desc = _cameras[_cameraIndex];
                    _controller = CameraController(desc, ResolutionPreset.low, enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
                    try {
                      await _controller!.initialize();
                      await _controller!.startImageStream(_processCameraImage);
                      _isStreaming = true;
                      if (mounted) setState(() {});
                    } catch (err) {
                      debugPrint('Error restarting camera at lower resolution: $err');
                    }
                  });
                },
                child: const Text('Intentar resolución baja'),
              ),
            ],
          ),
        );
      }

      // reset counters after pausing/alerting so we don't repeat immediately.
      _conversionErrorCount = 0;
      _firstConversionErrorAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_noCameras) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se detectó ninguna cámara en el dispositivo.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _noCameras = false;
                setState(() {});
                _checkAndInitCamera();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (_controller == null || !_controller!.value.isInitialized) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(
            _controller!,
            child: _customPaint,
          ),
          // Top overlay showing reps and current angle
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reps: $_repCount',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Ángulo: ${_lastAngle != null ? _lastAngle!.toStringAsFixed(1) + '°' : '--'}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'switchCamera',
              onPressed: _switchCamera,
              child: const Icon(Icons.flip_camera_android),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 100,
            child: FloatingActionButton(
              heroTag: 'pauseResume',
              backgroundColor: _isStreaming ? Colors.orange : Colors.green,
              onPressed: () {
                if (_isStreaming) {
                  _pauseCameraStream();
                } else {
                  _resumeCameraStream();
                }
              },
              child: Icon(_isStreaming ? Icons.pause : Icons.play_arrow),
            ),
          ),
            // Debug controls: rotate / mirror toggles to test alignment
            Positioned(
              bottom: 20,
              right: 180,
              child: FloatingActionButton(
                heroTag: 'debugRotate',
                backgroundColor: Colors.blueGrey,
                onPressed: () {
                  // Cycle through 0,90,180,270,null (null => use camera rotation)
                  final seq = [0, 90, 180, 270, -1];
                  final cur = _debugRotationDegrees ?? -1;
                  final idx = seq.indexOf(cur);
                  final next = seq[(idx + 1) % seq.length];
                  setState(() {
                    _debugRotationDegrees = next == -1 ? null : next;
                  });
                  debugPrint('[DEBUG] rotation override -> '
                      '${_debugRotationDegrees?.toString() ?? 'auto'}');
                },
                child: const Icon(Icons.rotate_right),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 260,
              child: FloatingActionButton(
                heroTag: 'debugMirror',
                backgroundColor: Colors.purple,
                onPressed: () {
                  setState(() {
                    _debugMirror = !(_debugMirror ?? false);
                  });
                  debugPrint('[DEBUG] mirror override -> '
                      '${_debugMirror == true ? 'ON' : 'OFF'}');
                },
                child: const Icon(Icons.flip),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'finishExercise',
              backgroundColor: Colors.red,
              onPressed: () {
                // Stop the camera stream and navigate to the results screen.
                _stopCameraStream().then((_) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/result',
                    arguments: _repCount,
                  );
                });
              },
              child: const Icon(Icons.stop),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicio en progreso'),
      ),
      body: content,
    );
  }

  @override
  void dispose() {
    // Close ML Kit detector and ensure camera is stopped/disposed.
    try {
      _poseDetector.close();
    } catch (_) {}
    // Best-effort stop of camera stream; _stopCameraStream is async but
    // we call it without awaiting here as dispose can't be async.
    try {
      _stopCameraStream();
    } catch (_) {}
    super.dispose();
  }
}