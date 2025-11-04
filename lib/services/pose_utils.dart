/// Utilities to calculate angles between body joints and implement simple
/// repetition counting.  This class contains static helpers that operate on
/// [PoseLandmark] objects returned by ML Kit's pose detector.
///
/// The angle calculation follows the implementation from the official
/// ML Kit documentation.  Given three points (firstPoint → midPoint → lastPoint)
/// it returns the acute angle at the `midPoint` formed by the vectors
/// `(firstPoint → midPoint)` and `(lastPoint → midPoint)`.
/// See: https://developers.google.com/ml-kit/vision/pose-detection/classifying-poses
/// where the angle is computed using `atan2` and converted to degrees【599519055646367†L376-L407】.
import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseUtils {
  /// Compute the acute angle (0–180°) between three landmarks.
  ///
  /// [firstPoint], [midPoint] and [lastPoint] correspond to three joints
  /// defining two line segments.  The returned value is always positive and
  /// constrained to [0, 180].
  static double calculateAngle(
      PoseLandmark firstPoint, PoseLandmark midPoint, PoseLandmark lastPoint) {
    final radians = atan2(
          lastPoint.y - midPoint.y,
          lastPoint.x - midPoint.x,
        ) -
        atan2(
          firstPoint.y - midPoint.y,
          firstPoint.x - midPoint.x,
        );
    double degrees = radians * 180.0 / pi;
    degrees = degrees.abs();
    if (degrees > 180) {
      degrees = 360.0 - degrees;
    }
    return degrees;
  }
}

/// Simple stateful counter for measuring repetitions of a basic exercise.
///
/// This class is configured for squat‑like movements by default: it measures
/// the angle at the knee joint (hip–knee–ankle).  When the knee angle falls
/// below [downThreshold] the internal state transitions to "down", and when
/// the angle exceeds [upThreshold] again the repetition counter is
/// incremented and the state resets to "up".  Different thresholds can be
/// supplied to tune the detector to arm curls, push‑ups or other exercises.
class RepetitionCounter {
  /// Create a [RepetitionCounter] with custom thresholds and joint type.
  RepetitionCounter({
    this.joint = PoseLandmarkType.leftKnee,
    this.downThreshold = 90.0,
    this.upThreshold = 160.0,
  });

  /// The joint around which we compute the angle.  For squats the knee is
  /// appropriate, for arm curls use [PoseLandmarkType.leftElbow] or
  /// [PoseLandmarkType.rightElbow].
  final PoseLandmarkType joint;

  /// Angle (in degrees) below which the pose is considered in the "down"
  /// position.  For example, 90° for a deep squat.
  final double downThreshold;

  /// Angle (in degrees) above which the pose is considered back in the
  /// starting "up" position.  A typical extended knee or elbow has an angle
  /// of around 160° or greater【599519055646367†L376-L407】.
  final double upThreshold;

  bool _isDown = false;
  int count = 0;

  /// Process a [Pose] and update the repetition count if the joint angle
  /// satisfies the state transition thresholds.  Returns the current count.
  int process(Pose pose) {
    // Determine which side to use based on the joint.
    PoseLandmark? a;
    PoseLandmark? b;
    PoseLandmark? c;
    switch (joint) {
      case PoseLandmarkType.leftKnee:
        a = pose.landmarks[PoseLandmarkType.leftHip];
        b = pose.landmarks[PoseLandmarkType.leftKnee];
        c = pose.landmarks[PoseLandmarkType.leftAnkle];
        break;
      case PoseLandmarkType.rightKnee:
        a = pose.landmarks[PoseLandmarkType.rightHip];
        b = pose.landmarks[PoseLandmarkType.rightKnee];
        c = pose.landmarks[PoseLandmarkType.rightAnkle];
        break;
      case PoseLandmarkType.leftElbow:
        a = pose.landmarks[PoseLandmarkType.leftShoulder];
        b = pose.landmarks[PoseLandmarkType.leftElbow];
        c = pose.landmarks[PoseLandmarkType.leftWrist];
        break;
      case PoseLandmarkType.rightElbow:
        a = pose.landmarks[PoseLandmarkType.rightShoulder];
        b = pose.landmarks[PoseLandmarkType.rightElbow];
        c = pose.landmarks[PoseLandmarkType.rightWrist];
        break;
      default:
        // Fallback to left knee if unspecified.
        a = pose.landmarks[PoseLandmarkType.leftHip];
        b = pose.landmarks[PoseLandmarkType.leftKnee];
        c = pose.landmarks[PoseLandmarkType.leftAnkle];
        break;
    }
    if (a == null || b == null || c == null) {
      return count;
    }
    final angle = PoseUtils.calculateAngle(a, b, c);
    // If the angle is below the down threshold we are in the down position.
    if (angle < downThreshold) {
      _isDown = true;
    }
    // If the angle is above the up threshold and we previously were down
    // then a full repetition has been completed.
    if (angle > upThreshold && _isDown) {
      count++;
      _isDown = false;
    }
    return count;
  }
}