import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

double computeAngle(Offset a, Offset b, Offset c) {
  final ab = Offset(a.dx - b.dx, a.dy - b.dy);
  final cb = Offset(c.dx - b.dx, c.dy - b.dy);
  final dot = ab.dx * cb.dx + ab.dy * cb.dy;
  final magAB = ab.distance;
  final magCB = cb.distance;
  if (magAB == 0 || magCB == 0) return 0;
  return acos((dot / (magAB * magCB)).clamp(-1.0, 1.0)) * 180 / pi;
}

Map<String, double> calculatePoseAngles(Pose pose) {
  final lms = pose.landmarks;
  double? angle(String name, PoseLandmarkType a, PoseLandmarkType b, PoseLandmarkType c) {
    final la = lms[a], lb = lms[b], lc = lms[c];
    if (la == null || lb == null || lc == null) return null;
    return computeAngle(
      Offset(la.x, la.y),
      Offset(lb.x, lb.y),
      Offset(lc.x, lc.y),
    );
  }

  return {
    'leftElbow': angle('leftElbow', PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist) ?? 0,
    'rightElbow': angle('rightElbow', PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist) ?? 0,
    'leftShoulder': angle('leftShoulder', PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow) ?? 0,
    'rightShoulder': angle('rightShoulder', PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow) ?? 0,
    'leftHip': angle('leftHip', PoseLandmarkType.leftKnee, PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder) ?? 0,
    'rightHip': angle('rightHip', PoseLandmarkType.rightKnee, PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder) ?? 0,
    'leftKnee': angle('leftKnee', PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle) ?? 0,
    'rightKnee': angle('rightKnee', PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle) ?? 0,
  };
}