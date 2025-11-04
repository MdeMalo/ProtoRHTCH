import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// ../services/pose_utils.dart is not required here; remove unused import.

/// A [CustomPainter] that renders the detected pose landmarks and skeletal
/// connections on top of the camera preview.  It also displays the current
/// angle at a joint (knee or elbow) and the repetition count.
///
/// The coordinate translation logic used here is adapted from the official
/// ML Kit pose detection example.  It transforms landmark coordinates from
/// image space into the canvas coordinate system taking into account
/// rotation and camera lens direction.
class PosePainter extends CustomPainter {
  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    this.jointType = PoseLandmarkType.leftKnee,
    this.currentAngle,
    this.repetitionCount = 0,
  });

  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final PoseLandmarkType jointType;
  final double? currentAngle;
  final int repetitionCount;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint settings for landmarks and lines
    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red
      ..strokeWidth = 6.0;
    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;
    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    final Map<PoseLandmarkType, Offset> landmarkOffsets = {};
    // Precompute translated offsets for each landmark.
    pose.landmarks.forEach((type, landmark) {
      landmarkOffsets[type] = Offset(
        _translateX(landmark.x, size, imageSize, rotation, cameraLensDirection),
        _translateY(landmark.y, size, imageSize, rotation, cameraLensDirection),
      );
    });

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2, Paint paint) {
      final p1 = landmarkOffsets[type1];
      final p2 = landmarkOffsets[type2];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }

    // Draw body connections similar to the example
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);

    // Draw all landmarks as small circles.
    for (final offset in landmarkOffsets.values) {
      canvas.drawCircle(offset, 2.0, Paint()..color = Colors.green);
    }

    // Highlight the joint being measured.
    final jointOffset = landmarkOffsets[jointType];
    if (jointOffset != null) {
      canvas.drawCircle(jointOffset, 6.0, jointPaint);
    }

    // Draw angle and repetition count text near the top of the canvas.
    final textPainter = TextPainter(
      text: TextSpan(
        text:
            'Reps: $repetitionCount\nAngle: ${currentAngle?.toStringAsFixed(1) ?? '--'}°',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: size.width - 20);
    textPainter.paint(canvas, const Offset(10, 10));
  }

  /// Translate the landmark's x coordinate to the canvas coordinate system.
  double _translateX(
    double x,
    Size size,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
  ) {
  final scaleX = size.width / imageSize.width;
    double result;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        result = x * scaleX;
        break;
      case InputImageRotation.rotation270deg:
        result = size.width - x * scaleX;
        break;
      default:
        result = x * scaleX;
    }
    if (cameraLensDirection == CameraLensDirection.front) {
      return size.width - result;
    }
    return result;
  }

  /// Translate the landmark's y coordinate to the canvas coordinate system.
  double _translateY(
    double y,
    Size size,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
  ) {
    final scaleY = size.height / imageSize.height;
    double result;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        result = y * scaleY;
        break;
      default:
        result = y * scaleY;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.repetitionCount != repetitionCount ||
        oldDelegate.currentAngle != currentAngle;
  }
}