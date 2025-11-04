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
    this.debugRotationDegrees,
    this.debugMirror,
  });

  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final PoseLandmarkType jointType;
  final double? currentAngle;
  final int repetitionCount;
  // Optional debug overrides (degrees). If null, use provided rotation.
  final int? debugRotationDegrees;
  // If non-null, override mirror decision (true => mirrored)
  final bool? debugMirror;

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
      // Determine effective rotation degrees and mirror flag from overrides.
      final effectiveRotationDeg = debugRotationDegrees ?? _rotationDegreesFromEnum(rotation);
      final effectiveMirror = debugMirror ?? (cameraLensDirection == CameraLensDirection.front);
      final mapped = _mapPoint(landmark.x, landmark.y, size, imageSize, effectiveRotationDeg, effectiveMirror);
      landmarkOffsets[type] = mapped;
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

    // Draw all landmarks as small circles (transformed)
    for (final offset in landmarkOffsets.values) {
      canvas.drawCircle(offset, 3.0, Paint()..color = Colors.green);
    }

    // Also draw the raw image-space points (no rotation/mirror) in red to
    // help debugging misalignment. Raw mapping assumes image coordinates map
    // directly with no rotation and no mirror.
    for (final landmark in pose.landmarks.values) {
      final rx = (landmark.x / imageSize.width) * size.width;
      final ry = (landmark.y / imageSize.height) * size.height;
      canvas.drawCircle(Offset(rx, ry), 2.0, Paint()..color = Colors.red);
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
  /// Map an image-space point (x,y) into canvas coordinates taking into
  /// account image rotation and front/back mirroring.
  Offset _mapPoint(
    double x,
    double y,
    Size canvasSize,
    Size imageSize,
    int rotationDegrees,
    bool mirror,
  ) {
    // Use mapping logic aligned with ML Kit examples that accounts for
    // rotation by swapping width/height where appropriate and then scales
    // into the canvas. Finally, apply horizontal mirroring if requested.
    double px, py;
    switch (rotationDegrees % 360) {
      case 90:
        // Image rotated 90° clockwise.
        // x' = y; y' = imageWidth - x
        px = y * (canvasSize.width / imageSize.height);
        py = (imageSize.width - x) * (canvasSize.height / imageSize.width);
        break;
      case 180:
        // x' = imageWidth - x; y' = imageHeight - y
        px = (imageSize.width - x) * (canvasSize.width / imageSize.width);
        py = (imageSize.height - y) * (canvasSize.height / imageSize.height);
        break;
      case 270:
        // x' = imageHeight - y; y' = x
        px = (imageSize.height - y) * (canvasSize.width / imageSize.height);
        py = x * (canvasSize.height / imageSize.width);
        break;
      case 0:
      default:
        // No rotation.
        px = x * (canvasSize.width / imageSize.width);
        py = y * (canvasSize.height / imageSize.height);
        break;
    }

    if (mirror) {
      px = canvasSize.width - px;
    }
    return Offset(px, py);
  }

  int _rotationDegreesFromEnum(InputImageRotation r) {
    switch (r) {
      case InputImageRotation.rotation90deg:
        return 90;
      case InputImageRotation.rotation180deg:
        return 180;
      case InputImageRotation.rotation270deg:
        return 270;
      case InputImageRotation.rotation0deg:
      default:
        return 0;
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.repetitionCount != repetitionCount ||
        oldDelegate.currentAngle != currentAngle;
  }
}